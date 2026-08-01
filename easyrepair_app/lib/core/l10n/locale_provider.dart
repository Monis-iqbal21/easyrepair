import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';

/// SharedPreferences key holding the user's language choice.
///
/// Logout deliberately does not clear SharedPreferences, so the choice
/// survives sign-out, app close and device restart.
const String kLocalePrefsKey = 'app_locale';

/// Overridden in `main()` with an already-resolved instance so the locale is
/// known synchronously on the very first frame — otherwise the app would flash
/// English before switching to the saved language.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // An existing user who has never chosen a language gets English.
    return AppLocale.fromStorage(prefs.getString(kLocalePrefsKey));
  }

  /// Applies [next] immediately, then persists it.
  ///
  /// State is set first so the UI switches on the current frame rather than
  /// waiting on disk; a failed write only means the choice is not remembered
  /// next launch, which is far better than a selector that appears to do
  /// nothing.
  Future<void> setLocale(AppLocale next) async {
    if (state == next) return;
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kLocalePrefsKey, next.storageValue);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);
