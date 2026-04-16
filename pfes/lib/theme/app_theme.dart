import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Backgrounds ────────────────────────────────────
  static const bg        = Color.fromRGBO(52, 144, 141, 1);      // أخضر-أزرق جميل 🎨
  static const surface   = Color.fromRGBO(65, 165, 162, 1);      // أفتح شوي
  static const card      = Color.fromRGBO(40, 110, 107, 1);      // أغمق للبطاقات

  // ── Borders ────────────────────────────────────────
  static const border    = Color.fromRGBO(75, 180, 177, 1);      // يتناسب مع الألوان

  // ── Primary Colors ─────────────────────────────────
  static const blue      = Color.fromRGBO(52, 144, 141, 1);      // نفس اللون الأساسي
  static const blue2     = Color.fromRGBO(85, 180, 177, 1);      // نسخة أفتح
  static const cyan      = Color.fromRGBO(100, 200, 200, 1);     // سماوي متناسق

  // ── Accent Colors ──────────────────────────────────
  static const green     = Color.fromRGBO(52, 144, 141, 1);      // أخضر-أزرق مثل الأساسي
  static const yellow    = Color.fromRGBO(255, 193, 7, 1);       // أصفر ذهبي دافئ
  static const red       = Color.fromRGBO(244, 67, 54, 1);       // أحمر واضح
  static const purple    = Color.fromRGBO(156, 39, 176, 1);      // بنفسجي عميق
  static const orange    = Color.fromRGBO(255, 152, 0, 1);       // برتقالي دافئ

  // ── Text ───────────────────────────────────────────
  static const textPri   = Color.fromRGBO(255, 255, 255, 1);     // أبيض ناصع
  static const textSec   = Color.fromRGBO(230, 240, 240, 1);     // أبيض فاتح
  static const textMuted = Color.fromRGBO(200, 220, 220, 1);     // رمادي فاتح متناسق

  // ── Special UI Colors ──────────────────────────────
  static const white      = Color.fromRGBO(255, 255, 255, 1);    // أبيض ناصع
  static const highlight  = Color.fromRGBO(255, 255, 255, 1);    // للخطوط البيضاء
  static const accent     = Color.fromRGBO(85, 180, 177, 1);     // تأكيد ثانوي
  static const darkText   = Color.fromRGBO(52, 144, 141, 1);     // نص داكن على أبيض

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
  
  // ── Parking Card Gradient (البيض) ──────────────
  static const parkingCardGrad = LinearGradient(
    colors: [
      Color.fromRGBO(255, 255, 255, 1),  // أبيض
      Color.fromRGBO(240, 248, 248, 1),  // أبيض فاتح جداً
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const parkingCardGradAlt = LinearGradient(
    colors: [
      Color.fromRGBO(250, 250, 250, 1),      // أبيض فاتح
      Color.fromRGBO(240, 248, 248, 1),      // أبيض أفتح
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        background: AppColors.bg,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textSec,
        displayColor: AppColors.textPri,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: AppColors.textSec, fontSize: 14),
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
          backgroundColor: AppColors.blue,
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
        unselectedItemColor: AppColors.textSec,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
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