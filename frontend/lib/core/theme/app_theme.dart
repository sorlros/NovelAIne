import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  // Font Fallbacks to prevent Tofu (X in boxes)
  static const List<String> _fontFallbacks = [
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'sans-serif',
  ];

  /// The Material theme of [palette]. Widgets that set no colour of their own (dialogs, snack bars,
  /// progress indicators, text buttons) follow it; screens read the palette itself.
  static ThemeData of(AppPalette palette) {
    final textTheme = TextTheme(
      displayLarge: GoogleFonts.lato(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: palette.text,
      ).copyWith(fontFamilyFallback: _fontFallbacks),
      displayMedium: GoogleFonts.lato(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: palette.text,
      ).copyWith(fontFamilyFallback: _fontFallbacks),
      bodyLarge: GoogleFonts.merriweather(
        fontSize: 18,
        height: 1.6, // Better for reading
        color: palette.text,
      ).copyWith(fontFamilyFallback: _fontFallbacks),
      bodyMedium: GoogleFonts.lato(
        fontSize: 16,
        color: palette.muted,
      ).copyWith(fontFamilyFallback: _fontFallbacks),
      labelLarge: GoogleFonts.lato(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.accent,
      ).copyWith(fontFamilyFallback: _fontFallbacks),
    );

    final colorScheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.danger,
      onError: palette.ground,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.muted,
      outline: palette.line,
      outlineVariant: palette.line,
      surfaceContainerLowest: palette.ground,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surface,
      surfaceContainerHighest: palette.raised,
      surfaceTint: Colors.transparent,
      inverseSurface: palette.text,
      onInverseSurface: palette.ground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      extensions: [palette],
      scaffoldBackgroundColor: palette.ground,
      primaryColor: palette.accent,
      cardColor: palette.surface,
      fontFamilyFallback: _fontFallbacks, // Global safety net
      colorScheme: colorScheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: palette.text),
      dividerTheme: DividerThemeData(color: palette.line),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.text),
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 4,
        shadowColor: const Color(0x40000000), // Soft shadow
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Rounded corners
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: palette.muted,
          fontSize: 15,
          height: 1.5,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.raised,
        contentTextStyle: TextStyle(color: palette.text),
        actionTextColor: palette.accent,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: palette.text),
      ),

      // Input Decoration Theme (TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: palette.faint),
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
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.3),
        selectionHandleColor: palette.accent,
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.raised,
          disabledForegroundColor: palette.faint,
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

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.raised,
          disabledForegroundColor: palette.faint,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.accent),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.line),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        elevation: 4,
        shape: const CircleBorder(),
      ),
    );
  }
}
