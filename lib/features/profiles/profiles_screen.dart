import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/language/language_prefs.dart';
import '../../core/providers/content_refresh.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profiles Screen
// ─────────────────────────────────────────────────────────────────────────────

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    final s        = ref.watch(stringsProvider);
    final notifier = ref.read(profileProvider.notifier);
    final profiles = notifier.all;
    final activeId = StorageService.activeProfileId;

    return Scaffold(
      appBar: AppBar(title: Text(s.profiles)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile cards ────────────────────────────────────────────────
          ...profiles.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            return _ProfileCard(
              profile:  p,
              isActive: p.id == activeId,
              // Only ONE card autofocuses (the first). Autofocusing every
              // non-active card put multiple autofocus:true in one scope, so
              // the initial highlight landed unpredictably / looked missing.
              autofocus: i == 0,
              // OK opens an actions sheet (Switch / Edit / Delete). Previously
              // these were tiny trailing icon buttons that a D-pad couldn't
              // reach inside the tile's full-width InkWell — so Delete was
              // effectively unreachable on the TV.
              onOpen: () => _showActions(context, ref, s, p,
                  isActive: p.id == activeId, canDelete: profiles.length > 1),
            );
          }),

          const SizedBox(height: 12),

          // ── Add profile ──────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _showCreateDialog(context, ref, s),
            icon: const Icon(Icons.add_rounded),
            label: Text(s.addProfile),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            s.profilesHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _showCreateDialog(
      BuildContext ctx, WidgetRef ref, AppStrings s) async {
    await showDialog<void>(
      context: ctx,
      builder: (_) => _ProfileDialog(
        title: s.addProfile,
        onSave: (name, color, emoji, kidsMode) async {
          await ref.read(profileProvider.notifier).createProfile(
                name: name,
                color: color,
                emoji: emoji,
                isKidsMode: kidsMode,
                switchTo: true,
              );
          ref.read(categoryPrefsProvider.notifier).reload();
          ref.read(languagePrefsProvider.notifier).reload();
          // New profile is now active (with an inherited playlist) — load its
          // content fresh so Home reflects it and the language popup can run.
          invalidateAllContent(ref);
          // Dialog closes itself (see _ProfileDialogState._save).
          if (mounted) setState(() {}); // show the new profile immediately
        },
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext ctx, WidgetRef ref, AppStrings s, Profile p) async {
    await showDialog<void>(
      context: ctx,
      builder: (_) => _ProfileDialog(
        title: s.editProfile,
        initialName: p.name,
        initialColor: Color(p.colorValue),
        initialKidsMode: p.isKidsMode,
        initialEmoji: p.emoji,
        onSave: (name, color, emoji, kidsMode) async {
          final updated = Profile(
            id: p.id,
            name: name,
            colorValue: color.value,
            isKidsMode: kidsMode,
            emoji: emoji,
          );
          await ref.read(profileProvider.notifier).updateProfile(updated);
          // Dialog closes itself (see _ProfileDialogState._save).
          if (mounted) setState(() {}); // reflect name/colour change
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, WidgetRef ref, AppStrings s, Profile p) async {
    final wasActive = p.id == StorageService.activeProfileId;
    final ok = await showDialog<bool>(
      context: ctx,
      // Pop with the dialog's OWN context (dialogCtx). showDialog uses the root
      // navigator, but popping with the screen context targets a nested
      // navigator — so the dialog never closed and nothing deleted (only Esc,
      // the dialog's built-in dismiss, worked).
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(s.deleteProfile,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${s.deleteProfileConfirm} "${p.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(s.cancel)),
          TextButton(
            // The user already chose "Delete" in the actions sheet, so OK here
            // confirms (autofocused so the remote's OK works on a TV).
            autofocus: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(profileProvider.notifier).deleteProfile(p.id);
    if (mounted) setState(() {}); // remove the deleted card immediately
    ref.read(categoryPrefsProvider.notifier).reload();
    ref.read(languagePrefsProvider.notifier).reload();
    // Deleting the active profile switches to another → refresh its content.
    if (wasActive) invalidateAllContent(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Deleted "${p.name}"'),
          duration: const Duration(seconds: 2)));
    }
  }

  // ── Actions sheet (Switch / Edit / Delete) ───────────────────────────────────
  // A reliable, D-pad-reachable replacement for the old tiny trailing icons,
  // which were unreachable inside the tile's full-width InkWell on a TV.
  void _showActions(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
    Profile p, {
    required bool isActive,
    required bool canDelete,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  _Avatar(profile: p, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!isActive)
              ListTile(
                autofocus: true,
                leading: Icon(Icons.play_circle_outline_rounded,
                    color: AppColors.primary),
                title: const Text('Switch to this profile',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await ref.read(profileProvider.notifier).switchProfile(p.id);
                  ref.read(categoryPrefsProvider.notifier).reload();
                  ref.read(languagePrefsProvider.notifier).reload();
                  // Re-fetch everything for the new profile (its playlist,
                  // watch history, favourites, language prefs).
                  invalidateAllContent(ref);
                  if (context.mounted) context.go('/home');
                },
              ),
            ListTile(
              autofocus: isActive,
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Edit',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showEditDialog(context, ref, s, p);
              },
            ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.withValues(alpha: 0.85)),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDelete(context, ref, s, p);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.autofocus,
    required this.onOpen,
  });

  final Profile     profile;
  final bool        isActive;
  final bool        autofocus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        // OK on the whole card opens the actions sheet — one clean D-pad target
        // (the old per-icon buttons weren't reachable by remote inside the tile).
        onTap: onOpen,
        autofocus: autofocus,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _Avatar(profile: profile, size: 44),
        title: Row(
          children: [
            Flexible(
              child: Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? color : AppColors.textPrimary,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            if (profile.isKidsMode) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Text('KIDS',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ],
        ),
        subtitle: isActive
            ? Text('Active',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))
            : null,
        trailing:
            const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar widget — reused across the app
// ─────────────────────────────────────────────────────────────────────────────

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 36});
  final Profile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return _Avatar._placeholder(size: size);
    }
    return _Avatar(profile: profile!, size: size);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.size});
  final Profile profile;
  final double size;

  static Widget _placeholder({required double size}) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceVariant,
      child: Icon(Icons.person_rounded,
          color: AppColors.textMuted, size: size * 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.25)!,
            color,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          profile.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.title,
    required this.onSave,
    this.initialName   = '',
    this.initialColor,
    this.initialKidsMode = false,
    this.initialEmoji,
  });

  final String title;
  final String initialName;
  final Color?  initialColor;
  final bool    initialKidsMode;
  final String? initialEmoji;
  final Future<void> Function(
      String name, Color color, String emoji, bool kidsMode) onSave;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late bool  _kidsMode;
  late String _emoji;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _color    = widget.initialColor ?? profileColors.first;
    _kidsMode = widget.initialKidsMode;
    _emoji    = widget.initialEmoji ?? profileEmojis.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      // Scrollable so the colour picker & kids toggle are reachable in
      // landscape, and the keyboard can't cover the fields.
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar preview
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color.lerp(_color, Colors.white, 0.25)!,
                    _color,
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: _color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 34)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name field — NOT autofocused: on TV that pops the on-screen
            // keyboard immediately and traps the user. Initial focus goes to
            // the first colour swatch instead (see below).
            TextField(
              controller: _nameCtrl,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle:
                    const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                counterStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            const Text('Colour',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < profileColors.length; i++)
                  _PickerOption(
                    autofocus: i == 0, // initial dialog focus (not the name field)
                    onTap: () => setState(() => _color = profileColors[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: profileColors[i],
                        border: profileColors[i].value == _color.value
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: profileColors[i].value == _color.value
                            ? [
                                BoxShadow(
                                    color: profileColors[i]
                                        .withValues(alpha: 0.6),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Emoji picker
            const Text('Avatar',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in profileEmojis)
                  _PickerOption(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e == _emoji
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.surfaceVariant,
                        border: e == _emoji
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Kids mode toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Kids Mode',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: 2),
                      Text('Restricts to family-friendly content',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: _kidsMode,
                  onChanged: (v) => setState(() => _kidsMode = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed:
              (_saving || _nameCtrl.text.trim().isEmpty) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_nameCtrl.text.trim(), _color, _emoji, _kidsMode);
      // Close the dialog using its OWN context so the correct route is popped
      // even after createProfile(switchTo:true) triggers rebuilds.
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Public entry point so other screens (e.g. the profile-select / login screen)
/// can open the same edit dialog (name / emoji / colour / kids). The dialog
/// closes itself on save.
Future<void> showEditProfileDialog(
    BuildContext context, WidgetRef ref, Profile p) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ProfileDialog(
      title: 'Edit Profile',
      initialName: p.name,
      initialColor: Color(p.colorValue),
      initialKidsMode: p.isKidsMode,
      initialEmoji: p.emoji,
      onSave: (name, color, emoji, kidsMode) async {
        await ref.read(profileProvider.notifier).updateProfile(
              Profile(
                id: p.id,
                name: name,
                colorValue: color.value,
                isKidsMode: kidsMode,
                emoji: emoji,
              ),
            );
      },
    ),
  );
}

// A D-pad-focusable wrapper for the colour swatches / emoji tiles in the
// profile dialog. Adds a focus ring and activates on Select/Enter so the
// pickers are reachable by remote (they were tap-only before).
class _PickerOption extends StatefulWidget {
  const _PickerOption({
    required this.onTap,
    required this.child,
    this.autofocus = false,
  });
  final VoidCallback onTap;
  final Widget child;
  final bool autofocus;

  @override
  State<_PickerOption> createState() => _PickerOptionState();
}

class _PickerOptionState extends State<_PickerOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _focused ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
