import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
//  BMH DESIGN TOKENS
//  Pulled directly from 00_Brand_System_Reference.html
// ─────────────────────────────────────────────

class BMHColors {
  BMHColors._();

  // Deep navy base — pulled from logo background
  static const Color bg0 = Color(0xFF02060F); // deepest, almost black
  static const Color bg1 = Color(0xFF050C1C); // primary navy
  static const Color bg2 = Color(0xFF0A1428); // elevated surface
  static const Color bg3 = Color(0xFF10203D); // card surface
  static const Color bg4 = Color(0xFF162A4D); // raised card

  // Surfaces (with opacity)
  static const Color surface    = Color(0x9910203D); // rgba(16,32,61,0.6)
  static const Color surfaceHi  = Color(0xBF162A4D); // rgba(22,42,77,0.75)
  static const Color surfaceGlass = Color(0x800A1428);

  // Ink (text on dark)
  static const Color ink      = Color(0xFFEEF4FF); // primary text
  static const Color ink2     = Color(0xFFC9D4E8); // secondary text
  static const Color inkDim   = Color(0xFF8A98B4); // dim / captions
  static const Color inkMute  = Color(0xFF5A6A88); // muted
  static const Color inkFaint = Color(0xFF384866);

  // Hairlines
  static const Color line       = Color(0x1F78A0DC); // rgba(120,160,220,0.12)
  static const Color lineBright = Color(0x4000D4E8); // rgba(0,212,232,0.25)
  static const Color lineSoft   = Color(0x0F78A0DC); // rgba(120,160,220,0.06)

  // Brand cyan — from logo scan-line figure
  static const Color cyan      = Color(0xFF00D4E8);
  static const Color cyan2     = Color(0xFF00A8C4);
  static const Color cyanDeep  = Color(0xFF006E82);
  static const Color cyanSoft  = Color(0x1F00D4E8); // 0.12 alpha
  static const Color cyanFaint = Color(0x0A00D4E8); // 0.04 alpha
  static const Color cyanGlow  = Color(0x5900D4E8); // 0.35 alpha

  // Signal colours — biological domains
  static const Color sCardio    = Color(0xFFFF5577); // heart rate / cardiovascular
  static const Color sOxygen    = Color(0xFF3B82F6); // SpO2 / respiratory
  static const Color sDna       = Color(0xFFA78BFA); // DNA / genetics
  static const Color sMetabolic = Color(0xFFFBBF24); // metabolic / glucose
  static const Color sNervous   = Color(0xFFFB923C); // stress / nervous system
  static const Color sSleep     = Color(0xFF8B5CF6); // sleep
  static const Color sGut       = Color(0xFF34D399); // gut / microbiome / HRV
  static const Color sBody      = Color(0xFF00D4E8); // body composition (= cyan)

  // State colours
  static const Color success = Color(0xFF34D399);
  static const Color warn    = Color(0xFFFBBF24);
  static const Color danger  = Color(0xFFFF4D4D);

  // Helper — signal color with 0.08 alpha (metric card bg)
  static Color signalBg(Color signal) => signal.withOpacity(0.08);
  static Color signalBorder(Color signal) => signal.withOpacity(0.20);
}

// ─────────────────────────────────────────────
//  TYPOGRAPHY  — via Google Fonts (no local font files needed)
//  All styles are static getters (not const) because GoogleFonts
//  returns non-const TextStyle objects.
// ─────────────────────────────────────────────

class BMHText {
  BMHText._();

  // ── Display — Fraunces serif ──────────────────────────
  static TextStyle get displayXl => GoogleFonts.fraunces(
    fontSize: 54, height: 60/54,
    fontWeight: FontWeight.w300, color: BMHColors.ink,
    letterSpacing: -0.02 * 54,
  );
  static TextStyle get displayLg => GoogleFonts.fraunces(
    fontSize: 40, height: 46/40,
    fontWeight: FontWeight.w300, color: BMHColors.ink,
    letterSpacing: -0.02 * 40,
  );
  static TextStyle get displayMd => GoogleFonts.fraunces(
    fontSize: 32, height: 40/32,
    fontWeight: FontWeight.w300, color: BMHColors.ink,
    letterSpacing: -0.025 * 32,
  );
  static TextStyle get displaySm => GoogleFonts.fraunces(
    fontSize: 24, height: 32/24,
    fontWeight: FontWeight.w400, color: BMHColors.ink,
  );

  // ── Headings — Fraunces ───────────────────────────────
  static TextStyle get heading1 => GoogleFonts.fraunces(
    fontSize: 22, height: 28/22,
    fontWeight: FontWeight.w400, color: BMHColors.ink,
    letterSpacing: -0.01 * 22,
  );
  static TextStyle get heading2 => GoogleFonts.fraunces(
    fontSize: 17, height: 24/17,
    fontWeight: FontWeight.w400, color: BMHColors.ink,
  );
  static TextStyle get heading3 => GoogleFonts.fraunces(
    fontSize: 15, height: 22/15,
    fontWeight: FontWeight.w500, color: BMHColors.ink,
  );
  static TextStyle get greetTitle => GoogleFonts.fraunces(
    fontSize: 30, height: 1.15,
    fontWeight: FontWeight.w300, color: BMHColors.ink,
    letterSpacing: -0.02 * 30,
  );

  // ── Body — Plus Jakarta Sans ──────────────────────────
  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
    fontSize: 15, height: 24/15,
    fontWeight: FontWeight.w400, color: BMHColors.ink,
  );
  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
    fontSize: 13, height: 20/13,
    fontWeight: FontWeight.w400, color: BMHColors.ink,
  );
  static TextStyle get bodySm => GoogleFonts.plusJakartaSans(
    fontSize: 11, height: 16/11,
    fontWeight: FontWeight.w400, color: BMHColors.ink2,
  );

  // ── Labels — Plus Jakarta Sans ────────────────────────
  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
    fontSize: 13, height: 18/13,
    fontWeight: FontWeight.w500, color: BMHColors.ink,
  );
  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
    fontSize: 11, height: 16/11,
    fontWeight: FontWeight.w500, color: BMHColors.inkMute,
  );
  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
    fontSize: 10, height: 14/10,
    fontWeight: FontWeight.w600, color: BMHColors.inkMute,
    letterSpacing: 0.05 * 10,
  );

  // ── Mono — JetBrains Mono ─────────────────────────────
  static TextStyle get monoLg => GoogleFonts.jetBrainsMono(
    fontSize: 11, height: 16/11,
    fontWeight: FontWeight.w500, color: BMHColors.inkMute,
    letterSpacing: 0.15 * 11,
  );
  static TextStyle get monoMd => GoogleFonts.jetBrainsMono(
    fontSize: 10, height: 14/10,
    fontWeight: FontWeight.w500, color: BMHColors.inkMute,
    letterSpacing: 0.22 * 10,
  );
  static TextStyle get monoSm => GoogleFonts.jetBrainsMono(
    fontSize: 9, height: 12/9,
    fontWeight: FontWeight.w500, color: BMHColors.inkMute,
    letterSpacing: 0.28 * 9,
  );

  // ── Eyebrow — mono cyan ───────────────────────────────
  static TextStyle get eyebrow => GoogleFonts.jetBrainsMono(
    fontSize: 10, height: 14/10,
    fontWeight: FontWeight.w500, color: BMHColors.cyan,
    letterSpacing: 0.30 * 10,
  );

  // ── Italic editorial — Fraunces italic ───────────────
  static TextStyle get italic => GoogleFonts.fraunces(
    fontSize: 14, height: 22/14,
    fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
    color: BMHColors.inkDim,
  );
}

// ─────────────────────────────────────────────
//  SPACING & RADII
// ─────────────────────────────────────────────

class BMHSpacing {
  BMHSpacing._();
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s8  = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double screenH = 20; // horizontal screen edge padding
}

class BMHRadius {
  BMHRadius._();
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 22;
  static const double full = 9999;
}

// ─────────────────────────────────────────────
//  SHADOWS
// ─────────────────────────────────────────────

class BMHShadows {
  BMHShadows._();
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 40, spreadRadius: -16, offset: const Offset(0, 20),
    ),
  ];
  static List<BoxShadow> get cyan => [
    BoxShadow(
      color: BMHColors.cyanGlow,
      blurRadius: 32, spreadRadius: -8, offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.45),
      blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8),
    ),
  ];
}
