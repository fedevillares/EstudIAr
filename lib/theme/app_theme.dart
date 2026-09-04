import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFFA855F7); 
  static const secondary = Color(0xFF06B6D4);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFFACC15); // Agregamos esta línea para corregir el error
  static const background = Color(0xFF0D0520);

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: Color(0xFF1A1025),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    // ... resto del theme
  );
}