import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const backgroundDecoration = BoxDecoration(color: Color(0xFF0D0E10));

  static ThemeData get darkTheme {
    const background = Color(0xFF0D0E10);
    const surface = Color(0xFF15171A);
    const card = Color(0xFF1B1E22);
    const accent = Color(0xFFF03A37);
    const accentContainer = Color(0xFF5B2024);
    const outline = Color(0xFF3A3E44);
    const text = Color(0xFFE7E8EA);
    const mutedText = Color(0xFFB5B8BD);
    final baseTextTheme = GoogleFonts.rajdhaniTextTheme(
      ThemeData.dark().textTheme,
    );
    final textTheme = baseTextTheme.copyWith(
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: text, height: 1.5),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: mutedText,
        height: 1.5,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.rajdhani().fontFamily,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Color(0xFF1A0A0B),
        primaryContainer: accentContainer,
        onPrimaryContainer: Color(0xFFFFDAD9),
        secondary: Color(0xFFB9C7D9),
        onSecondary: Color(0xFF17202B),
        surface: surface,
        surfaceContainerLowest: Color(0xFF101214),
        surfaceContainerLow: Color(0xFF181A1D),
        surfaceContainer: card,
        surfaceContainerHigh: Color(0xFF24282D),
        surfaceContainerHighest: Color(0xFF2C3036),
        onSurface: text,
        onSurfaceVariant: mutedText,
        outline: outline,
        outlineVariant: Color(0xFF2B2F34),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        foregroundColor: text,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121820),
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : mutedText,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            color: mutedText,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF181A1D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF202832),
          foregroundColor: text,
          side: const BorderSide(color: accent, width: 1),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: outline),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: accentContainer,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: textTheme.labelLarge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF202328),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: text,
        textColor: text,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2B2F34),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C3036),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      iconTheme: const IconThemeData(color: text, size: 24),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
      ),
    );
  }
}
