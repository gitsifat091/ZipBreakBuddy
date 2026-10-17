import 'package:flutter/material.dart';

class ZipColors {
  static const background = Color(0xFFF6F2EA);
  static const text = Color(0xFF1E2A3A);
  static const accent = Color(0xFFF26B1D);
  static const muted = Color(0xFF6B7584);
  static const line = Color(0xFFE4DDD0);
}

const zipRadius = 20.0;

ThemeData buildZipTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    colorScheme: ColorScheme.fromSeed(
      seedColor: ZipColors.accent,
      primary: ZipColors.accent,
      surface: ZipColors.background,
      onSurface: ZipColors.text,
    ),
    scaffoldBackgroundColor: Colors.transparent,
  );
  // Derive from the theme's label style so the font family carries over;
  // a bare TextStyle here would drop it.
  final buttonText = base.textTheme.labelLarge!.copyWith(
    fontWeight: FontWeight.w600,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ZipColors.text,
      displayColor: ZipColors.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZipColors.accent,
        foregroundColor: Colors.white,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZipColors.text,
        side: const BorderSide(color: ZipColors.line, width: 1.5),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
  );
}
