import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colours — mirrors the green/emerald palette from the web app
  static const Color primary = Color(0xFF22C55E);       // green-500
  static const Color primaryDark = Color(0xFF059669);   // emerald-600
  static const Color primaryLight = Color(0xFFDCFCE7);  // green-100
  static const Color primarySurface = Color(0xFFF0FDF4); // green-50

  static const Color textPrimary = Color(0xFF111827);   // gray-900
  static const Color textSecondary = Color(0xFF6B7280); // gray-500
  static const Color textMuted = Color(0xFF9CA3AF);     // gray-400

  static const Color border = Color(0xFFBBF7D0);        // green-200
  static const Color borderLight = Color(0xFFDCFCE7);   // green-100
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF9FAFB);

  // Role accent colours
  static const Color landlordColor = Color(0xFF3B82F6); // blue-500
  static const Color tenantColor = Color(0xFF22C55E);   // green-500
  static const Color contractorColor = Color(0xFFF97316); // orange-500
  static const Color agentColor = Color(0xFFA855F7);    // purple-500

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primaryDark,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
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
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    );
    return base;
  }

  static Color roleColor(String role) {
    switch (role) {
      case 'landlord':
        return landlordColor;
      case 'tenant':
        return tenantColor;
      case 'contractor':
        return contractorColor;
      case 'agent':
        return agentColor;
      default:
        return primary;
    }
  }

  static LinearGradient roleGradient(String role) {
    switch (role) {
      case 'landlord':
        return const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        );
      case 'tenant':
        return const LinearGradient(
          colors: [Color(0xFF4ADE80), Color(0xFF059669)],
        );
      case 'contractor':
        return const LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
        );
      case 'agent':
        return const LinearGradient(
          colors: [Color(0xFFC084FC), Color(0xFF9333EA)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF4ADE80), Color(0xFF059669)],
        );
    }
  }

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryDark],
  );
}
