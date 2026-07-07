import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../utils/local_cache.dart';

// ═══════════════════════════════════════════════════════════════
// ÉTAT
// ═══════════════════════════════════════════════════════════════

class ThemeState {
  final bool isDarkMode;

  const ThemeState({this.isDarkMode = true});

  ThemeState copyWith({bool? isDarkMode}) =>
      ThemeState(isDarkMode: isDarkMode ?? this.isDarkMode);

  // Couleurs officielles du drapeau djiboutien — branding ponctuel uniquement
  // (ex: écran onboarding). Ne définissent PLUS le thème global : voir AppColors.
  static const Color djiboutiBlue  = Color(0xFF6AB2E1);
  static const Color djiboutiGreen = Color(0xFF12AD2B);
  static const Color djiboutiRed   = Color(0xFFD7141A);

  /// Palette canonique courante (source de vérité unique : lib/theme/app_colors.dart)
  AppColors get colors => isDarkMode ? AppColors.dark : AppColors.light;

  // ThemeData dérivé entièrement de AppColors — aucune couleur en dur ici.
  ThemeData get themeData {
    final c = colors;
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      cardColor: c.surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        // Pas de rôle "secondary" défini dans AppColors : on retombe sur
        // primary. Signalé pour synchro Android si un rôle dédié est ajouté.
        secondary: c.primary,
        onSecondary: c.onPrimary,
        error: c.error,
        // Pas de rôle "onError" défini dans AppColors : blanc par défaut
        // (contraste correct sur les deux rouges error dark/light). Signalé.
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.onSurface,
        onSurfaceVariant: c.onSurfaceVariant,
        outlineVariant: c.outlineVariant,
        surfaceContainerLowest: c.surfaceLow,
        surfaceContainerLow: c.surfaceLow,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceHigh,
        surfaceContainerHighest: c.surfaceTop,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfaceHigh,
        foregroundColor: c.onSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
      ),
    );
  }

  // Couleurs dynamiques (texte lisible en clair/sombre) — dérivées de AppColors.
  Color get cardColor => colors.surface;
  Color get textPrimary => colors.onSurface;
  Color get textSecondary => colors.onSurfaceVariant;
  Color get scaffoldBackground => colors.bg;
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