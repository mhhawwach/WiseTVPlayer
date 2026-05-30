import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'core/diagnostics/crash_reporter.dart';
import 'core/perf/perf_profile.dart';
import 'core/storage/storage_service.dart';
import 'core/utils/content_cache_service.dart';

void main() {
  // Run everything inside a guarded zone so uncaught async errors are caught.
  runZonedGuarded(_bootstrap, (error, stack) {
    CrashReporter.record(error, stack, source: 'zone');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape — IPTV is always landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full immersive mode — no status/nav bars during playback
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // ── Minimal init required BEFORE the first frame ─────────────────────────
  // Only what the splash/profile screens read. Heavy/lazy work is deferred
  // below so the splash paints fast (was a 5–10s black screen on TV).
  await Hive.initFlutter();
  await StorageService.init();        // playlists + profiles (small boxes)

  // Resolve the performance tier (saved choice + native low-end detection) and
  // size the in-memory image cache accordingly: 250 MB on capable hardware,
  // a lean 64 MB on low-RAM TVs that would otherwise trip the low-memory killer.
  await Perf.init();
  Perf.applyImageCache();

  await CrashReporter.init();
  CrashReporter.install();

  runApp(
    const ProviderScope(
      child: WiseTVPlayerApp(),
    ),
  );

  // ── Deferred init (NOT on the startup critical path) ─────────────────────
  // The content cache box can be large; opening it (even lazily) takes seconds
  // on weak TV flash, so it runs in the background after the first frame. Until
  // it's ready the cache reports "miss" and content loads from the network.
  // media_kit / wakelock are only needed once playback starts.
  unawaited(ContentCacheService.init());
  MediaKit.ensureInitialized();
  WakelockPlus.enable();
}
