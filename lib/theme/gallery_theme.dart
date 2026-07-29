import 'package:flutter/material.dart';

class GalleryColors {
  static const black = Color(0xFF08070B);
  static const surface = Color(0xFF14111A);
  static const surfaceRaised = Color(0xFF201A29);

  // Compatibility names used by the Studio screens.
  static const panel = surfaceRaised;

  static const purple = Color(0xFF9C4DFF);
  static const purpleBright = Color(0xFFB86BFF);
  static const purpleDeep = Color(0xFF5D1DA9);
  static const silver = Color(0xFFC7C5CE);
  static const muted = Color(0xFF9A94A3);
  static const success = Color(0xFF69D39C);
}

class GalleryTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: GalleryColors.purple,
      brightness: Brightness.dark,
      surface: GalleryColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: GalleryColors.purple,
        secondary: GalleryColors.silver,
        surface: GalleryColors.surface,
      ),
      scaffoldBackgroundColor: GalleryColors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: GalleryColors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: GalleryColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x337D6C8E)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GalleryColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x337D6C8E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: GalleryColors.purple,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: GalleryColors.surface,
        indicatorColor: Color(0x555D1DA9),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GalleryColors.purple,
        foregroundColor: Colors.white,
      ),
    );
  }
}
