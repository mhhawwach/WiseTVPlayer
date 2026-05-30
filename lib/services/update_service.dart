import 'package:dio/dio.dart';
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

/// Checks a remote `version.json` endpoint and returns [UpdateInfo] when a
/// newer version exists, or `null` when the app is up-to-date or the check fails.
///
/// All failures are swallowed — update checking must never block startup.
class UpdateService {
  const UpdateService._();
  static const instance = UpdateService._();

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
    headers: {'User-Agent': 'WiseTVPlayer/1.0'},
  ));

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final resp = await _dio.get<Map<String, dynamic>>(
        AppConstants.updateCheckUrl,
        options: Options(responseType: ResponseType.json),
      );

      final data = resp.data;
      if (data == null) return null;

      final remoteVersion = data['version'] as String? ?? '';
      if (remoteVersion.isEmpty) return null;

      if (!_isNewer(remoteVersion, info.version)) return null;

      return UpdateInfo(
        version: remoteVersion,
        notes: data['notes'] as String? ?? '',
        downloadUrl: data['download_url'] as String? ?? '',
        required: data['required'] as bool? ?? false,
      );
    } catch (_) {
      // Network error, parse error, placeholder URL — all silently ignored.
      return null;
    }
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
