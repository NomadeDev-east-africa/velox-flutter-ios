import 'package:shared_preferences/shared_preferences.dart';
import 'fr.dart';
import 'en.dart';
import 'ar.dart';
import 'so.dart';
import 'aa.dart';

class AppTranslations {
  static Map<String, String> _currentTranslations = fr;
  static String _currentLanguage = 'fr';

  // Langues disponibles
  static const List<Map<String, String>> availableLanguages = [
    {'code': 'so', 'name': 'Somali', 'nativeName': 'Af-Soomaali'},
    {'code': 'aa', 'name': 'Afar', 'nativeName': 'Qafar af'},
    {'code': 'fr', 'name': 'Français', 'nativeName': 'Français'},
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
  ];

  // Obtenir toutes les traductions par code de langue
  static Map<String, Map<String, String>> get allTranslations => {
        'fr': fr,
        'en': en,
        'ar': ar,
        'so': so,
        'aa': aa,
      };

  // Obtenir la langue actuelle
  static String get currentLanguage => _currentLanguage;

  // Obtenir les traductions actuelles
  static Map<String, String> get translations => _currentTranslations;

  // Initialiser la langue au démarrage de l'app
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language') ?? 'fr';
    await setLanguage(savedLanguage);
  }

  // Changer de langue
  static Future<void> setLanguage(String languageCode) async {
    if (allTranslations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
      _currentTranslations = allTranslations[languageCode]!;

      // Sauvegarder dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', languageCode);
    }
  }

  // Traduire une clé
  static String translate(String key) {
    return _currentTranslations[key] ?? key;
  }
}

// Fonction raccourcie pour traduire
String tr(String key) {
  return AppTranslations.translate(key);
}
