import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Wraps the Android PiP MethodChannel + EventChannel.
///
/// All methods are safe no-ops on non-Android platforms so the same call-sites
/// compile for iOS / desktop without any `Platform.isAndroid` guards scattered
/// throughout the UI code.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _method = MethodChannel('com.wiseapps.wisetv/device');
  static const _event  = EventChannel('com.wiseapps.wisetv/pip_events');

  Stream<bool>? _stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// True if this device supports PiP (Android 8+, non-TV).
  Future<bool> get isSupported async {
    if (!Platform.isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request PiP mode with the given aspect ratio (default 16 : 9).
  /// Returns true if the OS accepted the request.
  Future<bool> enter({int width = 16, int height = 9}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>(
            'enterPip',
            {'width': width, 'height': height},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Broadcast stream of PiP-mode transitions.
  /// Emits `true` when the window shrinks into PiP, `false` when restored.
  Stream<bool> get changes {
    if (!Platform.isAndroid) return const Stream.empty();
    _stream ??= _event
        .receiveBroadcastStream()
        .map((v) => v as bool)
        .asBroadcastStream();
    return _stream!;
  }
}
