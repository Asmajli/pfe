import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg        = Color(0xFF060912);
  static const surface   = Color(0xFF0D1220);
  static const card      = Color(0xFF111827);
  static const border    = Color(0x1A3B82F6);
  static const blue      = Color(0xFF2563EB);
  static const blue2     = Color(0xFF3B82F6);
  static const cyan      = Color(0xFF06B6D4);
  static const green     = Color(0xFF10B981);
  static const yellow    = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFF8B5CF6);
  static const textPri   = Color(0xFFE2E8F0);
  static const textSec   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  static const blueGrad  = LinearGradient(colors:[blue, cyan], begin:Alignment.topLeft, end:Alignment.bottomRight);
  static const greenGrad = LinearGradient(colors:[green, cyan], begin:Alignment.topLeft, end:Alignment.bottomRight);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue2, secondary: AppColors.cyan,
        surface: AppColors.surface, background: AppColors.bg, error: AppColors.red,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPri, displayColor: AppColors.textPri,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue2, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.red)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue2, foregroundColor: Colors.white,
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface, elevation: 0,
        titleTextStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPri),
        iconTheme: const IconThemeData(color: AppColors.textPri),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface, selectedItemColor: AppColors.cyan,
        unselectedItemColor: AppColors.textMuted, elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true, showUnselectedLabels: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: const TextStyle(color: AppColors.textPri),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
