import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/storage_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends Notifier<WiseTheme> {
  @override
  WiseTheme build() {
    // Restore persisted choice; fall back to Midnight.
    final saved = StorageService.getSetting<String>(AppConstants.keyTheme);
    if (saved != null) {
      for (final t in WiseTheme.values) {
        if (t.name == saved) return t;
      }
    }
    return WiseTheme.midnight;
  }

  Future<void> setTheme(WiseTheme theme) async {
    await StorageService.setSetting(AppConstants.keyTheme, theme.name);
    state = theme;
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, WiseTheme>(ThemeNotifier.new);
