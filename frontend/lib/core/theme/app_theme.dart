import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color _primaryBlue = Color(0xFF7AA2F7); // Soft Blue
  static const Color _backgroundDark = Color(0xFF1A1B26); // Deep Navy/Charcoal
  static const Color _surfaceDark = Color(0xFF24283B); // Lighter Blue-Grey
  static const Color _textPrimary = Color(0xFFC0CAF5); // Moonlight White
  static const Color _textSecondary = Color(0xFF565F89); // Muted Blue-Grey
  static const Color _accentGreen = Color(0xFF9ECE6A); // Soft Green
  static const Color _errorRed = Color(0xFFF7768E); // Soft Red

  // Text Styles
  static final TextTheme _textTheme = TextTheme(
    displayLarge: GoogleFonts.lato(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: _textPrimary,
    ),
    displayMedium: GoogleFonts.lato(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: _textPrimary,
    ),
    bodyLarge: GoogleFonts.merriweather(
      fontSize: 18,
      height: 1.6, // Better for reading
      color: _textPrimary,
    ),
    bodyMedium: GoogleFonts.lato(fontSize: 16, color: _textSecondary),
    labelLarge: GoogleFonts.lato(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: _primaryBlue,
    ),
  );

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _backgroundDark,
      primaryColor: _primaryBlue,
      cardColor: _surfaceDark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: _primaryBlue,
        secondary: _accentGreen,
        surface: _surfaceDark,
        error: _errorRed,
        onPrimary: _backgroundDark,
        onSecondary: _backgroundDark,
        onSurface: _textPrimary,
      ),

      // Text Theme
      textTheme: _textTheme,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _textPrimary),
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 4,
        shadowColor: const Color(0x40000000), // Soft shadow
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Rounded corners
        ),
      ),

      // Input Decoration Theme (TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Pill shape
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: _backgroundDark,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryBlue,
        foregroundColor: _backgroundDark,
        elevation: 4,
        shape:
            CircleBorder(), // Or RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
      ),
    );
  }
}
