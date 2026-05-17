import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/local_cache.dart';

// ═══════════════════════════════════════════════════════════════
// ÉTAT
// ═══════════════════════════════════════════════════════════════

class ThemeState {
  final bool isDarkMode;

  const ThemeState({this.isDarkMode = true});

  ThemeState copyWith({bool? isDarkMode}) =>
      ThemeState(isDarkMode: isDarkMode ?? this.isDarkMode);

  // Couleurs officielles du drapeau djiboutien
  static const Color djiboutiBlue  = Color(0xFF6AB2E1);
  static const Color djiboutiGreen = Color(0xFF12AD2B);
  static const Color djiboutiRed   = Color(0xFFD7141A);

  // ThemeData dynamique (sans police personnalisée pour l'instant)
  ThemeData get themeData {
    if (isDarkMode) {
      return ThemeData.dark().copyWith(
        primaryColor: djiboutiBlue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: djiboutiBlue,
          secondary: djiboutiGreen,
          error: djiboutiRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: djiboutiGreen,
        ),
      );
    }
    return ThemeData.light().copyWith(
      primaryColor: djiboutiBlue,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: const ColorScheme.light(
        primary: djiboutiBlue,
        secondary: djiboutiGreen,
        error: djiboutiRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: djiboutiBlue,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: djiboutiGreen,
      ),
    );
  }

  // Couleurs dynamiques (texte lisible en clair/sombre)
  Color get cardColor =>
      isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textPrimary =>
      isDarkMode ? Colors.white : const Color(0xFF121212);
  Color get textSecondary =>
      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get scaffoldBackground =>
      isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
}

// ═══════════════════════════════════════════════════════════════
// NOTIFIER
// ═══════════════════════════════════════════════════════════════

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final isDark = LocalCache.getDarkMode();
    if (mounted) {
      state = state.copyWith(isDarkMode: isDark);
    }
  }

  Future<void> toggleTheme() async {
    final newValue = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newValue);
    await LocalCache.saveDarkMode(newValue);
    debugPrint('🌓 [ThemeNotifier] Mode: ${newValue ? "dark" : "light"}');
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    await LocalCache.saveDarkMode(value);
  }
}

final themeNotifierProvider =
StateNotifierProvider<ThemeNotifier, ThemeState>(
      (ref) => ThemeNotifier(),
);