// NexusVPN — iOS/macOS Network Extension (NEPacketTunnelProvider)
// Bridges Flutter ↔ sing-box via NEPacketTunnelProvider + app group shared container.
// Entitlements required:
//   com.apple.developer.networking.networkextension: [packet-tunnel-provider]
//   com.apple.security.application-groups: [group.com.yourcompany.nexusvpn]

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = Logger(subsystem: "com.yourcompany.nexusvpn", category: "tunnel")
    private var singboxProcess: Process?
    private var configPath: URL?

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log.info("Starting NexusVPN tunnel")

        guard let configData = options?["singboxConfig"] as? Data,
              let configJson = String(data: configData, encoding: .utf8) else {
            completionHandler(TunnelError.missingConfig)
            return
        }

        do {
            // Write config to shared container accessible by the extension
            let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.nexusvpn")!
            configPath = containerURL.appendingPathComponent("sing-box-config.json")
            try configJson.write(to: configPath!, atomically: true, encoding: .utf8)

            // Configure the TUN interface
            let networkSettings = buildNetworkSettings()
            setTunnelNetworkSettings(networkSettings) { [weak self] error in
                if let error { completionHandler(error); return }
                self?.startSingbox(completionHandler: completionHandler)
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log.info("Stopping tunnel — reason: \(reason.rawValue)")
        singboxProcess?.terminate()
        singboxProcess = nil
        completionHandler()
    }

    // ── sing-box Process ──────────────────────────────────────────────────────

    private func startSingbox(completionHandler: @escaping (Error?) -> Void) {
        guard let configPath else { completionHandler(TunnelError.missingConfig); return }

        // sing-box binary bundled in the extension's Resources
        guard let binaryURL = Bundle.main.url(forResource: "sing-box", withExtension: nil) else {
            completionHandler(TunnelError.binaryNotFound)
            return
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["run", "-c", configPath.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8) {
                self?.log.debug("\(line)")
                // Crash detection: restart if core exits unexpectedly
                if line.contains("panic") || line.contains("fatal") {
                    self?.log.error("sing-box crash detected — restarting")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        self?.startSingbox(completionHandler: { _ in })
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            self?.log.warning("sing-box exited with code \(proc.terminationStatus)")
        }

        do {
            try process.run()
            singboxProcess = process
            log.info("sing-box started, PID \(process.processIdentifier)")
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    // ── Network Settings ──────────────────────────────────────────────────────

    private func buildNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // TUN interface addresses (must match sing-box inbound config)
        let ipv4 = NEIPv4Settings(
            addresses: ["172.19.0.1"],
            subnetMasks: ["255.255.255.252"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(
            addresses: ["fdfe:dcba:9876::1"],
            networkPrefixLengths: [126]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        // DNS — route all DNS through sing-box (leak prevention)
        let dns = NEDNSSettings(servers: ["172.19.0.1"])
        dns.matchDomains = [""]   // match all domains
        settings.dnsSettings = dns

        // MTU
        settings.mtu = 9000

        return settings
    }
}

// ── Errors ────────────────────────────────────────────────────────────────────

enum TunnelError: LocalizedError {
    case missingConfig
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .missingConfig:   return "Missing sing-box configuration"
        case .binaryNotFound:  return "sing-box binary not found in extension bundle"
        }
    }
}
