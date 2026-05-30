import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/profile_provider.dart';
import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/profile.dart';
import 'profiles_screen.dart' show showEditProfileDialog;

// ─────────────────────────────────────────────────────────────────────────────
// "Who's watching?" — shown after the splash so the user picks a profile
// before entering the app. Each profile has its own favourites / history.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileSelectScreen extends ConsumerStatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  ConsumerState<ProfileSelectScreen> createState() =>
      _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends ConsumerState<ProfileSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final profiles = StorageService.profiles;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Who's watching?",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 28,
                  runSpacing: 28,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < profiles.length; i++)
                      _ProfileTile(
                        profile: profiles[i],
                        autofocus: i == 0,
                        onTap: () async {
                          await ref
                              .read(profileProvider.notifier)
                              .switchProfile(profiles[i].id);
                          ref.read(categoryPrefsProvider.notifier).reload();
                          if (context.mounted) context.go('/home');
                        },
                        onEdit: () async {
                          await showEditProfileDialog(
                              context, ref, profiles[i]);
                          if (mounted) setState(() {}); // reflect changes
                        },
                      ),
                    _AddTile(onTap: () => context.go('/settings/profiles')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.autofocus,
    required this.onTap,
    required this.onEdit,
  });

  final Profile profile;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.colorValue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableCard(
          autofocus: autofocus,
          onPressed: onTap,
          borderRadius: 18,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Text(profile.emoji,
                        style: const TextStyle(fontSize: 54)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 124,
                  child: Text(
                    profile.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _EditButton(onPressed: onEdit),
      ],
    );
  }
}

// Small focusable "Edit" affordance under each profile (D-pad: Down from the
// profile tile → Edit → OK opens the name/emoji/colour dialog).
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onPressed,
      borderRadius: 10,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined,
                size: 15, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text('Edit',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onTap,
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant,
                border: Border.all(color: AppColors.divider, width: 2),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.textSecondary, size: 44),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 124,
              child: Text(
                'Add Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
