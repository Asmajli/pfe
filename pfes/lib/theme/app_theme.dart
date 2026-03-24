import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Backgrounds ────────────────────────────────────
  static const bg        = Color(0xFFE2E8F0);   // رمادي فاتح
  static const surface   = Color(0xFFFFFFFF);   // أبيض
  static const card      = Color(0xFFFFFFFF);   // أبيض

  // ── Borders ────────────────────────────────────────
  static const border    = Color(0xFFE2E8F0);   // رمادي فاتح

  // ── Primary Colors ─────────────────────────────────
  static const blue      = Color(0xFF2563EB);   // أزرق
  static const blue2     = Color(0xFF3B82F6);   // أزرق متوسط
  static const cyan      = Color(0xFF0891B2);   // تيل

  // ── Accent Colors ──────────────────────────────────
  static const green     = Color(0xFF059669);   // أخضر
  static const yellow    = Color(0xFFD97706);   // ذهبي
  static const red       = Color(0xFFDC2626);   // أحمر
  static const purple    = Color(0xFF7C3AED);   // بنفسجي
  static const orange    = Color(0xFFEA580C);   // برتقالي

  // ── Text ───────────────────────────────────────────
  static const textPri   = Color(0xFF0F172A);   // أسود ناعم
  static const textSec   = Color(0xFF475569);   // رمادي داكن
  static const textMuted = Color(0xFF94A3B8);   // رمادي فاتح

  // ── Gradients ──────────────────────────────────────
  static const blueGrad = LinearGradient(
    colors: [blue, blue2],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const greenGrad = LinearGradient(
    colors: [green, cyan],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const oceanGrad = LinearGradient(
    colors: [blue, cyan],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue2,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        background: AppColors.bg,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPri,
        displayColor: AppColors.textPri,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue2, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue2,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPri,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPri),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.border,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.blue2,
        unselectedItemColor: AppColors.textMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPri,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}