import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Backgrounds (فاتح ونظيف) ────────────────────────
  static const bg        = Color(0xFFf0f4f8);   // رمادي-أزرق فاتح جداً
  static const surface   = Color(0xFFffffff);   // أبيض ناصع
  static const card      = Color(0xFFffffff);   // بطاقات بيضاء

  // ── Borders ──────────────────────────────────────────
  static const border    = Color(0xFFe2e8f0);   // حدود خفيفة رمادية

  // ── Primary Blues ────────────────────────────────────
  static const blue      = Color(0xFF2563eb);   // أزرق أساسي قوي
  static const blue2     = Color(0xFF3b82f6);   // أزرق فاتح
  static const cyan      = Color(0xFF0891b2);   // سماوي

  // ── Accents ──────────────────────────────────────────
  static const green     = Color(0xFF16a34a);   // أخضر واضح
  static const yellow    = Color(0xFFd97706);   // ذهبي
  static const red       = Color(0xFFdc2626);   // أحمر
  static const purple    = Color(0xFF7c3aed);   // بنفسجي
  static const orange    = Color(0xFFea580c);   // برتقالي

  // ── Text ─────────────────────────────────────────────
  static const textPri   = Color(0xFF0f172a);   // أسود-أزرق عميق
  static const textSec   = Color(0xFF334155);   // رمادي-أزرق داكن
  static const textMuted = Color(0xFF94a3b8);   // رمادي خافت
  static const text      = Color(0xFF0f172a);
  static const text2     = Color(0xFF475569);

  // ── Aliases ──────────────────────────────────────────
  static const white     = Color(0xFFffffff);
  static const highlight = Color(0xFF3b82f6);
  static const accent    = Color(0xFF0891b2);
  static const darkText  = Color(0xFF0f172a);

  // ── Shadows ──────────────────────────────────────────
  static const shadow   = BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2));
  static const shadowMd = BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 4));

  // ── Gradients ────────────────────────────────────────
  static const blueGrad = LinearGradient(
    colors: [blue, cyan],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const greenGrad = LinearGradient(
    colors: [green, Color(0xFF0891b2)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const oceanGrad = LinearGradient(
    colors: [blue, cyan],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const parkingCardGrad = LinearGradient(
    colors: [Color(0xFFf8fafc), Color(0xFFf1f5f9)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const parkingCardGradAlt = LinearGradient(
    colors: [white, Color(0xFFf8fafc)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary:    AppColors.blue,
        secondary:  AppColors.cyan,
        surface:    AppColors.surface,
        error:      AppColors.red,
      ),
      textTheme: base.textTheme.apply(
        bodyColor:    AppColors.textSec,
        displayColor: AppColors.textPri,
      ),
      cardColor:    AppColors.card,
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
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
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPri,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPri, size: 24),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.border,
    ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.textMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 24),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPri,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}