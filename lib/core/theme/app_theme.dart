import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Page / surface backgrounds ─────────────────────────────────────────────
  static const Color bg        = Color(0xFF0A0A0C);
  static const Color bgPage    = Color(0xFF0A0A0C);   // backward-compat alias
  static const Color bgSurface = Color(0xFF131316);   // cards / sheet surfaces
  static const Color card2     = Color(0xFF1C1C20);   // nested surfaces

  // ── Borders ────────────────────────────────────────────────────────────────
  static const Color border     = Color(0x12FFFFFF);  // rgba(255,255,255,0.07)
  static const Color borderLight = Color(0x12FFFFFF); // alias

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF2F2F3);
  static const Color textSecondary = Color(0xFF9A9AA4);
  static const Color textMuted     = Color(0xFF6B6B72);

  // ── Green — primary brand accent ───────────────────────────────────────────
  static const Color green      = Color(0xFF4ADE80);
  static const Color greenLight = Color(0xFF4ADE80);
  static const Color greenBg    = Color(0x264ADE80); // rgba(74,222,128,0.15)

  // ── Dark section aliases (kept for backward compat with SnackBar refs) ─────
  static const Color darkBg     = Color(0xFF0A0A0C);
  static const Color darkBorder = Color(0x12FFFFFF);
  static const Color darkMuted  = Color(0xFF6B6B72);
  static const Color darkSubtle = Color(0x33FFFFFF);

  // ── Role colours ───────────────────────────────────────────────────────────
  // Backgrounds
  static const Color landlordBg    = Color(0xFF0F2D1F);
  static const Color tenantBg      = Color(0xFF1A1A0A);
  static const Color contractorBg  = Color(0xFF1F0F0A);
  static const Color agentBg       = Color(0xFF0D0F2A);

  // Accent / glow colours
  static const Color landlordGlow   = Color(0xFF4ADE80);
  static const Color tenantGlow     = Color(0xFFEAB308);
  static const Color contractorGlow = Color(0xFFFB923C);
  static const Color agentGlow      = Color(0xFF818CF8);

  // ── Backward-compat aliases ────────────────────────────────────────────────
  static const Color primary        = green;
  static const Color primaryDark    = green;
  static const Color primaryLight   = greenBg;
  static const Color primarySurface = greenBg;
  static const Color surface        = bgSurface;
  static const Color background     = bgPage;
  static const Color landlordColor  = landlordGlow;
  static const Color tenantColor    = tenantGlow;
  static const Color contractorColor = contractorGlow;
  static const Color agentColor     = agentGlow;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:    green,
        secondary:  greenLight,
        surface:    bgSurface,
        onPrimary:  bgPage,
        onSecondary: bgPage,
        onSurface:  textPrimary,
        outline:    border,
      ),
      scaffoldBackgroundColor: bgPage,
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.dmSans(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.dmSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
        prefixIconColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: bgPage,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          textStyle: GoogleFonts.dmSans(
              fontSize: 15, fontWeight: FontWeight.w500,
              letterSpacing: -0.3),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          textStyle: GoogleFonts.dmSans(
              fontSize: 15, fontWeight: FontWeight.w500),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPage,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgSurface,
        modalBackgroundColor: bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.3,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 13, color: textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? bgPage : textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? green : border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgSurface,
        contentTextStyle: GoogleFonts.dmSans(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }

  // Keep 'light' getter pointing to the same theme for zero-change compat
  // (main.dart references AppTheme.light — updated separately)
  static ThemeData get light => dark;

  // ── Role helpers ───────────────────────────────────────────────────────────

  /// Solid background colour for role avatar squares.
  static Color roleBg(String role) {
    switch (role) {
      case 'landlord':   return landlordBg;
      case 'tenant':     return tenantBg;
      case 'contractor': return contractorBg;
      case 'agent':      return agentBg;
      default:           return bgSurface;
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
