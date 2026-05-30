import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_service.dart';

/// Supported app locales.
enum AppLocale {
  en(label: 'English', labelNative: 'English', locale: Locale('en')),
  ar(label: 'Arabic',  labelNative: 'العربية',  locale: Locale('ar'));

  const AppLocale({
    required this.label,
    required this.labelNative,
    required this.locale,
  });

  final String label;
  final String labelNative;
  final Locale locale;
}

class LocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'app_locale';

  @override
  AppLocale build() {
    final saved = StorageService.getSetting<String>(_key);
    if (saved == null) return AppLocale.en;
    return AppLocale.values.firstWhere(
      (l) => l.name == saved,
      orElse: () => AppLocale.en,
    );
  }

  Future<void> setLocale(AppLocale locale) async {
    await StorageService.setSetting(_key, locale.name);
    state = locale;
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, AppLocale>(LocaleNotifier.new);
