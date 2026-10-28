import 'update_service.dart';

/// Web builds have no in-app installer.
class UpdateInstaller {
  UpdateInstaller._();

  static bool get supported => false;

  static Future<String> download(
    UpdateInfo info, {
    required void Function(double progress) onProgress,
  }) =>
      throw UnsupportedError('No in-app updates on this platform');

  static Future<String?> install(String path) =>
      throw UnsupportedError('No in-app updates on this platform');
}
