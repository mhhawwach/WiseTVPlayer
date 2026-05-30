import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CrashReporter
//
// Captures uncaught Flutter / Dart / platform errors and persists them to a
// rolling on-device log so crashes are visible without a backend. A remote
// sink (e.g. Sentry) can be slotted into [_forward] later without touching
// call sites.
// ─────────────────────────────────────────────────────────────────────────────

class CrashEntry {
  final DateTime time;
  final String error;
  final String stack;
  final String source;

  const CrashEntry({
    required this.time,
    required this.error,
    required this.stack,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'ts': time.toIso8601String(),
        'error': error,
        'stack': stack,
        'source': source,
      };

  factory CrashEntry.fromJson(Map<String, dynamic> j) => CrashEntry(
        time: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime(2000),
        error: j['error'] as String? ?? '',
        stack: j['stack'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );

  String get formatted {
    final t = time.toLocal().toString().split('.').first;
    final buf = StringBuffer()
      ..writeln('[$t] ($source)')
      ..writeln(error);
    if (stack.isNotEmpty) buf.writeln(stack);
    return buf.toString();
  }
}

class CrashReporter {
  CrashReporter._();

  static const _boxName = 'crash_log';
  static const _maxEntries = 50;
  static Box<String>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Install global error handlers. Call inside the same zone as runApp.
  static void install() {
    // 1. Flutter framework errors (build/layout/paint).
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      if (kDebugMode) FlutterError.presentError(details);
      record(details.exception, details.stack, source: 'flutter');
    };

    // 2. Uncaught async errors that reach the platform dispatcher.
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, source: 'platform');
      return true; // handled — don't crash the isolate
    };
  }

  /// Persist a single error. Safe to call before [init] (silently drops).
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String source = 'manual',
  }) async {
    final box = _box;
    if (box == null) {
      // ignore: avoid_print
      if (kDebugMode) print('CrashReporter(uninit): $error');
      return;
    }
    try {
      final entry = CrashEntry(
        time: DateTime.now(),
        error: error.toString(),
        stack: stack?.toString() ?? '',
        source: source,
      );
      // Key is millis so natural string sort == chronological.
      final key = DateTime.now().microsecondsSinceEpoch.toString();
      await box.put(key, jsonEncode(entry.toJson()));

      // Trim oldest beyond cap.
      if (box.length > _maxEntries) {
        final keys = box.keys.map((e) => e.toString()).toList()..sort();
        final excess = box.length - _maxEntries;
        for (var i = 0; i < excess; i++) {
          await box.delete(keys[i]);
        }
      }
      _forward(entry);
    } catch (_) {
      // Never let the reporter itself throw.
    }
  }

  /// Most-recent-first list of stored crashes.
  static List<CrashEntry> recent() {
    final box = _box;
    if (box == null) return [];
    final entries = box.values
        .map((v) {
          try {
            return CrashEntry.fromJson(jsonDecode(v) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<CrashEntry>()
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return entries;
  }

  static bool get hasCrashes => (_box?.isNotEmpty ?? false);
  static int get count => _box?.length ?? 0;

  static Future<void> clear() async => _box?.clear();

  /// Hook for a remote sink (Sentry/Crashlytics). No-op for now.
  static void _forward(CrashEntry entry) {
    // e.g. Sentry.captureException(entry.error, stackTrace: entry.stack);
  }
}
