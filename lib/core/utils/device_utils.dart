import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects whether the app is running on a TV/box device.
/// On Android, checks the leanback feature; on others defaults to false.
class DeviceUtils {
  static bool? _isTV;

  // webOS / Tizen builds pass --dart-define=FLUTTER_TARGET_PLATFORM=<platform>.
  // Those are always TVs, so we can resolve isTV synchronously without a channel.
  // ignore: do_not_use_environment
  static const _targetPlatform =
      String.fromEnvironment('FLUTTER_TARGET_PLATFORM');

  static Future<bool> get isTV async {
    if (_isTV != null) return _isTV!;
    // Smart-TV web builds (webOS / Tizen) are always a TV with a remote.
    if (_targetPlatform.contains('webos') ||
        _targetPlatform.contains('tizen')) {
      _isTV = true;
      return true;
    }
    // Any other web target, or non-Android native, has no leanback channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
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
