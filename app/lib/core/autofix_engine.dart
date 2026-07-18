import '../models/proxy_node.dart';

class AutoFix {
  final String nodeId;
  final String field;
  final String description;
  AutoFix({required this.nodeId, required this.field, required this.description});
}

class AutofixResult {
  final List<ProxyNode> nodes;
  final List<AutoFix> fixes;
  AutofixResult({required this.nodes, required this.fixes});
}

class AutofixEngine {
  /// Returns corrected nodes (immutable copyWith) plus human-readable fix notes.
  AutofixResult fixAll(List<ProxyNode> nodes) {
    final fixes = <AutoFix>[];
    final out = <ProxyNode>[];
    for (final node in nodes) {
      final result = _fixNode(node);
      out.add(result.node);
      fixes.addAll(result.fixes);
    }
    return AutofixResult(nodes: out, fixes: fixes);
  }

  ({ProxyNode node, List<AutoFix> fixes}) _fixNode(ProxyNode node) {
    final fixes = <AutoFix>[];
    var n = node;

    if (n.transport == Transport.grpc) {
      final alpn = n.alpn != null ? List<String>.from(n.alpn!) : <String>[];
      if (alpn.contains('http/1.1') || alpn.isEmpty) {
        final next = alpn.where((a) => a != 'http/1.1').toList();
        if (!next.contains('h2')) next.add('h2');
        fixes.add(AutoFix(
          nodeId: n.id,
          field: 'alpn',
          description: '[${n.name}] gRPC ALPN → ${next.join(",")}（避免握手失败）',
        ));
        n = n.copyWith(alpn: next);
      }
    }

    if ([Protocol.hysteria2, Protocol.tuic].contains(n.protocol)) {
      fixes.add(AutoFix(
        nodeId: n.id,
        field: 'mux',
        description: '[${n.name}] QUIC 协议不支持 TCP Mux，已在配置生成时禁用',
      ));
    }

    if (n.protocol == Protocol.trojan && (n.sni == null || n.sni!.isEmpty)) {
      fixes.add(AutoFix(
        nodeId: n.id,
        field: 'sni',
        description: '[${n.name}] Trojan SNI 缺失，已设为 ${n.server}',
      ));
      n = n.copyWith(sni: n.server);
    }

    if (n.security == Security.reality) {
      if (n.fingerprint == null || n.fingerprint!.isEmpty) {
        fixes.add(AutoFix(
          nodeId: n.id,
          field: 'fingerprint',
          description: '[${n.name}] REALITY fingerprint 缺失，已设为 chrome',
        ));
        n = n.copyWith(fingerprint: 'chrome');
      }
      if (n.publicKey == null || n.publicKey!.isEmpty) {
        fixes.add(AutoFix(
          nodeId: n.id,
          field: 'publicKey',
          description: '[${n.name}] REALITY public_key 缺失，请检查服务端配置',
        ));
      }
    }

    if (n.protocol == Protocol.shadowsocks) {
      const methods2022 = [
        '2022-blake3-aes-128-gcm',
        '2022-blake3-aes-256-gcm',
        '2022-blake3-chacha20-poly1305',
      ];
      if (methods2022.contains(n.method) && (n.password == null || n.password!.isEmpty)) {
        fixes.add(AutoFix(
          nodeId: n.id,
          field: 'password',
          description: '[${n.name}] 2022 系列加密需要 Base64 密钥，请核实密码',
        ));
      }
    }

    if (n.protocol == Protocol.vmess && (n.alterId ?? 0) > 0) {
      fixes.add(AutoFix(
        nodeId: n.id,
        field: 'alterId',
        description: '[${n.name}] VMess alterId=${n.alterId} 已过时，已改为 0（AEAD）',
      ));
      n = n.copyWith(alterId: 0);
    }

    if (n.server.isEmpty) {
      fixes.add(AutoFix(
        nodeId: n.id,
        field: 'server',
        description: '[${n.name}] 服务器地址为空，节点不可用',
      ));
    }

    return (node: n, fixes: fixes);
  }
}
