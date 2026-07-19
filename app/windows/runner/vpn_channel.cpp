// Nexus — Windows Platform Channel
// Bridges Flutter ↔ WinTUN driver + sing-box process via MethodChannel
// Requires: WinTUN driver (wintun.dll) and admin elevation

#include "vpn_channel.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <shlwapi.h>
#include <string>
#include <vector>
#include <memory>
#include <thread>

// WinTUN API typedefs (loaded dynamically from wintun.dll)
typedef WINTUN_ADAPTER_HANDLE (WINAPI *CreateAdapter_t)(LPCWSTR, LPCWSTR, const GUID*);
typedef void (WINAPI *CloseAdapter_t)(WINTUN_ADAPTER_HANDLE);
typedef WINTUN_SESSION_HANDLE (WINAPI *StartSession_t)(WINTUN_ADAPTER_HANDLE, DWORD);
typedef void (WINAPI *EndSession_t)(WINTUN_SESSION_HANDLE);

namespace nexus {

static HANDLE g_singboxProcess = NULL;
static HMODULE g_wintun = NULL;
static WINTUN_ADAPTER_HANDLE g_adapter = NULL;

void VpnChannel::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "com.nexus/proxy",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<VpnChannel>();
    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
}

void VpnChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    const auto& method = call.method_name();

    if (method == "startVpn" || method == "startTunnel") {
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) { result->Error("INVALID_ARGS", "Expected map"); return; }

        const auto& configJson = std::get<std::string>(args->at(flutter::EncodableValue("config")));
        StartVpn(configJson, std::move(result));
    }
    else if (method == "stopVpn" || method == "stopTunnel") {
        StopVpn(std::move(result));
    }
    else if (method == "getStats") {
        GetStats(std::move(result));
    }
    else if (method == "setSystemProxy") {
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) { result->Error("INVALID_ARGS", "Expected map"); return; }
        const auto& host = std::get<std::string>(args->at(flutter::EncodableValue("host")));
        int port = 7890;
        auto portIt = args->find(flutter::EncodableValue("port"));
        if (portIt != args->end()) {
            if (std::holds_alternative<int>(portIt->second)) {
                port = std::get<int>(portIt->second);
            } else if (std::holds_alternative<int64_t>(portIt->second)) {
                port = static_cast<int>(std::get<int64_t>(portIt->second));
            }
        }
        SetSystemProxy(host.c_str(), port);
        result->Success(flutter::EncodableValue(true));
    }
    else if (method == "clearSystemProxy") {
        ClearSystemProxy();
        result->Success(flutter::EncodableValue(true));
    }
    else {
        result->NotImplemented();
    }
}

void VpnChannel::StartVpn(
    const std::string& configJson,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    // 1. Write sing-box config to temp file
    char tmpPath[MAX_PATH];
    GetTempPathA(MAX_PATH, tmpPath);
    std::string configFile = std::string(tmpPath) + "nexus-singbox.json";

    HANDLE hFile = CreateFileA(configFile.c_str(), GENERIC_WRITE, 0, NULL,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        result->Error("IO_ERROR", "Cannot write config file");
        return;
    }
    DWORD written;
    WriteFile(hFile, configJson.c_str(), (DWORD)configJson.size(), &written, NULL);
    CloseHandle(hFile);

    // 2. Load WinTUN adapter
    g_wintun = LoadLibraryW(L"wintun.dll");
    if (!g_wintun) {
        result->Error("WINTUN_ERROR", "wintun.dll not found — install WinTUN driver");
        return;
    }

    // 3. Resolve sing-box.exe next to this process (or cores\ subfolder)
    char modulePath[MAX_PATH];
    GetModuleFileNameA(NULL, modulePath, MAX_PATH);
    PathRemoveFileSpecA(modulePath);
    std::string exeDir(modulePath);
    std::string candidates[] = {
        exeDir + "\\sing-box.exe",
        exeDir + "\\cores\\sing-box.exe",
    };
    std::string singboxPath;
    for (const auto& c : candidates) {
        if (GetFileAttributesA(c.c_str()) != INVALID_FILE_ATTRIBUTES) {
            singboxPath = c;
            break;
        }
    }
    if (singboxPath.empty()) {
        result->Error("PROCESS_ERROR",
            "sing-box.exe not found next to app or in cores\\");
        return;
    }

    std::string cmd = "\"" + singboxPath + "\" run -c \"" + configFile + "\"";
    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi;
    // CreateProcess may mutate the command line buffer.
    std::vector<char> cmdBuf(cmd.begin(), cmd.end());
    cmdBuf.push_back('\0');

    if (!CreateProcessA(NULL, cmdBuf.data(), NULL, NULL, FALSE,
        CREATE_NO_WINDOW, NULL, exeDir.c_str(), &si, &pi)) {
        result->Error("PROCESS_ERROR", "Failed to start sing-box.exe");
        return;
    }
    g_singboxProcess = pi.hProcess;
    CloseHandle(pi.hThread);

    // 4. Set system proxy to sing-box mixed port
    SetSystemProxy("127.0.0.1", 7890);

    result->Success(flutter::EncodableValue(true));
}

void VpnChannel::StopVpn(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    if (g_singboxProcess) {
        TerminateProcess(g_singboxProcess, 0);
        CloseHandle(g_singboxProcess);
        g_singboxProcess = NULL;
    }
    ClearSystemProxy();
    result->Success(flutter::EncodableValue(true));
}

void VpnChannel::GetStats(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    // In production: query Clash API http://127.0.0.1:9090/traffic via WinHTTP
    flutter::EncodableMap stats;
    stats[flutter::EncodableValue("uploadMbps")]   = flutter::EncodableValue(2.5);
    stats[flutter::EncodableValue("downloadMbps")] = flutter::EncodableValue(15.2);
    stats[flutter::EncodableValue("latencyMs")]    = flutter::EncodableValue(42);
    result->Success(flutter::EncodableValue(stats));
}

// Set Windows system proxy
void VpnChannel::SetSystemProxy(const char* host, int port) {
    // Uses WinINet registry keys for system-wide proxy
    HKEY hKey;
    RegOpenKeyExA(HKEY_CURRENT_USER,
        "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
        0, KEY_SET_VALUE, &hKey);
    RegSetValueExA(hKey, "ProxyEnable", 0, REG_DWORD, (BYTE*)"\x01\x00\x00\x00", 4);
    std::string proxy = std::string(host) + ":" + std::to_string(port);
    RegSetValueExA(hKey, "ProxyServer", 0, REG_SZ,
        (BYTE*)proxy.c_str(), (DWORD)(proxy.size() + 1));
    RegCloseKey(hKey);
    InternetSetOptionA(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
    InternetSetOptionA(NULL, INTERNET_OPTION_REFRESH, NULL, 0);
}

void VpnChannel::ClearSystemProxy() {
    HKEY hKey;
    RegOpenKeyExA(HKEY_CURRENT_USER,
        "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
        0, KEY_SET_VALUE, &hKey);
    RegSetValueExA(hKey, "ProxyEnable", 0, REG_DWORD, (BYTE*)"\x00\x00\x00\x00", 4);
    RegCloseKey(hKey);
    InternetSetOptionA(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
    InternetSetOptionA(NULL, INTERNET_OPTION_REFRESH, NULL, 0);
}

} // namespace nexus
