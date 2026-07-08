import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE10600);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      primary: primary,
      surface: surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
  );
}