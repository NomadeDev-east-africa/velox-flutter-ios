import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/local_cache.dart';
import '../translations/app_translations.dart';

// ═══════════════════════════════════════════════════════════════
// ÉTAT
// ═══════════════════════════════════════════════════════════════

class LanguageState {
  final String language;

  const LanguageState({this.language = 'FR'});

  LanguageState copyWith({String? language}) =>
      LanguageState(language: language ?? this.language);

  String get languageName {
    switch (language) {
      case 'FR': return 'Français';
      case 'EN': return 'English';
      case 'SO': return 'Somali';
      case 'AR': return 'العربية';
      case 'AF': return 'Afar';
      default:   return 'Français';
    }
  }

  String get languageFlag {
    switch (language) {
      case 'FR': return '🇫🇷';
      case 'EN': return '🇬🇧';
      case 'SO': return '🇸🇴';
      case 'AR': return '🇸🇦';
      case 'AF': return '🇩🇯';
      default:   return '🇫🇷';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTIFIER
// ═══════════════════════════════════════════════════════════════

class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(const LanguageState()) {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    // Lire depuis LocalCache (synchrone après init)
    final lang = LocalCache.getLanguage().toUpperCase();
    if (mounted) {
      state = state.copyWith(language: lang);
    }
  }

  /// Changer la langue de l'app
  Future<void> setLanguage(String lang) async {
    if (!mounted) return;

    state = state.copyWith(language: lang.toUpperCase());

    // Persister
    await LocalCache.saveLanguage(lang.toLowerCase());

    // Mettre à jour AppTranslations (système de traduction existant)
    await AppTranslations.setLanguage(lang.toLowerCase());

    debugPrint('🌐 [LanguageNotifier] Langue: ${state.languageName}');
  }

  // Helpers pour les screens existants
  String getLanguageName(String code) =>
      LanguageState(language: code).languageName;

  String getLanguageFlag(String code) =>
      LanguageState(language: code).languageFlag;
}

// ═══════════════════════════════════════════════════════════════
// PROVIDER GLOBAL
// Utilisation dans les screens :
//   ref.watch(languageNotifierProvider)               → LanguageState
//   ref.watch(languageNotifierProvider).language      → 'FR' | 'EN' ...
//   ref.read(languageNotifierProvider.notifier).setLanguage('EN')
// ═══════════════════════════════════════════════════════════════

final languageNotifierProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) => LanguageNotifier(),
);
