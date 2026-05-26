import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Colors.white;

  static TextTheme _textTheme(Color bodyColor) => GoogleFonts.poppinsTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: bodyColor),
          displayMedium: TextStyle(color: bodyColor),
          displaySmall: TextStyle(color: bodyColor),
          headlineLarge: TextStyle(color: bodyColor),
          headlineMedium: TextStyle(color: bodyColor),
          headlineSmall: TextStyle(color: bodyColor),
          titleLarge: TextStyle(color: bodyColor),
          titleMedium: TextStyle(color: bodyColor),
          titleSmall: TextStyle(color: bodyColor),
          bodyLarge: TextStyle(color: bodyColor),
          bodyMedium: TextStyle(color: bodyColor),
          bodySmall: TextStyle(color: bodyColor),
          labelLarge: TextStyle(color: bodyColor),
          labelMedium: TextStyle(color: bodyColor),
          labelSmall: TextStyle(color: bodyColor),
        ),
      );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: _textTheme(Colors.black87),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: Colors.black87,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      textTheme: _textTheme(Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
