import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Background ─────────────────────────────────────────────────────────────
  static const Color bgPage    = Color(0xFFF5F2EE);
  static const Color bgSurface = Color(0xFFFDFAF7);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const Color border    = Color(0xFFE0DAD2);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1C1C1A);
  static const Color textSecondary = Color(0xFF7A6E62);
  static const Color textMuted     = Color(0xFFA89E93);

  // ── Green — primary brand accent ───────────────────────────────────────────
  static const Color green      = Color(0xFF2D6A2D);
  static const Color greenLight = Color(0xFF6ECF6E);
  static const Color greenBg    = Color(0xFFD6EDD6);

  // ── Dark sections ──────────────────────────────────────────────────────────
  static const Color darkBg     = Color(0xFF141E14);
  static const Color darkBorder = Color(0xFF1F2E1F);
  static const Color darkMuted  = Color(0xFF4A5E4A);
  static const Color darkSubtle = Color(0xFF3D4E3D);

  // ── Role colours — card backgrounds ───────────────────────────────────────
  static const Color landlordBg    = Color(0xFF1E3A5F);
  static const Color landlordGlow  = Color(0xFF60A5FA);
  static const Color tenantBg      = Color(0xFF1A3D1A);
  static const Color tenantGlow    = Color(0xFF6ECF6E);
  static const Color contractorBg  = Color(0xFF7C2D00);
  static const Color contractorGlow = Color(0xFFFB923C);
  static const Color agentBg       = Color(0xFF1C1C1A);
  static const Color agentGlow     = Color(0xFFA78BFA);

  // ── Backward-compat aliases ────────────────────────────────────────────────
  static const Color primary        = green;
  static const Color primaryDark    = green;
  static const Color primaryLight   = greenBg;
  static const Color primarySurface = greenBg;
  static const Color surface        = bgSurface;
  static const Color background     = bgPage;
  static const Color borderLight    = border;
  static const Color landlordColor  = landlordGlow;
  static const Color tenantColor    = tenantGlow;
  static const Color contractorColor = contractorGlow;
  static const Color agentColor     = agentGlow;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        secondary: greenLight,
        surface: bgSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bgPage,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPage,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
    );
  }

  // ── Role helpers ───────────────────────────────────────────────────────────

  /// Solid background colour for role avatar squares.
  static Color roleBg(String role) {
    switch (role) {
      case 'landlord':   return landlordBg;
      case 'tenant':     return tenantBg;
      case 'contractor': return contractorBg;
      case 'agent':      return agentBg;
      default:           return tenantBg;
    }
  }

  /// Accent / glow colour used for stat card bars, badges, etc.
  static Color roleColor(String role) {
    switch (role) {
      case 'landlord':   return landlordGlow;
      case 'tenant':     return tenantGlow;
      case 'contractor': return contractorGlow;
      case 'agent':      return agentGlow;
      default:           return green;
    }
  }
}
