import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_provider.dart';

const String kThemeModePrefsKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(kThemeModePrefsKey);
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await ref.read(sharedPreferencesProvider).setString(
          kThemeModePrefsKey,
          next == ThemeMode.dark ? 'dark' : 'light',
        );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
