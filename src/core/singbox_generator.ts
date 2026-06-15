/**
 * Nexus VPN — sing-box JSON Config Generator
 * Converts ProxyNode[] → complete sing-box config.json
 * Supports sing-box 1.9.x schema
 */

import type { ProxyNode } from '../parsers/node_parser';

export interface SingboxConfig {
  log: LogConfig;
  dns: DnsConfig;
  inbounds: Inbound[];
  outbounds: Outbound[];
  route: RouteConfig;
  experimental?: ExperimentalConfig;
}

interface LogConfig {
  level: 'trace' | 'debug' | 'info' | 'warn' | 'error';
  timestamp: boolean;
}

interface DnsConfig {
  servers: DnsServer[];
  rules: DnsRule[];
  final: string;
  strategy: string;
}

interface DnsServer {
  tag: string;
  address: string;
  address_resolver?: string;
  strategy?: string;
  detour?: string;
}

interface DnsRule {
  rule_set?: string[];
  geosite?: string[];
  domain_suffix?: string[];
  server: string;
  disable_cache?: boolean;
}

interface Inbound {
  type: string;
  tag: string;
  listen?: string;
  listen_port?: number;
  sniff?: boolean;
  sniff_override_destination?: boolean;
  users?: any[];
  interface_name?: string;
  address?: string[];
  mtu?: number;
  auto_route?: boolean;
  strict_route?: boolean;
}

type Outbound = Record<string, any>;

interface RouteConfig {
  rules: RouteRule[];
  rule_set: RuleSet[];
  final: string;
  auto_detect_interface: boolean;
}

interface RouteRule {
  rule_set?: string[];
  geosite?: string[];
  geoip?: string[];
  ip_is_private?: boolean;
  domain_suffix?: string[];
  outbound: string;
  protocol?: string;
}

interface RuleSet {
  tag: string;
  type: 'remote' | 'local';
  format: 'binary' | 'source';
  url?: string;
  path?: string;
  update_interval?: string;
}

interface ExperimentalConfig {
  clash_api?: { external_controller: string; external_ui?: string; };
  cache_file?: { enabled: boolean; path: string; };
}

// ─── Main Generator ───────────────────────────────────────────────────────────

export interface GeneratorOptions {
  /** The node to connect through (outbound) */
  selectedNode: ProxyNode;
  /** All nodes (for selector outbound group) */
  allNodes?: ProxyNode[];
  /** Enable TUN mode for transparent proxy */
  tunMode?: boolean;
  /** DNS leak protection */
  dnsLeakProtection?: boolean;
  /** Enable Clash API for dashboard */
  clashApi?: boolean;
  /** Traffic routing strategy */
  routeMode?: 'rule' | 'global' | 'direct';
  /** Log level */
  logLevel?: LogConfig['level'];
}

export function generateSingboxConfig(opts: GeneratorOptions): SingboxConfig {
  const {
    selectedNode,
    allNodes = [selectedNode],
    tunMode = true,
    dnsLeakProtection = true,
    clashApi = false,
    routeMode = 'rule',
    logLevel = 'info',
  } = opts;

  return {
    log: buildLog(logLevel),
    dns: buildDns(dnsLeakProtection),
    inbounds: buildInbounds(tunMode),
    outbounds: buildOutbounds(selectedNode, allNodes, routeMode),
    route: buildRoute(routeMode),
    ...(clashApi ? { experimental: buildExperimental() } : {}),
  };
}

// ─── Log ──────────────────────────────────────────────────────────────────────

function buildLog(level: LogConfig['level']): LogConfig {
  return { level, timestamp: true };
}

// ─── DNS ──────────────────────────────────────────────────────────────────────

function buildDns(leakProtection: boolean): DnsConfig {
  const servers: DnsServer[] = [
    { tag: 'dns-remote', address: 'https://1.1.1.1/dns-query', detour: 'proxy' },
    { tag: 'dns-local', address: 'https://223.5.5.5/dns-query', detour: 'direct' },
    { tag: 'dns-block', address: 'rcode://success' },
  ];

  const rules: DnsRule[] = leakProtection
    ? [
        { rule_set: ['geosite-cn'], server: 'dns-local' },
        { rule_set: ['geosite-geolocation-!cn'], server: 'dns-remote' },
        { domain_suffix: ['.local'], server: 'dns-local', disable_cache: true },
      ]
    : [
        { rule_set: ['geosite-cn'], server: 'dns-local' },
      ];

  return {
    servers,
    rules,
    final: leakProtection ? 'dns-remote' : 'dns-local',
    strategy: 'prefer_ipv4',
  };
}

// ─── Inbounds ─────────────────────────────────────────────────────────────────

function buildInbounds(tunMode: boolean): Inbound[] {
  const inbounds: Inbound[] = [
    {
      type: 'mixed',
      tag: 'mixed-in',
      listen: '127.0.0.1',
      listen_port: 7890,
      sniff: true,
    },
  ];

  if (tunMode) {
    inbounds.push({
      type: 'tun',
      tag: 'tun-in',
      interface_name: 'tun0',
      address: ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      mtu: 9000,
      auto_route: true,
      strict_route: true,
      sniff: true,
    });
  }

  return inbounds;
}

// ─── Outbounds ────────────────────────────────────────────────────────────────

function buildOutbounds(
  selected: ProxyNode,
  all: ProxyNode[],
  routeMode: string
): Outbound[] {
  const outbounds: Outbound[] = [];

  // Individual node outbounds
  for (const node of all) {
    outbounds.push(nodeToOutbound(node));
  }

  // Selector (proxy group)
  outbounds.push({
    type: 'selector',
    tag: 'proxy',
    outbounds: all.map(n => n.name),
    default: selected.name,
  });

  // URL-test (auto-select lowest latency)
  outbounds.push({
    type: 'urltest',
    tag: 'auto',
    outbounds: all.map(n => n.name),
    url: 'https://www.gstatic.com/generate_204',
    interval: '3m',
    tolerance: 50,
  });

  // Built-ins
  outbounds.push({ type: 'direct', tag: 'direct' });
  outbounds.push({ type: 'block',  tag: 'block' });
  outbounds.push({ type: 'dns',    tag: 'dns-out' });

  return outbounds;
}

export function nodeToOutbound(node: ProxyNode): Outbound {
  const base: Outbound = {
    type: node.protocol,
    tag: node.name,
    server: node.server,
    server_port: node.port,
  };

  // TLS settings
  if (node.security !== 'none') {
    base.tls = {
      enabled: true,
      server_name: node.sni,
      ...(node.alpn ? { alpn: node.alpn } : {}),
      ...(node.fingerprint ? { utls: { enabled: true, fingerprint: node.fingerprint } } : {}),
      ...(node.security === 'reality' ? {
        reality: {
          enabled: true,
          public_key: node.publicKey,
          short_id: node.shortId,
        }
      } : {}),
    };
  }

  // Transport
  if (node.transport !== 'tcp' && node.transport !== 'none') {
    base.transport = buildTransport(node);
  }

  // Protocol-specific
  switch (node.protocol) {
    case 'vless':
      base.uuid = node.uuid;
      base.flow = node.security === 'reality' ? 'xtls-rprx-vision' : undefined;
      break;
    case 'vmess':
      base.uuid = node.uuid;
      base.alter_id = node.alterId ?? 0;
      base.security = 'auto';
      break;
    case 'trojan':
      base.password = node.password;
      break;
    case 'shadowsocks':
      base.method = node.method;
      base.password = node.password;
      break;
    case 'hysteria2':
      base.password = node.password;
      if (node.obfs) {
        base.obfs = { type: node.obfs, password: node.obfsPassword };
      }
      break;
    case 'tuic':
      base.uuid = node.uuid;
      base.password = node.password;
      base.congestion_control = node.congestion ?? 'bbr';
      break;
    case 'wireguard':
      base.private_key = node.privateKey;
      base.peers = [{
        public_key: node.publicKeyWG,
        allowed_ips: node.allowedIPs ?? ['0.0.0.0/0', '::/0'],
        server: node.server,
        server_port: node.port,
      }];
      base.dns_server = node.dns ?? '1.1.1.1';
      delete base.server;
      delete base.server_port;
      break;
  }

  return base;
}

function buildTransport(node: ProxyNode): Record<string, any> {
  switch (node.transport) {
    case 'ws':
      return {
        type: 'ws',
        path: node.path ?? '/',
        headers: node.host ? { Host: node.host } : undefined,
        max_early_data: 2048,
        early_data_header_name: 'Sec-WebSocket-Protocol',
      };
    case 'grpc':
      return { type: 'grpc', service_name: node.serviceName ?? '' };
    case 'http':
      return { type: 'http', host: node.host ? [node.host] : undefined, path: node.path };
    case 'quic':
      return { type: 'quic' };
    default:
      return { type: node.transport };
  }
}

// ─── Route ────────────────────────────────────────────────────────────────────

function buildRoute(mode: string): RouteConfig {
  const rules: RouteRule[] = [
    { protocol: 'dns', outbound: 'dns-out' },
    { ip_is_private: true, outbound: 'direct' },
  ];

  if (mode === 'rule') {
    rules.push({ rule_set: ['geoip-cn', 'geosite-cn'], outbound: 'direct' });
    rules.push({ rule_set: ['geosite-category-ads-all'], outbound: 'block' });
  }

  const ruleSets: RuleSet[] = mode === 'rule' ? [
    {
      tag: 'geoip-cn',
      type: 'remote',
      format: 'binary',
      url: 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
      update_interval: '7d',
    },
    {
      tag: 'geosite-cn',
      type: 'remote',
      format: 'binary',
      url: 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
      update_interval: '7d',
    },
    {
      tag: 'geosite-geolocation-!cn',
      type: 'remote',
      format: 'binary',
      url: 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs',
      update_interval: '7d',
    },
    {
      tag: 'geosite-category-ads-all',
      type: 'remote',
      format: 'binary',
      url: 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
      update_interval: '7d',
    },
  ] : [];

  return {
    rules,
    rule_set: ruleSets,
    final: mode === 'global' ? 'proxy' : mode === 'direct' ? 'direct' : 'proxy',
    auto_detect_interface: true,
  };
}

// ─── Experimental ─────────────────────────────────────────────────────────────

function buildExperimental(): ExperimentalConfig {
  return {
    clash_api: { external_controller: '127.0.0.1:9090', external_ui: 'ui' },
    cache_file: { enabled: true, path: 'cache.db' },
  };
}

// ─── Serializer ───────────────────────────────────────────────────────────────

export function configToJson(config: SingboxConfig, pretty = true): string {
  // Remove undefined fields recursively
  const clean = JSON.parse(JSON.stringify(config));
  return pretty ? JSON.stringify(clean, null, 2) : JSON.stringify(clean);
}
