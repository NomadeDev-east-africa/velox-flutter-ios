import 'package:flutter/material.dart';

/// Palette centralisée dark / light.
/// Utilisation dans un écran Riverpod :
///   final c = ref.watch(themeNotifierProvider).isDarkMode
///       ? AppColors.dark : AppColors.light;
class AppColors {
  final Color bg;
  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceTop;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color error;

  const AppColors._({
    required this.bg,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceTop,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.error,
  });

  static const dark = AppColors._(
    bg:               Color(0xFF0E0E0E),
    surfaceLow:       Color(0xFF131313),
    surface:          Color(0xFF1A1919),
    surfaceHigh:      Color(0xFF20201F),
    surfaceTop:       Color(0xFF262626),
    primary:          Color(0xFF9FFF88),
    onPrimary:        Color(0xFF026400),
    onSurface:        Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFADAAAB),
    outlineVariant:   Color(0xFF484847),
    error:            Color(0xFFFF7351),
  );

  static const light = AppColors._(
    bg:               Color(0xFFF5F5F5),
    surfaceLow:       Color(0xFFFFFFFF),
    surface:          Color(0xFFF0F0F0),
    surfaceHigh:      Color(0xFFE8E8E8),
    surfaceTop:       Color(0xFFDDDDDD),
    primary:          Color(0xFF12AD2B),
    onPrimary:        Color(0xFFFFFFFF),
    onSurface:        Color(0xFF0E0E0E),
    onSurfaceVariant: Color(0xFF6B6B6B),
    outlineVariant:   Color(0xFFCCCCCC),
    error:            Color(0xFFE53935),
  );
}
