import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_translations.dart';

/// Global locale provider — manages language state across the app.
/// Use with Provider: context.watch<LocaleProvider>() for reactive UI updates
class LocaleProvider extends ChangeNotifier {
  String _locale = 'en';
  static const String _prefKey = 'app_locale';

  String get locale => _locale;
  bool get isGujarati => _locale == 'gu';
  bool get isEnglish => _locale == 'en';

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_prefKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale);
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    await setLocale(_locale == 'en' ? 'gu' : 'en');
  }

  /// Translate a key to the current locale
  String tr(String key) {
    final translations = AppTranslations.translations[_locale];
    return translations?[key] ?? AppTranslations.translations['en']?[key] ?? key;
  }
}
