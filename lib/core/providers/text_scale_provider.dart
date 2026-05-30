import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppTextScale — app-wide accessibility text size.
//
// Applied as a fixed TextScaler in app.dart so the choice is predictable
// across all screens (overrides the system scale, which is often locked
// to 1.0 on TV devices). Stored globally — shared by every profile.
// ─────────────────────────────────────────────────────────────────────────────

enum AppTextScale {
  small(0.85, 'Small', 'صغير'),
  normal(1.0, 'Normal', 'عادي'),
  large(1.15, 'Large', 'كبير'),
  xlarge(1.3, 'Extra Large', 'كبير جداً');

  const AppTextScale(this.factor, this.label, this.labelAr);

  final double factor;
  final String label;
  final String labelAr;
}

class TextScaleNotifier extends Notifier<AppTextScale> {
  static const _key = 'text_scale';

  @override
  AppTextScale build() {
    final saved = StorageService.getGlobalSetting<String>(_key);
    return AppTextScale.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => AppTextScale.normal,
    );
  }

  Future<void> setScale(AppTextScale scale) async {
    state = scale;
    await StorageService.setGlobalSetting(_key, scale.name);
  }
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, AppTextScale>(TextScaleNotifier.new);
