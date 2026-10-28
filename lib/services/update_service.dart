import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────

class UpdateInfo {
  final String version;
  final String notes;
  final String downloadUrl;
  final bool required;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.required,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Checks the latest GitHub release and returns [UpdateInfo] when it is newer
/// than this build and carries an installer for this platform, or `null` when
/// the app is up to date, the platform has no in-app updates, or the check
/// fails.
///
/// All failures are swallowed — update checking must never block startup.
class UpdateService {
  const UpdateService._();
  static const instance = UpdateService._();

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: {
      'User-Agent': 'WiseTVPlayer',
      'Accept': 'application/vnd.github+json',
    },
  ));

  /// Release asset this platform installs from; null = no in-app updates
  /// (web/TV packages, iOS/macOS stores).
  static RegExp? get _assetName {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => RegExp(r'^WiseTVPlayer\.apk$'),
      TargetPlatform.windows => RegExp(r'^WiseVodPlayer-Setup-.*\.exe$'),
      _ => null,
    };
  }

  static bool get supported => _assetName != null;

  Future<UpdateInfo?> checkForUpdate() async {
    final wanted = _assetName;
    if (wanted == null) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final resp = await _dio.get<Map<String, dynamic>>(
        AppConstants.updateCheckUrl,
        options: Options(responseType: ResponseType.json),
      );
      final data = resp.data;
      if (data == null) return null;

      final remoteVersion =
          (data['tag_name'] as String? ?? '').replaceFirst(RegExp('^[vV]'), '');
      if (remoteVersion.isEmpty || !_isNewer(remoteVersion, info.version)) {
        return null;
      }

      final assets = (data['assets'] as List?) ?? const [];
      final asset = assets.whereType<Map>().where((a) {
        final name = a['name'];
        return name is String && wanted.hasMatch(name);
      }).firstOrNull;
      final url = asset?['browser_download_url'];
      if (url is! String || url.isEmpty) return null;

      final body = data['body'] as String? ?? '';
      return UpdateInfo(
        version: remoteVersion,
        notes: _plainNotes(body),
        downloadUrl: url,
        // A release is mandatory when its notes contain "[required]".
        required: body.toLowerCase().contains('[required]'),
      );
    } catch (_) {
      // Network error, rate limit, parse error — all silently ignored.
      return null;
    }
  }

  /// Release notes are Markdown; the dialog shows plain, shortened text.
  static String _plainNotes(String markdown) {
    final text = markdown
        .replaceAll('[required]', '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.length > 700 ? '${text.substring(0, 697)}…' : text;
  }

  /// Returns true if [remote] is strictly newer than [local].
  /// Compares dot-separated integer segments (1.2.3 style).
  bool _isNewer(String remote, String local) {
    int seg(String v, int i) {
      final parts = v.split('.');
      return i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    }

    final segments =
        [remote, local].map((v) => v.split('.').length).reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < segments; i++) {
      final r = seg(remote, i);
      final l = seg(local, i);
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }
}
