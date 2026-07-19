/**
 * Nexus — Universal Node Parser
 * Supports: vmess:// vless:// trojan:// ss:// hysteria2:// tuic:// wg://
 * Script sources: 233boy/sing-box, 233boy/Xray, 233boy/v2ray,
 *                 mack-a/v2ray-agent, yonggekkk/sing-box-yg
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export type Protocol =
  | 'vless' | 'vmess' | 'trojan' | 'shadowsocks'
  | 'hysteria2' | 'tuic' | 'wireguard';

export type Transport = 'tcp' | 'ws' | 'grpc' | 'http' | 'quic' | 'none';
export type Security  = 'tls' | 'reality' | 'none';

export interface ProxyNode {
  id: string;
  name: string;
  protocol: Protocol;
  server: string;
  port: number;
  // Protocol-specific fields
  uuid?: string;           // vless/vmess/trojan
  password?: string;       // trojan/ss
  method?: string;         // ss encryption method
  alterId?: number;        // vmess
  // Transport
  transport: Transport;
  path?: string;           // ws/grpc path
  host?: string;           // ws host header
  serviceName?: string;    // grpc service
  // TLS / REALITY
  security: Security;
  sni?: string;
  alpn?: string[];
  fingerprint?: string;    // tls fingerprint (chrome/firefox/safari)
  publicKey?: string;      // REALITY public key
  shortId?: string;        // REALITY short id
  // Hysteria2 / TUIC extras
  obfs?: string;
  obfsPassword?: string;
  congestion?: string;
  // WireGuard
  privateKey?: string;
  publicKeyWG?: string;
  peerEndpoint?: string;
  allowedIPs?: string[];
  dns?: string;
  // Meta
  source?: string;   // which script generated this
  rawUri?: string;   // original URI for debugging
}

export interface ParseResult {
  nodes: ProxyNode[];
  errors: ParseError[];
  autofixes: AutoFix[];
  detectedSource?: string;
}

export interface ParseError {
  uri: string;
  reason: string;
}

export interface AutoFix {
  nodeId: string;
  field: string;
  before: string;
  after: string;
  description: string;
}

// ─── Source Detection ─────────────────────────────────────────────────────────

export type ScriptSource =
  | '233boy/sing-box'
  | '233boy/Xray'
  | '233boy/v2ray'
  | 'mack-a/v2ray-agent'
  | 'yonggekkk/sing-box-yg'
  | 'generic';

/**
 * Detect which VPN server script generated a subscription payload.
 * Heuristics based on URL patterns and JSON structure.
 */
export function detectSource(urlOrContent: string): ScriptSource {
  const s = urlOrContent.toLowerCase();

  // URL-based hints
  if (s.includes('233boy') && s.includes('sing-box')) return '233boy/sing-box';
  if (s.includes('233boy') && s.includes('xray'))     return '233boy/Xray';
  if (s.includes('233boy') && s.includes('v2ray'))    return '233boy/v2ray';
  if (s.includes('v2ray-agent') || s.includes('mack-a')) return 'mack-a/v2ray-agent';
  if (s.includes('sing-box-yg') || s.includes('yonggekkk')) return 'yonggekkk/sing-box-yg';

  // Content-based hints (from subscription JSON)
  if (s.includes('"inbounds"') && s.includes('"outbounds"') && s.includes('"route"'))
    return '233boy/sing-box';  // sing-box full config
  if (s.includes('"log"') && s.includes('"inbounds"') && s.includes('"routing"'))
    return '233boy/Xray';      // Xray full config

  return 'generic';
}

// ─── Main Parser ──────────────────────────────────────────────────────────────

export async function parseSubscription(
  input: string,
  fetchFn?: (url: string) => Promise<string>
): Promise<ParseResult> {
  const result: ParseResult = { nodes: [], errors: [], autofixes: [] };

  // Case 1: HTTP URL → fetch subscription
  if (/^https?:\/\//.test(input.trim())) {
    if (!fetchFn) throw new Error('fetchFn required for URL subscriptions');
    let content: string;
    try {
      content = await fetchFn(input.trim());
    } catch (e) {
      result.errors.push({ uri: input, reason: `Failed to fetch: ${e}` });
      return result;
    }
    result.detectedSource = detectSource(input + '\n' + content);
    return mergeResults(result, await parseContent(content, result));
  }

  // Case 2: Multi-URI (one per line)
  const lines = input.split('\n').map(l => l.trim()).filter(Boolean);
  if (lines.length > 1 || lines[0]?.includes('://')) {
    result.detectedSource = 'generic';
    for (const line of lines) {
      try {
        const node = parseUri(line);
        result.nodes.push(node);
      } catch (e: any) {
        result.errors.push({ uri: line, reason: e.message });
      }
    }
    runAutofixes(result);
    return result;
  }

  // Case 3: Base64 encoded list
  try {
    const decoded = atob(input.trim());
    return parseSubscription(decoded, fetchFn);
  } catch (_) {}

  result.errors.push({ uri: input, reason: 'Unrecognized input format' });
  return result;
}

async function parseContent(content: string, result: ParseResult): Promise<ParseResult> {
  // Try JSON (sing-box / Xray / v2ray full config)
  try {
    const json = JSON.parse(content);
    return parseSingboxConfig(json, result);
  } catch (_) {}

  // Try base64 line list
  try {
    const decoded = atob(content.trim());
    const lines = decoded.split('\n').map(l => l.trim()).filter(Boolean);
    for (const line of lines) {
      try { result.nodes.push(parseUri(line)); }
      catch (e: any) { result.errors.push({ uri: line, reason: e.message }); }
    }
    runAutofixes(result);
    return result;
  } catch (_) {}

  // Try raw line URIs
  const lines = content.split('\n').map(l => l.trim()).filter(Boolean);
  for (const line of lines) {
    if (line.includes('://')) {
      try { result.nodes.push(parseUri(line)); }
      catch (e: any) { result.errors.push({ uri: line, reason: e.message }); }
    }
  }
  runAutofixes(result);
  return result;
}

// ─── sing-box Full Config Parser ──────────────────────────────────────────────

function parseSingboxConfig(json: any, result: ParseResult): ParseResult {
  const outbounds: any[] = json.outbounds ?? [];

  for (const ob of outbounds) {
    // Skip special outbounds
    if (['direct','block','dns'].includes(ob.type)) continue;

    try {
      const node = singboxOutboundToNode(ob);
      result.nodes.push(node);
    } catch (e: any) {
      result.errors.push({ uri: JSON.stringify(ob).slice(0, 80), reason: e.message });
    }
  }
  runAutofixes(result);
  return result;
}

function singboxOutboundToNode(ob: any): ProxyNode {
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  const tls = ob.tls ?? {};
  const tport = ob.transport ?? {};

  const node: ProxyNode = {
    id,
    name: ob.tag ?? 'Unnamed',
    protocol: ob.type as Protocol,
    server: ob.server ?? '',
    port: ob.server_port ?? 443,
    transport: mapTransport(tport.type),
    security: tls.enabled ? (tls.reality?.enabled ? 'reality' : 'tls') : 'none',
    sni: tls.server_name,
    alpn: tls.alpn,
    fingerprint: tls.utls?.fingerprint,
    publicKey: tls.reality?.public_key,
    shortId: tls.reality?.short_id,
    path: tport.path ?? tport.service_name,
    serviceName: tport.service_name,
    source: 'sing-box config',
  };

  // Protocol-specific
  switch (ob.type) {
    case 'vless': node.uuid = ob.uuid; break;
    case 'vmess': node.uuid = ob.uuid; node.alterId = ob.alter_id ?? 0; break;
    case 'trojan': node.password = ob.password; break;
    case 'shadowsocks': node.password = ob.password; node.method = ob.method; break;
    case 'hysteria2':
      node.password = ob.password;
      node.obfs = ob.obfs?.type;
      node.obfsPassword = ob.obfs?.password;
      break;
    case 'tuic':
      node.uuid = ob.uuid;
      node.password = ob.password;
      node.congestion = ob.congestion_control;
      break;
    case 'wireguard':
      node.privateKey = ob.private_key;
      node.publicKeyWG = ob.peers?.[0]?.public_key;
      node.allowedIPs = ob.peers?.[0]?.allowed_ips;
      break;
  }

  return node;
}

function mapTransport(t?: string): Transport {
  const m: Record<string, Transport> = {
    ws: 'ws', websocket: 'ws', grpc: 'grpc',
    http: 'http', tcp: 'tcp', quic: 'quic',
  };
  return m[t?.toLowerCase() ?? ''] ?? 'tcp';
}

// ─── URI Parsers ──────────────────────────────────────────────────────────────

export function parseUri(uri: string): ProxyNode {
  const scheme = uri.split('://')[0].toLowerCase();
  switch (scheme) {
    case 'vmess':     return parseVmess(uri);
    case 'vless':     return parseVless(uri);
    case 'trojan':    return parseTrojan(uri);
    case 'ss':        return parseShadowsocks(uri);
    case 'hysteria2':
    case 'hy2':       return parseHysteria2(uri);
    case 'tuic':      return parseTuic(uri);
    case 'wg':
    case 'wireguard': return parseWireguard(uri);
    default:          throw new Error(`Unsupported scheme: ${scheme}`);
  }
}

/** vmess://BASE64({v,ps,add,port,id,aid,net,type,host,path,tls,...}) */
function parseVmess(uri: string): ProxyNode {
  const b64 = uri.slice('vmess://'.length);
  let json: any;
  try {
    json = JSON.parse(atob(b64));
  } catch {
    throw new Error('Invalid vmess:// base64 payload');
  }
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  return {
    id,
    name: json.ps ?? json.add,
    protocol: 'vmess',
    server: json.add,
    port: Number(json.port),
    uuid: json.id,
    alterId: Number(json.aid ?? 0),
    transport: mapTransport(json.net),
    path: json.path,
    host: json.host,
    serviceName: json.path,   // gRPC service name reuses path
    security: json.tls === 'tls' ? 'tls' : 'none',
    sni: json.sni ?? json.host,
    alpn: json.alpn ? json.alpn.split(',') : undefined,
    source: 'vmess:// URI',
    rawUri: uri,
  };
}

/** vless://UUID@host:port?params#name */
function parseVless(uri: string): ProxyNode {
  const url = new URL(uri.replace('vless://', 'https://'));
  const p = url.searchParams;
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  const security = p.get('security') as Security ?? 'none';
  return {
    id,
    name: decodeURIComponent(url.hash.slice(1)) || url.hostname,
    protocol: 'vless',
    server: url.hostname,
    port: Number(url.port),
    uuid: url.username,
    transport: mapTransport(p.get('type') ?? 'tcp'),
    path: p.get('path') ?? p.get('serviceName'),
    host: p.get('host'),
    serviceName: p.get('serviceName'),
    security,
    sni: p.get('sni') ?? p.get('peer'),
    alpn: p.get('alpn')?.split(','),
    fingerprint: p.get('fp'),
    publicKey: p.get('pbk'),
    shortId: p.get('sid'),
    source: 'vless:// URI',
    rawUri: uri,
  };
}

/** trojan://password@host:port?params#name */
function parseTrojan(uri: string): ProxyNode {
  const url = new URL(uri.replace('trojan://', 'https://'));
  const p = url.searchParams;
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  return {
    id,
    name: decodeURIComponent(url.hash.slice(1)) || url.hostname,
    protocol: 'trojan',
    server: url.hostname,
    port: Number(url.port || 443),
    password: url.username,
    transport: mapTransport(p.get('type') ?? 'tcp'),
    path: p.get('path') ?? p.get('serviceName'),
    serviceName: p.get('serviceName'),
    security: 'tls',
    sni: p.get('sni') ?? p.get('peer') ?? url.hostname,
    alpn: p.get('alpn')?.split(','),
    fingerprint: p.get('fp'),
    source: 'trojan:// URI',
    rawUri: uri,
  };
}

/** ss://BASE64(method:password)@host:port#name  OR  ss://BASE64(whole)#name */
function parseShadowsocks(uri: string): ProxyNode {
  const [main, nameRaw] = uri.slice(5).split('#');
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  let method: string, password: string, server: string, portStr: string;

  if (main.includes('@')) {
    const [credentials, hostPart] = main.split('@');
    [method, password] = atob(credentials).split(':');
    [server, portStr] = hostPart.split(':');
  } else {
    // Some clients encode the whole ss URI in base64
    const decoded = atob(main);
    const match = decoded.match(/^(.+?):(.+)@(.+):(\d+)$/);
    if (!match) throw new Error('Invalid ss:// format');
    [, method, password, server, portStr] = match;
  }

  return {
    id,
    name: nameRaw ? decodeURIComponent(nameRaw) : server,
    protocol: 'shadowsocks',
    server,
    port: Number(portStr),
    method,
    password,
    transport: 'tcp',
    security: 'none',
    source: 'ss:// URI',
    rawUri: uri,
  };
}

/** hysteria2://password@host:port?params#name */
function parseHysteria2(uri: string): ProxyNode {
  const url = new URL(uri.replace(/^(hysteria2|hy2):\/\//, 'https://'));
  const p = url.searchParams;
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  return {
    id,
    name: decodeURIComponent(url.hash.slice(1)) || url.hostname,
    protocol: 'hysteria2',
    server: url.hostname,
    port: Number(url.port || 443),
    password: url.username,
    transport: 'quic',
    security: 'tls',
    sni: p.get('sni'),
    obfs: p.get('obfs') ?? undefined,
    obfsPassword: p.get('obfs-password') ?? undefined,
    fingerprint: p.get('pinSHA256') ?? undefined,
    source: 'hysteria2:// URI',
    rawUri: uri,
  };
}

/** tuic://UUID:password@host:port?params#name */
function parseTuic(uri: string): ProxyNode {
  const url = new URL(uri.replace('tuic://', 'https://'));
  const p = url.searchParams;
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  return {
    id,
    name: decodeURIComponent(url.hash.slice(1)) || url.hostname,
    protocol: 'tuic',
    server: url.hostname,
    port: Number(url.port),
    uuid: url.username,
    password: url.password,
    transport: 'quic',
    security: 'tls',
    sni: p.get('sni'),
    alpn: p.get('alpn')?.split(','),
    congestion: p.get('congestion_control') ?? 'bbr',
    source: 'tuic:// URI',
    rawUri: uri,
  };
}

/** wg://private-key@endpoint:port?pub=...&allowed=...&dns=... */
function parseWireguard(uri: string): ProxyNode {
  const url = new URL(uri.replace(/^(wg|wireguard):\/\//, 'https://'));
  const p = url.searchParams;
  const id = crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);
  return {
    id,
    name: decodeURIComponent(url.hash.slice(1)) || url.hostname,
    protocol: 'wireguard',
    server: url.hostname,
    port: Number(url.port || 51820),
    privateKey: url.username,
    publicKeyWG: p.get('pub') ?? undefined,
    allowedIPs: p.get('allowed')?.split(',') ?? ['0.0.0.0/0', '::/0'],
    dns: p.get('dns') ?? '1.1.1.1',
    transport: 'none',
    security: 'none',
    source: 'wg:// URI',
    rawUri: uri,
  };
}

// ─── Auto-Fix Engine ──────────────────────────────────────────────────────────

/**
 * Runs heuristic checks on all parsed nodes and automatically repairs
 * common misconfiguration patterns emitted by various VPN server scripts.
 */
function runAutofixes(result: ParseResult): void {
  for (const node of result.nodes) {
    fixVmessEncryption(node, result.autofixes);
    fixAlpnMismatch(node, result.autofixes);
    fixMuxConflict(node, result.autofixes);
    fixTrojanSni(node, result.autofixes);
    fixReality(node, result.autofixes);
    fixSsMethod(node, result.autofixes);
  }
}

/** VMess: encryption field must be "none" for sing-box outbounds */
function fixVmessEncryption(node: ProxyNode, fixes: AutoFix[]): void {
  if (node.protocol !== 'vmess') return;
  // Some v2ray server scripts export encryption="auto"; sing-box requires "none"
  if ((node as any).encryption && (node as any).encryption !== 'none') {
    const before = (node as any).encryption;
    (node as any).encryption = 'none';
    fixes.push({
      nodeId: node.id,
      field: 'encryption',
      before,
      after: 'none',
      description: `[${node.name}] VMess encryption 字段 "${before}" → "none" (sing-box 要求)`,
    });
  }
}

/** ALPN: h2 + http/1.1 can cause handshake failure for gRPC-only services */
function fixAlpnMismatch(node: ProxyNode, fixes: AutoFix[]): void {
  if (!node.alpn) return;
  if (node.transport === 'grpc' && node.alpn.includes('http/1.1') && node.alpn.includes('h2')) {
    const before = node.alpn.join(',');
    node.alpn = ['h2'];
    fixes.push({
      nodeId: node.id,
      field: 'alpn',
      before,
      after: 'h2',
      description: `[${node.name}] gRPC 节点 ALPN "${before}" → "h2"（移除 http/1.1 避免握手失败）`,
    });
  }
}

/** Mux conflicts with QUIC-based protocols (Hysteria2, TUIC) */
function fixMuxConflict(node: ProxyNode, fixes: AutoFix[]): void {
  if (!['hysteria2','tuic'].includes(node.protocol)) return;
  if ((node as any).mux?.enabled) {
    (node as any).mux.enabled = false;
    fixes.push({
      nodeId: node.id,
      field: 'mux.enabled',
      before: 'true',
      after: 'false',
      description: `[${node.name}] QUIC 协议不支持 TCP Mux，已自动关闭`,
    });
  }
}

/** Trojan: SNI defaults to server address if missing, but CDN breaks without explicit SNI */
function fixTrojanSni(node: ProxyNode, fixes: AutoFix[]): void {
  if (node.protocol !== 'trojan') return;
  if (!node.sni && node.server) {
    // Use server as sni only if it looks like a domain
    if (!/^\d+\.\d+\.\d+\.\d+$/.test(node.server)) {
      const before = 'undefined';
      node.sni = node.server;
      fixes.push({
        nodeId: node.id,
        field: 'sni',
        before,
        after: node.server,
        description: `[${node.name}] Trojan SNI 缺失，已设为服务器域名 "${node.server}"`,
      });
    }
  }
}

/** REALITY: publicKey + shortId are mandatory */
function fixReality(node: ProxyNode, fixes: AutoFix[]): void {
  if (node.security !== 'reality') return;
  if (!node.fingerprint) {
    node.fingerprint = 'chrome';
    fixes.push({
      nodeId: node.id,
      field: 'fingerprint',
      before: 'none',
      after: 'chrome',
      description: `[${node.name}] REALITY fingerprint 缺失，已设为 "chrome"`,
    });
  }
}

/** Shadowsocks: 2022 methods require Base64 password */
function fixSsMethod(node: ProxyNode, fixes: AutoFix[]): void {
  if (node.protocol !== 'shadowsocks') return;
  const methods2022 = ['2022-blake3-aes-128-gcm','2022-blake3-aes-256-gcm','2022-blake3-chacha20-poly1305'];
  if (methods2022.includes(node.method ?? '') && node.password) {
    // Validate that password is valid base64 (basic check)
    try { atob(node.password); } catch {
      const before = node.password;
      // Generate a valid base64 placeholder note (cannot auto-generate real key)
      fixes.push({
        nodeId: node.id,
        field: 'password',
        before: before.slice(0,8) + '...',
        after: '(需要有效的 Base64 密钥)',
        description: `[${node.name}] 2022 系列加密方式要求 Base64 密钥，请检查密码格式`,
      });
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function mergeResults(base: ParseResult, extra: ParseResult): ParseResult {
  return {
    nodes: [...base.nodes, ...extra.nodes],
    errors: [...base.errors, ...extra.errors],
    autofixes: [...base.autofixes, ...extra.autofixes],
    detectedSource: base.detectedSource ?? extra.detectedSource,
  };
}
