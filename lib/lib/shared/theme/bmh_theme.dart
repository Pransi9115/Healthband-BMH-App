import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bmh_tokens.dart';

class BMHTheme {
  BMHTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: BMHColors.bg0,
    colorScheme: const ColorScheme.dark(
      surface: BMHColors.bg2,
      primary: BMHColors.cyan,
      onPrimary: BMHColors.bg0,
      secondary: BMHColors.cyan2,
      onSecondary: BMHColors.bg0,
      error: BMHColors.danger,
      onSurface: BMHColors.ink,
    ),
    // Set Plus Jakarta Sans as the default text theme
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: BMHColors.ink, displayColor: BMHColors.ink),

    // App bar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: BMHColors.bg0,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: BMHText.heading2,
      iconTheme: const IconThemeData(color: BMHColors.ink, size: 20),
    ),

    // Bottom nav
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: BMHColors.cyan,
      unselectedItemColor: BMHColors.inkMute,
      selectedLabelStyle: BMHText.monoMd,
      unselectedLabelStyle: BMHText.monoMd,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: BMHColors.line,
      thickness: 1,
      space: 0,
    ),

    // Card
    cardTheme: CardThemeData(
      color: BMHColors.bg3,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        side: const BorderSide(color: BMHColors.line, width: 1),
      ),
    ),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BMHColors.bg3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BMHRadius.md),
        borderSide: const BorderSide(color: BMHColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BMHRadius.md),
        borderSide: const BorderSide(color: BMHColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BMHRadius.md),
        borderSide: const BorderSide(color: BMHColors.cyan, width: 1.5),
      ),
      labelStyle: BMHText.labelMd,
      hintStyle: BMHText.labelMd,
    ),

    // Elevated button = primary cyan
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BMHColors.cyan,
        foregroundColor: BMHColors.bg0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.full),
        ),
        textStyle: BMHText.labelLg.copyWith(
          fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
        elevation: 0,
      ),
    ),

    // Outlined button = secondary
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BMHColors.cyan,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: BMHColors.cyan),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.full),
        ),
        textStyle: BMHText.labelLg,
      ),
    ),

    // Text button = ghost
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BMHColors.cyan,
        textStyle: BMHText.labelLg,
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BMHColors.bg4,
      contentTextStyle: BMHText.bodyMd,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BMHRadius.md),
      ),
    ),
  );
}
