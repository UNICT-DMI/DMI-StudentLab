import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateStatus {
  upToDate,
  optional,
  required,
  maintenance,
}

class AppUpdateInfo {
  final AppUpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String message;
  final String updateUrl;

  const AppUpdateInfo({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.message,
    required this.updateUrl,
  });

  bool get updateAvailable =>
      status == AppUpdateStatus.optional || status == AppUpdateStatus.required;

  bool get updateRequired => status == AppUpdateStatus.required;

  bool get isMaintenance => status == AppUpdateStatus.maintenance;
}

class AppUpdateService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';

  Future<AppUpdateInfo> checkForUpdates() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;

    final Uri url = Uri.parse('$_baseUrl/app_version');

    final http.Response response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Impossibile verificare la versione dell\'app.');
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Risposta versione non valida.');
    }

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(decoded);

    final String latestVersion =
        data['latest_version']?.toString() ?? currentVersion;

    final String minimumVersion =
        data['minimum_version']?.toString() ?? currentVersion;

    final bool forceUpdate = data['force_update'] == true;
    final bool maintenance = data['maintenance'] == true;
    final String message = data['message']?.toString() ?? '';
    final String updateUrl = _resolveUpdateUrl(data);

    if (maintenance) {
      return AppUpdateInfo(
        status: AppUpdateStatus.maintenance,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        message: message,
        updateUrl: updateUrl,
      );
    }

    final bool belowMinimum =
        _compareVersions(currentVersion, minimumVersion) < 0;

    if (forceUpdate || belowMinimum) {
      return AppUpdateInfo(
        status: AppUpdateStatus.required,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        message: message,
        updateUrl: updateUrl,
      );
    }

    final bool newerAvailable =
        _compareVersions(currentVersion, latestVersion) < 0;

    if (newerAvailable) {
      return AppUpdateInfo(
        status: AppUpdateStatus.optional,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        message: message,
        updateUrl: updateUrl,
      );
    }

    return AppUpdateInfo(
      status: AppUpdateStatus.upToDate,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minimumVersion: minimumVersion,
      message: message,
      updateUrl: updateUrl,
    );
  }

  int _compareVersions(String first, String second) {
    final List<int> a = _parseVersion(first);
    final List<int> b = _parseVersion(second);

    final int length = a.length > b.length ? a.length : b.length;

    for (int index = 0; index < length; index++) {
      final int firstPart = index < a.length ? a[index] : 0;
      final int secondPart = index < b.length ? b[index] : 0;

      if (firstPart < secondPart) {
        return -1;
      }

      if (firstPart > secondPart) {
        return 1;
      }
    }

    return 0;
  }

  List<int> _parseVersion(String version) {
    final String cleanVersion =
        version.split('+').first.split('-').first;

    return cleanVersion
        .split('.')
        .map((String value) => int.tryParse(value) ?? 0)
        .toList();
  }

  String _resolveUpdateUrl(Map<String, dynamic> data) {
    if (kIsWeb) {
      return data['web_url']?.toString() ??
          data['update_url']?.toString() ??
          '';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return data['android_url']?.toString() ?? '';
      case TargetPlatform.iOS:
        return data['ios_url']?.toString() ?? '';
      case TargetPlatform.windows:
        return data['windows_url']?.toString() ?? '';
      case TargetPlatform.linux:
        return data['linux_url']?.toString() ?? '';
      case TargetPlatform.macOS:
        return data['macos_url']?.toString() ?? '';
      case TargetPlatform.fuchsia:
        return '';
    }
  }
}