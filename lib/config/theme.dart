import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FreetaskTheme {
  const FreetaskTheme._();

  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);
    const scaffoldBackground = Color(0xFFF9F9F9);
    final colorScheme = base.colorScheme.copyWith(
      primary: const Color(0xFF3A7BD5),
      secondary: const Color(0xFF3A7BD5),
      surface: Colors.white,
      surfaceContainerLowest: scaffoldBackground,
    );
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: Colors.black87,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A7BD5)),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: const Color(0xFF3A7BD5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
