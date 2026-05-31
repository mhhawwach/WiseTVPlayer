/// "Customize your experience" — the language-interest popup.
///
/// • Fires once per (profile, playlist) on first launch (see [LanguagePrefsGate],
///   mounted on the Home screen), and is re-openable from Settings.
/// • Auto-detects the languages present in the playlist and lets the user pick
///   which to keep. Arabic + English are checked by default.
/// • Saving updates [languagePrefsProvider]; every grid / list / home row /
///   search that watches it re-filters instantly (no provider invalidation
///   needed — the blocked set is recomputed client-side from the selection).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/category_language.dart';
import '../../core/language/language_prefs.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/live_category.dart';
import '../live_tv/live_categories_screen.dart' show liveCategoriesProvider;
import '../movies/movies_categories_screen.dart' show vodCategoriesProvider;
import '../series/series_categories_screen.dart' show seriesCategoriesProvider;

/// Shows the language popup. [present] is the list of language keys detected in
/// the playlist (the options). [current] pre-selects rows (used for the Settings
/// re-entry); when null, the Arabic+English default applies.
Future<void> showLanguagePrefsDialog(
  BuildContext context, {
  required List<String> present,
  Set<String>? current,
}) {
  final initial = current ?? CategoryLanguage.defaultSelectionFor(present);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _LanguagePrefsDialog(present: present, initial: initial),
  );
}

/// Re-opens the popup from Settings for the active playlist: discovers the
/// languages present, pre-selects the saved choice, and shows the dialog.
/// Returns `false` when there's no active playlist or the playlist has no
/// language-tagged categories (caller can surface a hint).
Future<bool> openLanguagePrefsForActivePlaylist(
    BuildContext context, WidgetRef ref) async {
  final pid = StorageService.activePlaylistId;
  if (pid == null) return false;
  final present = await _discoverPresent(ref);
  if (present.isEmpty) return false;
  final current = ref.read(languagePrefsProvider) ??
      CategoryLanguage.defaultSelectionFor(present);
  if (!context.mounted) return false;
  await showLanguagePrefsDialog(context, present: present, current: current);
  return true;
}

/// Loads the three category lists (cached / stale-while-revalidate) and returns
/// the union of languages present across all sections.
Future<List<String>> _discoverPresent(WidgetRef ref) async {
  final results = await Future.wait([
    ref.read(liveCategoriesProvider.future),
    ref.read(vodCategoriesProvider.future),
    ref.read(seriesCategoriesProvider.future),
  ]);
  final all = <LiveCategory>[for (final list in results) ...list];
  return CategoryLanguage.languagesPresent(all);
}

class _LanguagePrefsDialog extends ConsumerStatefulWidget {
  const _LanguagePrefsDialog({required this.present, required this.initial});

  final List<String> present;
  final Set<String> initial;

  @override
  ConsumerState<_LanguagePrefsDialog> createState() =>
      _LanguagePrefsDialogState();
}

class _LanguagePrefsDialogState extends ConsumerState<_LanguagePrefsDialog> {
  late final Set<String> _selected = {...widget.initial};
  bool _saving = false;

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(languagePrefsProvider.notifier).setSelected({..._selected});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = media.size.width < 480 ? media.size.width - 32 : 460.0;
    final maxH = media.size.height * 0.82;

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Let's customize your experience",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select the languages you’re interested in. We’ll tailor '
                    'Live TV, Movies and Series to your choice — anything '
                    'without a language stays available.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ── Language list ───────────────────────────────────────────────
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                shrinkWrap: true,
                itemCount: widget.present.length,
                itemBuilder: (_, i) {
                  final key = widget.present[i];
                  return _LangRow(
                    code: CategoryLanguage.codeFor(key),
                    label: CategoryLanguage.labelFor(key),
                    selected: _selected.contains(key),
                    autofocus: i == 0,
                    onTap: () => _toggle(key),
                  );
                },
              ),
            ),
            // ── Footer ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: _FooterButton(
                      label: 'Select all',
                      filled: false,
                      onTap: () =>
                          setState(() => _selected.addAll(widget.present)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _FooterButton(
                      label: _saving ? 'Saving…' : 'Save preferences',
                      filled: true,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── A single language row (focusable checkbox) ───────────────────────────────

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FocusableCard(
        autofocus: autofocus,
        onPressed: onTap,
        borderRadius: 14,
        focusScale: 1.02,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Language code chip.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1),
                ),
                child: Text(
                  code,
                  // AppColors.accent is a theme-dependent (non-const) getter.
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ).copyWith(color: AppColors.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Checkbox indicator.
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onTap,
      borderRadius: 12,
      focusScale: 1.03,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// First-launch gate — mounted (invisibly) on the Home screen. The first time a
// profile lands on Home with an active playlist whose language popup hasn't run
// yet, it discovers the playlist's languages and shows the popup.
// ─────────────────────────────────────────────────────────────────────────────

class LanguagePrefsGate extends ConsumerStatefulWidget {
  const LanguagePrefsGate({super.key});

  @override
  ConsumerState<LanguagePrefsGate> createState() => _LanguagePrefsGateState();
}

class _LanguagePrefsGateState extends ConsumerState<LanguagePrefsGate> {
  String? _handledPid; // playlist already evaluated by this gate instance
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final pid = StorageService.activePlaylistId;
    if (pid != null && pid != _handledPid && !_busy) {
      _handledPid = pid;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow(pid));
    }
    return const SizedBox.shrink();
  }

  Future<void> _maybeShow(String pid) async {
    if (!mounted || _busy) return;
    if (StorageService.languagePrefsSeen(pid)) return;
    _busy = true;
    try {
      final present = await _discoverPresent(ref);
      if (!mounted) return;
      if (present.isEmpty) {
        // Nothing language-tagged → no customization to offer. Mark seen so we
        // don't re-check every launch.
        await StorageService.markLanguagePrefsSeen(pid);
        return;
      }
      await showLanguagePrefsDialog(context, present: present);
    } catch (_) {
      // Categories failed to load (offline / server slow). Leave 'seen' false
      // so the popup gets another chance next launch.
    } finally {
      _busy = false;
    }
  }
}
