import 'dart:io';
import 'package:flutter/services.dart';

/// Detects whether the app is running on a TV/box device.
/// On Android, checks the leanback feature; on others defaults to false.
class DeviceUtils {
  static bool? _isTV;

  static Future<bool> get isTV async {
    if (_isTV != null) return _isTV!;
    if (!Platform.isAndroid) {
      _isTV = false;
      return false;
    }
    try {
      const channel = MethodChannel('com.wiseapps.wisetv/device');
      _isTV = await channel.invokeMethod<bool>('isTV') ?? false;
    } catch (_) {
      _isTV = false;
    }
    return _isTV!;
  }

  /// Synchronous TV check — only valid after [isTV] has been awaited once.
  static bool get isTVSync => _isTV ?? false;

  static Future<void> warmup() async => isTV;
}
