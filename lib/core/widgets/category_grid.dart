/// Shared building blocks for all three category screens
/// (Live TV, Movies, Series). Extracted to avoid code duplication.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/category_prefs_notifier.dart';
import '../storage/storage_service.dart';
import '../theme/app_theme.dart';
import '../../data/models/live_category.dart';
import '../../features/parental/pin_dialog.dart';
import 'focusable_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<LiveCategory> applyOrderAndFilter(
    List<LiveCategory> cats, CategoryPrefs prefs, String section) {
  final visible =
      cats.where((c) => !prefs.hidden.contains(c.categoryId)).toList();
  final order = StorageService.getCategoryOrder(section);
  if (order.isEmpty) return visible;
  final map = {for (final c in visible) c.categoryId: c};
  final sorted = <LiveCategory>[];
  for (final id in order) {
    if (map.containsKey(id)) sorted.add(map.remove(id)!);
  }
  sorted.addAll(map.values);
  return sorted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid
// ─────────────────────────────────────────────────────────────────────────────

class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.prefs,
    required this.section,
    required this.onNavigate,
  });

  final List<LiveCategory> categories;
  final CategoryPrefs prefs;
  final String section;
  final ValueChanged<LiveCategory> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _iconForSection(section);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final cat = categories[i];
        final locked = prefs.locked.contains(cat.categoryId);
        return CategoryCard(
          category: cat,
          locked: locked,
          icon: icon,
          autofocus: i == 0,
          onTap: () => _handleTap(context, ref, cat, locked),
          onLongPress: () => _showOptions(context, ref, cat, locked),
        );
      },
    );
  }

  static IconData _iconForSection(String section) {
    switch (section) {
      case 'live':
        return Icons.live_tv_rounded;
      case 'movies':
        return Icons.movie_rounded;
      case 'series':
        return Icons.video_library_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref,
      LiveCategory cat, bool locked) async {
    if (locked) {
      final ok = await showPinDialog(context);
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) onNavigate(cat);
  }

  void _showOptions(BuildContext context, WidgetRef ref,
      LiveCategory cat, bool locked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => CategoryOptionsSheet(
        category: cat,
        locked: locked,
        hidden: prefs.hidden.contains(cat.categoryId),
        onToggleLock: () async {
          Navigator.pop(context);
          await _toggleLock(context, ref, cat.categoryId, locked);
        },
        onToggleHide: () {
          Navigator.pop(context);
          ref
              .read(categoryPrefsProvider.notifier)
              .toggleHidden(cat.categoryId);
        },
      ),
    );
  }

  Future<void> _toggleLock(BuildContext context, WidgetRef ref,
      String id, bool currentlyLocked) async {
    if (currentlyLocked) {
      if (StorageService.hasParentalPin) {
        final ok = await showPinDialog(context, title: 'Enter PIN to unlock');
        if (!ok) return;
      }
    } else {
      if (!StorageService.hasParentalPin) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Set a parental PIN in Settings → Parental Controls')));
        }
        return;
      }
    }
    if (context.mounted) {
      ref.read(categoryPrefsProvider.notifier).toggleLocked(id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.locked,
    required this.icon,
    required this.autofocus,
    required this.onTap,
    required this.onLongPress,
  });

  final LiveCategory category;
  final bool locked;
  final IconData icon;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      autofocus: autofocus,
      onPressed: onTap,
      onLongPress: onLongPress,
      borderRadius: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.card,
                AppColors.surface.withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(color: AppColors.divider, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left gradient accent stripe (full height)
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Section icon badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.25),
                                AppColors.accent.withValues(alpha: 0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Icon(icon,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            category.categoryName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_rounded,
                              size: 16,
                              color: AppColors.textMuted),
                        ],
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            size: 22,
                            color: AppColors.accent.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class CategoryOptionsSheet extends StatelessWidget {
  const CategoryOptionsSheet({
    super.key,
    required this.category,
    required this.locked,
    required this.hidden,
    required this.onToggleLock,
    required this.onToggleHide,
  });

  final LiveCategory category;
  final bool locked;
  final bool hidden;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(category.categoryName,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: Icon(
              locked ? Icons.lock_open_outlined : Icons.lock_outline,
              color: AppColors.primary,
            ),
            title: Text(locked ? 'Unlock category' : 'Lock with PIN'),
            onTap: onToggleLock,
          ),
          ListTile(
            leading: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: hidden ? AppColors.accent : AppColors.liveRed,
            ),
            title: Text(hidden ? 'Show category' : 'Hide category'),
            onTap: onToggleHide,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
