import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../storage/storage_service.dart';

// ── Predefined avatar colours ─────────────────────────────────────────────────

const profileColors = [
  Color(0xFF6C5CE7), // purple  (default)
  Color(0xFF00B894), // teal
  Color(0xFFE17055), // coral
  Color(0xFF74B9FF), // sky blue
  Color(0xFFFDCB6E), // amber
  Color(0xFFFF7675), // rose
  Color(0xFF55EFC4), // mint
  Color(0xFFA29BFE), // lavender
];

// Emoji avatars to choose from when creating a profile.
const profileEmojis = [
  '🍿', '😀', '😎', '🦁', '🐱', '🐼', '🦊', '🐸',
  '🎬', '⚽', '🎮', '🎸', '👑', '🌟', '🚀', '🦄',
  '🧒', '👦', '👧', '👨', '👩', '🧑', '👶', '🐯',
];

// ── Notifier ──────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<Profile?> {
  ProfileNotifier() : super(StorageService.activeProfile);

  List<Profile> get all => StorageService.profiles;

  /// Switch the active profile. Returns the new [Profile].
  /// After calling, the widget should also call categoryPrefsProvider.reload().
  Future<Profile> switchProfile(String id) async {
    final profile = await StorageService.switchProfile(id);
    state = profile;
    return profile;
  }

  /// Create a new profile and optionally switch to it.
  Future<Profile> createProfile({
    required String name,
    required Color color,
    String emoji = '🍿',
    bool isKidsMode = false,
    bool switchTo = true,
  }) async {
    // Playlists are global, but the *active* selection is per-profile. Capture
    // the current profile's active playlist BEFORE switching so the new profile
    // inherits one — otherwise it has no active playlist → no content on Home
    // AND the "customize your experience" language popup can't run (it's gated
    // on having an active playlist).
    final inheritPlaylistId = StorageService.activePlaylistId;
    final p = Profile(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      colorValue: color.value,
      isKidsMode: isKidsMode,
      emoji: emoji,
    );
    await StorageService.saveProfile(p);
    if (switchTo) {
      await switchProfile(p.id);
      if (StorageService.activePlaylistId == null) {
        final pick = inheritPlaylistId ??
            (StorageService.playlists.isNotEmpty
                ? StorageService.playlists.first.id
                : null);
        if (pick != null) await StorageService.setActivePlaylistId(pick);
      }
    }
    // Notify listeners so profile list rebuilds.
    state = StorageService.activeProfile;
    return p;
  }

  /// Update name / color / kidsMode of an existing profile.
  Future<void> updateProfile(Profile p) async {
    await StorageService.saveProfile(p);
    if (p.id == StorageService.activeProfileId) state = p;
  }

  /// Delete a profile (cannot delete the last one).
  /// After calling, widget should reload categoryPrefsProvider.
  Future<void> deleteProfile(String id) async {
    if (StorageService.profiles.length <= 1) return;
    await StorageService.deleteProfile(id);
    state = StorageService.activeProfile;
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, Profile?>((ref) {
  return ProfileNotifier();
});
