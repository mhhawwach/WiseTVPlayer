import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

/// Downloads a release asset and hands it to the OS installer, so devices
/// without a browser (most Android TVs) can still update in-app.
class UpdateInstaller {
  UpdateInstaller._();

  static const _channel = MethodChannel('com.wiseapps.wisetv/device');

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Downloads [info]'s asset; returns the local file path.
  static Future<String> download(
    UpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    // Android shares files with the installer from cache/updates/ only (see
    // res/xml/update_paths.xml).
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final name = Uri.parse(info.downloadUrl).pathSegments.last;
    final path = '${dir.path}/$name';
    await Dio().download(
      info.downloadUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );
    return path;
  }

  /// Starts the installer. Returns null once it is running, otherwise a short
  /// message to show the user.
  static Future<String?> install(String path) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await Process.start(path, const [], mode: ProcessStartMode.detached);
      // Quit so the installer can replace the running executable.
      exit(0);
    }
    final result =
        await _channel.invokeMethod<String>('installApk', {'path': path});
    return switch (result) {
      'started' => null,
      'needs_permission' =>
        'Allow "Install unknown apps" for WiseVodPlayer on the screen that '
            'just opened, then come back and choose Update again.',
      _ => 'Could not start the installer${result != null ? ' ($result)' : ''}.',
    };
  }
}
