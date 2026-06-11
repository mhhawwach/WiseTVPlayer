import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/perf/perf_profile.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/text_scale_provider.dart';
import 'core/providers/wallpaper_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/focus_recovery.dart';

class WiseTVPlayerApp extends ConsumerWidget {
  const WiseTVPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(appRouterProvider);
    final theme     = ref.watch(themeProvider);
    final wallpaper = ref.watch(wallpaperProvider);
    final locale    = ref.watch(localeProvider);
    final textScale = ref.watch(textScaleProvider);

    // On the low tier the heavy wallpaper image is suppressed (decode + extra
    // overdraw); the Scaffold then gets a solid themed background instead.
    final showWallpaper = wallpaper.hasWallpaper && Perf.wallpaperAllowed;

    final themeData = AppTheme.buildFor(
      theme,
      hasWallpaper: showWallpaper,
    );

    return MaterialApp.router(
      title: 'WiseVodPlayer',
      debugShowCheckedModeBanner: false,

      // Let a mouse / trackpad drag-scroll on desktop & web (Flutter's default
      // only drag-scrolls with touch), so the horizontal home rows can be
      // scrolled left/right with a pointer.
      scrollBehavior: const _AppScrollBehavior(),

      // ── Locale & RTL ──────────────────────────────────────────────────────
      locale: locale.locale,
      supportedLocales: AppLocale.values.map((l) => l.locale).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Theme ─────────────────────────────────────────────────────────────
      theme:     themeData,
      darkTheme: themeData,
      themeMode: ThemeMode.dark,

      // ── Builder: app-wide text scaling + optional wallpaper layer ─────────
      // Text scale is applied as a fixed TextScaler so the in-app accessibility
      // setting is honoured even when the system scale is locked (common on TV).
      // The wallpaper, when active, sits behind the whole tree; Scaffold
      // backgrounds are transparent (set in AppTheme.buildFor).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        Widget result = MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(textScale.factor),
          ),
          child: child!,
        );
        if (showWallpaper) {
          result = Stack(
            children: [
              WallpaperBackground(mode: wallpaper),
              result,
            ],
          );
        }
        // Recover D-pad focus if it's ever lost (TV only) so the highlight
        // never just disappears requiring blind presses to get it back.
        result = FocusRecovery(child: result);
        // On the web build (webOS) the default arrow-key directional traversal
        // doesn't fire reliably, so drive it explicitly. No-op off the web.
        result = WebDirectionalFocus(child: result);
        // NOTE: hardware-Back interception is done at the shell-route level
        // (see HomeShell) — a handler here, above go_router's Router, never
        // sees the event because the Router consumes it first.
        return result;
      },

      routerConfig: router,
    );
  }
}

/// Adds mouse + trackpad (and stylus) to the drag devices, so pointer drags
/// scroll lists/rows on desktop and web — not just touch. Mouse-wheel and
/// trackpad gestures continue to work as before.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
