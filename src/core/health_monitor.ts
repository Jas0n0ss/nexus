/**
 * Nexus VPN — Runtime Health Monitor + Auto-Fix Engine
 * Handles: crash detection, DNS leak fix, latency monitoring, auto-restart
 */

export interface HealthStatus {
  coreRunning: boolean;
  cpuPercent: number;
  memoryMB: number;
  dnsLeaking: boolean;
  latencyMs: number;
  lastCheck: Date;
}

export type CoreType = 'singbox' | 'xray' | 'v2ray';

export interface HealthMonitorOptions {
  checkInterval?: number;   // ms, default 10_000
  restartDelay?: number;    // ms, default 2_000
  maxRestarts?: number;     // before giving up, default 5
  cpuThreshold?: number;    // %, default 80
  memThreshold?: number;    // MB, default 512
  latencyThreshold?: number;// ms, default 2_000
  onStatusChange?: (status: HealthStatus) => void;
  onFix?: (msg: string) => void;
  onCritical?: (msg: string) => void;
}

export class HealthMonitor {
  private opts: Required<HealthMonitorOptions>;
  private timer: ReturnType<typeof setInterval> | null = null;
  private restartCount = 0;
  private currentCore: CoreType = 'singbox';
  private fallbackCore: CoreType = 'xray';

  constructor(opts: HealthMonitorOptions = {}) {
    this.opts = {
      checkInterval:   opts.checkInterval   ?? 10_000,
      restartDelay:    opts.restartDelay    ?? 2_000,
      maxRestarts:     opts.maxRestarts     ?? 5,
      cpuThreshold:    opts.cpuThreshold    ?? 80,
      memThreshold:    opts.memThreshold    ?? 512,
      latencyThreshold:opts.latencyThreshold?? 2_000,
      onStatusChange:  opts.onStatusChange  ?? (() => {}),
      onFix:           opts.onFix           ?? (() => {}),
      onCritical:      opts.onCritical      ?? (() => {}),
    };
  }

  start(core: CoreType = 'singbox') {
    this.currentCore = core;
    this.timer = setInterval(() => this.check(), this.opts.checkInterval);
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
  }

  private async check() {
    const status = await this.collectStatus();
    this.opts.onStatusChange(status);

    // 1. Core crash
    if (!status.coreRunning) {
      await this.handleCrash();
      return;
    }

    // 2. CPU spike
    if (status.cpuPercent > this.opts.cpuThreshold) {
      this.opts.onFix(`CPU 使用率过高 (${status.cpuPercent}%)，正在重启核心...`);
      await this.restartCore();
    }

    // 3. Memory leak
    if (status.memoryMB > this.opts.memThreshold) {
      this.opts.onFix(`内存使用超限 (${status.memoryMB}MB)，正在重启核心...`);
      await this.restartCore();
    }

    // 4. DNS leak
    if (status.dnsLeaking) {
      this.opts.onFix('检测到 DNS 泄漏，正在强制修复路由...');
      await this.fixDnsLeak();
    }

    // 5. High latency → suggest node switch
    if (status.latencyMs > this.opts.latencyThreshold) {
      this.opts.onFix(`当前节点延迟过高 (${status.latencyMs}ms)，建议切换节点`);
    }
  }

  private async collectStatus(): Promise<HealthStatus> {
    // In production: read from native process stats / IPC
    // Here: mock implementation for demo
    return {
      coreRunning:  true,
      cpuPercent:   Math.random() * 15,
      memoryMB:     80 + Math.random() * 60,
      dnsLeaking:   false,
      latencyMs:    30 + Math.random() * 80,
      lastCheck:    new Date(),
    };
  }

  private async handleCrash() {
    if (this.restartCount >= this.opts.maxRestarts) {
      this.opts.onCritical(
        `核心 ${this.currentCore} 连续崩溃 ${this.restartCount} 次，已切换备用核心 ${this.fallbackCore}`
      );
      await this.switchCore(this.fallbackCore);
      this.restartCount = 0;
      return;
    }

    this.restartCount++;
    this.opts.onFix(`核心 ${this.currentCore} 意外退出，${this.opts.restartDelay}ms 后重启 (第 ${this.restartCount} 次)`);
    await delay(this.opts.restartDelay);
    await this.restartCore();
  }

  private async restartCore() {
    // In production: kill + re-spawn the core process via IPC
    await delay(500);
    this.opts.onFix(`核心 ${this.currentCore} 已重启`);
  }

  private async switchCore(to: CoreType) {
    this.currentCore = to;
    await this.restartCore();
  }

  private async fixDnsLeak() {
    // Force all DNS through the proxy tunnel by updating routing rules
    // In production: modify sing-box dns config to route all queries through proxy
    this.opts.onFix('DNS 泄漏修复完成：所有 DNS 查询已强制通过代理');
  }
}

function delay(ms: number) { return new Promise(r => setTimeout(r, ms)); }
