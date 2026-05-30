import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/perf/perf_profile.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/text_scale_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/wallpaper_provider.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/content_cache_service.dart';
import '../../core/widgets/focusable_card.dart';
import '../../features/profiles/profiles_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _livePlayer = AppConstants.playerAuto;
  String _vodPlayer  = AppConstants.playerAuto;

  @override
  void initState() {
    super.initState();
    _livePlayer = StorageService.getSetting<String>(AppConstants.keyLivePlayer) ??
        AppConstants.playerAuto;
    _vodPlayer = StorageService.getSetting<String>(AppConstants.keyVodPlayer) ??
        AppConstants.playerAuto;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader(s.appearance),
          const _ThemePicker(),

          // ── Wallpaper ────────────────────────────────────────────────────
          _WallpaperPicker(label: s.wallpaper),
          const Divider(),

          // ── Language ─────────────────────────────────────────────────────
          _LanguagePicker(label: s.sLanguage),
          const Divider(),

          // ── Text size (accessibility) ────────────────────────────────────
          _TextSizePicker(label: s.textSize),
          const Divider(),


          // ── Playlists ────────────────────────────────────────────────────
          _SectionHeader(s.sPlaylists),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(s.managePlaylists),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/playlists'),
          ),
          const Divider(),

          // ── Player ───────────────────────────────────────────────────────
          _SectionHeader(s.player),
          _PlayerPicker(
            title: s.liveTVPlayer,
            value: _livePlayer,
            s: s,
            onChanged: (v) async {
              await StorageService.setSetting(AppConstants.keyLivePlayer, v);
              setState(() => _livePlayer = v);
            },
          ),
          _PlayerPicker(
            title: s.moviesSeriesPlayer,
            value: _vodPlayer,
            s: s,
            onChanged: (v) async {
              await StorageService.setSetting(AppConstants.keyVodPlayer, v);
              setState(() => _vodPlayer = v);
            },
          ),
          const Divider(),

          // ── Performance ──────────────────────────────────────────────────
          const _PerformanceSection(),

          // ── Parental Controls ────────────────────────────────────────────
          _SectionHeader(s.parentalControls),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(s.pinLockedCategories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/parental'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(s.manageCategories),
            subtitle: Text(s.manageCategoriesSubtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/categories'),
          ),
          const Divider(),

          // ── Cache ────────────────────────────────────────────────────────
          _SectionHeader(s.cache),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.watchHistory),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/history'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(s.clearHistory),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await StorageService.clearHistory();
              messenger.showSnackBar(
                  SnackBar(content: Text(s.historyCleared)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.cached_rounded),
            title: Text(s.clearContentCache),
            subtitle: Text(s.clearContentCacheSubtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ContentCacheService.clearAll();
              messenger.showSnackBar(
                  SnackBar(content: Text(s.contentCacheCleared)));
            },
          ),
          const Divider(),

          // ── Profiles ─────────────────────────────────────────────────────
          _SectionHeader(s.profiles),
          Consumer(builder: (ctx, ref, _) {
            final active = ref.watch(profileProvider);
            final all    = ref.read(profileProvider.notifier).all;
            return ListTile(
              leading: ProfileAvatar(profile: active, size: 32),
              title: Text(s.manageProfiles),
              subtitle: Text(
                active?.name ?? '',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${all.length}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => context.go('/settings/profiles'),
            );
          }),
          const Divider(),

          // ── Account ──────────────────────────────────────────────────────
          _SectionHeader(s.account),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(s.accountInfo),
            subtitle: Text(s.accountStatus,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/account'),
          ),
          const Divider(),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader(s.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('WiseVodPlayer'),
            subtitle: Text(s.version),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(s.diagnostics),
            subtitle: Text(s.diagnosticsSubtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/diagnostics'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallpaper picker
// ─────────────────────────────────────────────────────────────────────────────

class _WallpaperPicker extends ConsumerWidget {
  const _WallpaperPicker({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wallpaperProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.wallpaper_rounded, size: 20,
                  color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: WallpaperMode.values.map((mode) {
              final selected = mode == current;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FocusableCard(
                  onPressed: () =>
                      ref.read(wallpaperProvider.notifier).setWallpaper(mode),
                  borderRadius: 12,
                  focusScale: 1.05,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: selected ? 2.0 : 1.0,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                              )
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base: real image, gradient, or solid dark for 'none'
                          if (mode.assetImage != null)
                            // Decode at thumbnail size — the source PNGs are
                            // multi-MB; full-res decode here janks low-end TVs.
                            Image.asset(mode.assetImage!,
                                fit: BoxFit.cover, cacheWidth: 160)
                          else if (mode.gradient != null)
                            DecoratedBox(
                                decoration:
                                    BoxDecoration(gradient: mode.gradient))
                          else
                            const ColoredBox(color: Color(0xFF1A1A1F)),
                          // Label overlay
                          Positioned(
                            left: 0, right: 0, bottom: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xDD000000),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(4, 14, 4, 5),
                              child: Text(
                                mode.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // Check badge
                          if (selected)
                            Positioned(
                              top: 5, right: 5,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language picker
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final s       = ref.watch(stringsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.language_rounded, size: 20,
              color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          // Toggle chips: EN | AR
          _LangChip(
            label: s.langEnglish,
            selected: current == AppLocale.en,
            onTap: () =>
                ref.read(localeProvider.notifier).setLocale(AppLocale.en),
          ),
          const SizedBox(width: 8),
          _LangChip(
            label: s.langArabic,
            selected: current == AppLocale.ar,
            onTap: () =>
                ref.read(localeProvider.notifier).setLocale(AppLocale.ar),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onTap,
      borderRadius: 20,
      focusScale: 1.05,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text size picker (accessibility)
// ─────────────────────────────────────────────────────────────────────────────

class _TextSizePicker extends ConsumerWidget {
  const _TextSizePicker({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(textScaleProvider);
    final isAr = ref.watch(localeProvider) == AppLocale.ar;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_size_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scale in AppTextScale.values)
                Semantics(
                  button: true,
                  selected: scale == current,
                  label: isAr ? scale.labelAr : scale.label,
                  child: _LangChip(
                    label: isAr ? scale.labelAr : scale.label,
                    selected: scale == current,
                    onTap: () =>
                        ref.read(textScaleProvider.notifier).setScale(scale),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme picker
// ─────────────────────────────────────────────────────────────────────────────

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (final theme in WiseTheme.values) ...[
            Expanded(
              child: _ThemeCard(
                theme: theme,
                selected: theme == current,
                onTap: () => ref.read(themeProvider.notifier).setTheme(theme),
              ),
            ),
            if (theme != WiseTheme.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final WiseTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onTap,
      borderRadius: 14,
      focusScale: 1.03,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: theme.previewBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.previewPrimary : AppColors.divider,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.previewPrimary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Color swatch preview ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                              theme.previewBg, Colors.white, 0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.previewPrimary
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.previewPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.previewAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Name + check ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.label,
                          style: TextStyle(
                            color: selected
                                ? theme.previewPrimary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          theme.description,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded,
                        color: theme.previewPrimary, size: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _PlayerPicker extends StatelessWidget {
  const _PlayerPicker({
    required this.title,
    required this.value,
    required this.s,
    required this.onChanged,
  });

  final String title;
  final String value;
  final AppStrings s;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.videocam_outlined),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.card,
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(
              value: AppConstants.playerAuto, child: Text(s.playerAuto)),
          DropdownMenuItem(
              value: AppConstants.playerHw, child: Text(s.playerHardware)),
          DropdownMenuItem(
              value: AppConstants.playerSw, child: Text(s.playerSoftware)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance tier
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceSection extends StatefulWidget {
  const _PerformanceSection();

  @override
  State<_PerformanceSection> createState() => _PerformanceSectionState();
}

class _PerformanceSectionState extends State<_PerformanceSection> {
  late PerfMode _mode;
  late bool _animations;
  late bool _wallpaper;
  late bool _cache;

  @override
  void initState() {
    super.initState();
    _mode = Perf.mode;
    _animations = !Perf.reduceMotion;
    _wallpaper = Perf.wallpaperAllowed;
    _cache = Perf.largeImageCache;
  }

  Future<void> _setMode(PerfMode m) async {
    await Perf.setMode(m);
    // setMode resets the per-feature overrides to the new tier's defaults.
    setState(() {
      _mode = m;
      _animations = !Perf.reduceMotion;
      _wallpaper = Perf.wallpaperAllowed;
      _cache = Perf.largeImageCache;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tierLabel = Perf.tier == PerfTier.high ? 'High' : 'Low';
    final autoLabel = Perf.autoDetectedLowEnd ? 'low-end' : 'high-end';
    final renderer = Perf.tier == PerfTier.high ? 'Impeller' : 'Skia';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Performance'),
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: const Text('Performance mode'),
          subtitle: Text(
            _mode == PerfMode.auto
                ? 'Auto · detected $autoLabel device'
                : 'Active tier: $tierLabel',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: DropdownButton<PerfMode>(
            value: _mode,
            dropdownColor: AppColors.card,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: PerfMode.auto, child: Text('Auto')),
              DropdownMenuItem(value: PerfMode.low, child: Text('Low')),
              DropdownMenuItem(value: PerfMode.high, child: Text('High')),
            ],
            onChanged: (v) {
              if (v != null) _setMode(v);
            },
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.hd_outlined),
          title: const Text('High-resolution image cache'),
          subtitle: const Text(
            '250 MB poster cache — smoother scrolling, more memory',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          value: _cache,
          activeColor: AppColors.primary,
          onChanged: (v) async {
            await Perf.setLargeImageCache(v);
            Perf.applyImageCache(); // cache budget can change live
            setState(() => _cache = v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.animation_rounded),
          title: const Text('UI animations'),
          subtitle: const Text(
            'Focus zoom, glow & home banner auto-rotate',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          value: _animations,
          activeColor: AppColors.primary,
          onChanged: (v) async {
            await Perf.setAnimations(v);
            setState(() => _animations = v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wallpaper_rounded),
          title: const Text('Background wallpaper'),
          subtitle: const Text(
            'Show the wallpaper image behind menus',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          value: _wallpaper,
          activeColor: AppColors.primary,
          onChanged: (v) async {
            await Perf.setWallpaperAllowed(v);
            setState(() => _wallpaper = v);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Renderer: $renderer. Restart the app to fully apply '
                  'performance changes.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}
