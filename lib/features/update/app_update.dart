import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Base URL of the self-hosted update server (same box as the TTS server).
/// Change this if devices reach the server via a different address.
const String kUpdateBaseUrl = 'http://100.66.1.4:8000';

/// True when [remoteCode] represents a newer build than [currentCode].
bool updateAvailable(int remoteCode, int currentCode) => remoteCode > currentCode;

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.url,
    this.notes,
  });

  final String versionName;
  final int versionCode;
  final String url;
  final String? notes;
}

/// Checks the self-hosted server for a newer Android build and opens the APK
/// download. iOS updates go through ESign, so [check] is a no-op there.
class AppUpdater {
  const AppUpdater({this._dio, this._baseUrl = kUpdateBaseUrl});

  final Dio? _dio;
  final String _baseUrl;

  Future<AppUpdateInfo?> check() async {
    if (!Platform.isAndroid) return null;
    final dio = _dio ?? Dio();
    final resp = await dio.get<Map<String, dynamic>>(
      '$_baseUrl/nvr/update/android.json',
      options: Options(
        responseType: ResponseType.json,
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    final data = resp.data;
    if (data == null) return null;
    final remoteCode = (data['versionCode'] as num?)?.toInt();
    final url = data['url'] as String?;
    final name = data['versionName'] as String?;
    if (remoteCode == null || url == null || url.isEmpty || name == null) {
      return null;
    }
    final info = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(info.buildNumber) ?? 0;
    if (!updateAvailable(remoteCode, currentCode)) return null;
    return AppUpdateInfo(
      versionName: name,
      versionCode: remoteCode,
      url: url,
      notes: data['notes'] as String?,
    );
  }

  Future<bool> openDownload(AppUpdateInfo info) =>
      launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
}

/// Checks for an update and, if one is available, prompts the user. Safe to
/// call from a post-frame callback; never throws. When [announceNoUpdate] is
/// true (manual check), shows a snackbar if already up to date.
Future<void> maybePromptUpdate(
  BuildContext context, {
  AppUpdater updater = const AppUpdater(),
  bool announceNoUpdate = false,
}) async {
  AppUpdateInfo? info;
  try {
    info = await updater.check();
  } catch (_) {
    info = null;
  }
  if (!context.mounted) return;
  if (info == null) {
    if (announceNoUpdate) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已是最新版本')));
    }
    return;
  }
  final update = info;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('发现新版本 ${update.versionName}'),
      content: Text(
        update.notes != null && update.notes!.isNotEmpty
            ? update.notes!
            : '有可用更新。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('以后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('下载更新'),
        ),
      ],
    ),
  );
  if (go == true) {
    try {
      await updater.openDownload(update);
    } catch (_) {}
  }
}
