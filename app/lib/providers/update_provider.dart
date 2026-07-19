import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStatus { idle, checking, upToDate, available, error }

class UpdateProvider extends ChangeNotifier {
  static final Uri _latestReleaseApi = Uri.parse(
    'https://api.github.com/repos/Jas0n0ss/nexus/releases/latest',
  );
  static const _lastCheckKey = 'appUpdateLastCheck';
  static const _automaticInterval = Duration(hours: 12);

  UpdateStatus status = UpdateStatus.idle;
  String currentVersion = '—';
  String? latestVersion;
  String? releaseUrl;
  String? downloadUrl;
  String? errorMessage;
  DateTime? lastCheckedAt;
  bool _automaticConfigured = false;

  bool get hasUpdate => status == UpdateStatus.available;

  Future<void> configureAutomaticCheck(bool enabled) async {
    if (!enabled || _automaticConfigured) return;
    _automaticConfigured = true;
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_lastCheckKey);
    if (lastMillis != null) {
      lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      if (DateTime.now().difference(lastCheckedAt!) < _automaticInterval) {
        notifyListeners();
        return;
      }
    }
    await checkForUpdates(silent: true);
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    if (status == UpdateStatus.checking) return;
    status = UpdateStatus.checking;
    errorMessage = null;
    notifyListeners();

    try {
      final package = await PackageInfo.fromPlatform();
      currentVersion = package.version;
      final response = await http.get(
        _latestReleaseApi,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'Nexus-Update-Checker',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw HttpException('GitHub API ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      latestVersion = data['tag_name']?.toString().replaceFirst('v', '');
      releaseUrl = data['html_url']?.toString();
      downloadUrl = _selectAsset(data['assets']);
      lastCheckedAt = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, lastCheckedAt!.millisecondsSinceEpoch);

      status = isNewerVersion(latestVersion, currentVersion)
          ? UpdateStatus.available
          : UpdateStatus.upToDate;
    } catch (e) {
      status = UpdateStatus.error;
      errorMessage = silent ? null : '检查失败：$e';
    }
    notifyListeners();
  }

  Future<bool> openUpdate() async {
    final target = downloadUrl ?? releaseUrl;
    if (target == null) return false;
    return launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );
  }

  String? _selectAsset(dynamic rawAssets) {
    if (rawAssets is! List) return null;
    final assets = rawAssets.whereType<Map>().map((raw) {
      return Map<String, dynamic>.from(raw);
    });

    bool matches(String name) {
      final lower = name.toLowerCase();
      if (kIsWeb) return false;
      if (Platform.isWindows) {
        return lower.endsWith('-windows-setup.exe');
      }
      if (Platform.isMacOS) return lower.endsWith('-macos.dmg');
      if (Platform.isLinux) return lower.endsWith('.appimage');
      if (Platform.isAndroid) {
        return lower.endsWith('-android-universal.apk');
      }
      if (Platform.isIOS) return lower.endsWith('.ipa');
      return false;
    }

    for (final asset in assets) {
      final name = asset['name']?.toString() ?? '';
      if (matches(name)) return asset['browser_download_url']?.toString();
    }
    return null;
  }

  @visibleForTesting
  static bool isNewerVersion(String? candidate, String current) {
    if (candidate == null || candidate.isEmpty) return false;
    List<int> parse(String value) {
      final clean = value.replaceFirst(RegExp(r'^v'), '').split('-').first;
      return clean
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: true);
    }

    final a = parse(candidate);
    final b = parse(current);
    final length = a.length > b.length ? a.length : b.length;
    while (a.length < length) a.add(0);
    while (b.length < length) b.add(0);
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
