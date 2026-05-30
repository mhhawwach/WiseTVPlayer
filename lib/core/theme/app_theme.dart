import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WiseTheme enum — one entry per selectable theme
// ─────────────────────────────────────────────────────────────────────────────

enum WiseTheme {
  midnight(
    label: 'Midnight',
    description: 'Deep dark with violet accents',
    previewBg: Color(0xFF0A0A0F),
    previewPrimary: Color(0xFF6C63FF),
    previewAccent: Color(0xFF00D4AA),
  ),
  amoled(
    label: 'Amoled',
    description: 'Pure black · saves battery on OLED',
    previewBg: Color(0xFF000000),
    previewPrimary: Color(0xFF2979FF),
    previewAccent: Color(0xFF00BCD4),
  ),
  ember(
    label: 'Ember',
    description: 'Warm dark with orange accents',
    previewBg: Color(0xFF0D0905),
    previewPrimary: Color(0xFFF57C00),
    previewAccent: Color(0xFFFFB300),
  );

  const WiseTheme({
    required this.label,
    required this.description,
    required this.previewBg,
    required this.previewPrimary,
    required this.previewAccent,
  });

  final String label;
  final String description;
  /// Used only in the theme-picker preview cards — not live AppColors.
  final Color previewBg;
  final Color previewPrimary;
  final Color previewAccent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-theme palette (immutable data, three instances)
// ─────────────────────────────────────────────────────────────────────────────

class _Palette {
  final Color background;
  final Color surface;
  final Color card;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color focusBorder;
  final Color divider;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const _Palette({
    required this.background,
    required this.surface,
    required this.card,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.focusBorder,
    required this.divider,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });
}

// ── Midnight — deep dark purple/violet ───────────────────────────────────────
const _midnightPalette = _Palette(
  background:       Color(0xFF0A0A0F),
  surface:          Color(0xFF13131A),
  card:             Color(0xFF1E1E28),
  surfaceVariant:   Color(0xFF1C1C26),
  primary:          Color(0xFF6C63FF),
  primaryDark:      Color(0xFF4A44CC),
  accent:           Color(0xFF00D4AA),
  focusBorder:      Color(0xFF6C63FF),
  divider:          Color(0xFF222230),
  shimmerBase:      Color(0xFF1E1E28),
  shimmerHighlight: Color(0xFF2A2A38),
);

// ── Amoled — pure black with blue accents ────────────────────────────────────
const _amoledPalette = _Palette(
  background:       Color(0xFF000000),
  surface:          Color(0xFF0D0D12),
  card:             Color(0xFF121218),
  surfaceVariant:   Color(0xFF18181E),
  primary:          Color(0xFF2979FF),
  primaryDark:      Color(0xFF1565C0),
  accent:           Color(0xFF00BCD4),
  focusBorder:      Color(0xFF448AFF),
  divider:          Color(0xFF1A1A22),
  shimmerBase:      Color(0xFF121218),
  shimmerHighlight: Color(0xFF1E1E28),
);

// ── Ember — warm dark with orange/amber accents ───────────────────────────────
const _emberPalette = _Palette(
  background:       Color(0xFF0D0905),
  surface:          Color(0xFF1A120C),
  card:             Color(0xFF221A13),
  surfaceVariant:   Color(0xFF2A2018),
  primary:          Color(0xFFF57C00),
  primaryDark:      Color(0xFFBF360C),
  accent:           Color(0xFFFFB300),
  focusBorder:      Color(0xFFFF9800),
  divider:          Color(0xFF2A1F18),
  shimmerBase:      Color(0xFF221A13),
  shimmerHighlight: Color(0xFF302418),
);

// ─────────────────────────────────────────────────────────────────────────────
// Active palette — swapped before MaterialApp rebuilds (Dart is single-threaded,
// so this is safe: provider change → _active updated → full widget tree rebuild)
// ─────────────────────────────────────────────────────────────────────────────

_Palette _active = _midnightPalette;

// ─────────────────────────────────────────────────────────────────────────────
// AppColors — the public API used across the whole app
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Theme-dependent (non-const getters, update when theme changes) ──────────
  static Color get background       => _active.background;
  static Color get surface          => _active.surface;
  static Color get card             => _active.card;
  static Color get surfaceVariant   => _active.surfaceVariant;
  static Color get primary          => _active.primary;
  static Color get primaryDark      => _active.primaryDark;
  static Color get accent           => _active.accent;
  static Color get focusBorder      => _active.focusBorder;
  static Color get divider          => _active.divider;
  static Color get shimmerBase      => _active.shimmerBase;
  static Color get shimmerHighlight => _active.shimmerHighlight;

  // ── Theme-invariant (const — identical across all three dark themes) ─────────
  // Neutral greys (no blue tint) lightened for strong contrast over the
  // (often blue) wallpaper. textPrimary is pure white.
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC4C4CC);
  static const Color textMuted     = Color(0xFF9A9AA6);
  static const Color liveRed       = Color(0xFFFF3B30);

  // Bright, theme-invariant D-pad focus highlight. Deliberately a different hue
  // from the (theme-coloured) "selected" primary so the focused element is
  // unmistakable on a TV from across the room.
  static const Color focus         = Color(0xFF1AE5FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — produces a ThemeData for any WiseTheme
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  /// Call this from MaterialApp.theme. Updates the active palette and returns
  /// a freshly-built ThemeData consistent with the new colors.
  ///
  /// [hasWallpaper] — when true the scaffold background is set to
  /// [Colors.transparent] so the wallpaper layer in the widget tree shows
  /// through. Individual player screens override with Colors.black explicitly
  /// so this has no effect on playback UI.
  static ThemeData buildFor(WiseTheme theme, {bool hasWallpaper = false}) {
    _active = switch (theme) {
      WiseTheme.midnight => _midnightPalette,
      WiseTheme.amoled   => _amoledPalette,
      WiseTheme.ember    => _emberPalette,
    };
    return _build(transparentScaffold: hasWallpaper);
  }

  static ThemeData _build({bool transparentScaffold = false}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor:
        transparentScaffold ? const Color(0x00000000) : AppColors.background,
    colorScheme: ColorScheme.dark(
      surface:                 AppColors.background,
      surfaceContainerHighest: AppColors.surfaceVariant,
      primary:                 AppColors.primary,
      secondary:               AppColors.accent,
      onSurface:               AppColors.textPrimary,
      onPrimary:               Colors.white,
    ),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0x00000000), // set per-screen via scaffoldBg
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    // Stronger focus highlight so Material list tiles / buttons are clearly
    // selected when navigating with a TV remote (10-foot UI). Uses the bright
    // theme-invariant focus colour for maximum visibility.
    focusColor:     AppColors.focus.withValues(alpha: 0.42),
    hoverColor:     AppColors.primary.withValues(alpha: 0.20),
    highlightColor: AppColors.primary.withValues(alpha: 0.12),
    splashColor:    AppColors.primary.withValues(alpha: 0.12),
  );

  // _textTheme is const because it only references const AppColors members
  // (textPrimary / textSecondary / textMuted — which never change between themes).
  static const _textTheme = TextTheme(
    displayLarge:  TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w800, letterSpacing: -1.0),
    displayMedium: TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineLarge: TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w700, letterSpacing: -0.3),
    headlineMedium:TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600),
    titleLarge:    TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w700, fontSize: 20),
    titleMedium:   TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600, fontSize: 16),
    titleSmall:    TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
    bodyLarge:     TextStyle(color: AppColors.textPrimary,   fontSize: 16),
    bodyMedium:    TextStyle(color: AppColors.textSecondary, fontSize: 14),
    bodySmall:     TextStyle(color: AppColors.textMuted,     fontSize: 12),
    labelLarge:    TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600, fontSize: 14),
    labelMedium:   TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
    labelSmall:    TextStyle(color: AppColors.textMuted,     fontWeight: FontWeight.w500, fontSize: 11),
  );
}
