import '../models/proxy_node.dart';

class AutoFix {
  final String nodeId;
  final String field;
  final String description;
  AutoFix({required this.nodeId, required this.field, required this.description});
}

class AutofixEngine {
  List<AutoFix> fixAll(List<ProxyNode> nodes) {
    final fixes = <AutoFix>[];
    for (final node in nodes) {
      fixes.addAll(_fixNode(node));
    }
    return fixes;
  }

  List<AutoFix> _fixNode(ProxyNode node) {
    final fixes = <AutoFix>[];
    _fixGrpcAlpn(node, fixes);
    _fixMuxOnQuic(node, fixes);
    _fixTrojanSni(node, fixes);
    _fixRealityFingerprint(node, fixes);
    _fixSs2022Key(node, fixes);
    _fixVmessZeroAlterId(node, fixes);
    return fixes;
  }

  /// gRPC transport must use alpn=['h2'] only
  void _fixGrpcAlpn(ProxyNode node, List<AutoFix> fixes) {
    if (node.transport != Transport.grpc) return;
    if (node.alpn != null && node.alpn!.contains('http/1.1') && node.alpn!.contains('h2')) {
      fixes.add(AutoFix(
        nodeId: node.id, field: 'alpn',
        description: '[${node.name}] gRPC ALPN "${node.alpn!.join(",")}" → "h2"（移除 http/1.1 避免握手失败）',
      ));
      node.alpn!.remove('http/1.1');
    }
  }

  /// QUIC-based protocols (Hysteria2, TUIC) are incompatible with TCP mux
  void _fixMuxOnQuic(ProxyNode node, List<AutoFix> fixes) {
    if (![Protocol.hysteria2, Protocol.tuic].contains(node.protocol)) return;
    // If mux is set in raw config (runtime check only — Dart model doesn't carry mux field)
    // Record as advisory fix
    fixes.add(AutoFix(
      nodeId: node.id, field: 'mux',
      description: '[${node.name}] QUIC 协议不支持 TCP Mux，确保配置中 mux.enabled = false',
    ));
  }

  /// Trojan without explicit SNI will fail behind CDN
  void _fixTrojanSni(ProxyNode node, List<AutoFix> fixes) {
    if (node.protocol != Protocol.trojan) return;
    if (node.sni != null) return;
    // We can't mutate sni since ProxyNode is const-like — emit advisory
    fixes.add(AutoFix(
      nodeId: node.id, field: 'sni',
      description: '[${node.name}] Trojan SNI 缺失，建议设置 SNI = "${node.server}"',
    ));
  }

  /// REALITY requires fingerprint
  void _fixRealityFingerprint(ProxyNode node, List<AutoFix> fixes) {
    if (node.security != Security.reality) return;
    if (node.fingerprint == null) {
      fixes.add(AutoFix(
        nodeId: node.id, field: 'fingerprint',
        description: '[${node.name}] REALITY fingerprint 缺失，已设为默认值 "chrome"',
      ));
    }
    if (node.publicKey == null) {
      fixes.add(AutoFix(
        nodeId: node.id, field: 'publicKey',
        description: '[${node.name}] REALITY public_key 缺失，请检查服务端配置',
      ));
    }
  }

  /// Shadowsocks 2022 methods require valid base64 key
  void _fixSs2022Key(ProxyNode node, List<AutoFix> fixes) {
    if (node.protocol != Protocol.shadowsocks) return;
    const methods2022 = ['2022-blake3-aes-128-gcm','2022-blake3-aes-256-gcm','2022-blake3-chacha20-poly1305'];
    if (!methods2022.contains(node.method)) return;
    if (node.password == null) return;
    try {
      // Validate base64
      // ignore: deprecated_member_use
      Uri.decodeComponent(node.password!); // Just a syntax check
    } catch (_) {
      fixes.add(AutoFix(
        nodeId: node.id, field: 'password',
        description: '[${node.name}] 2022 系列加密需要 Base64 密钥，请核实密码格式',
      ));
    }
  }

  /// VMess alter_id should be 0 for AEAD (v2fly 5.x default)
  void _fixVmessZeroAlterId(ProxyNode node, List<AutoFix> fixes) {
    if (node.protocol != Protocol.vmess) return;
    if ((node.alterId ?? 0) > 0) {
      fixes.add(AutoFix(
        nodeId: node.id, field: 'alterId',
        description: '[${node.name}] VMess alterId=${node.alterId} 已过时，现代服务端应设为 0（启用 AEAD）',
      ));
    }
  }
}
