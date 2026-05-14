// lib/utils/theme.dart
//
// 📌 AMAÇ:
//   Uygulamanın tüm görsel dilini (renkler, tipografi, bileşen stilleri)
//   tek bir yerden yönetir. Web tarafındaki CyberCheck tasarım sistemiyle
//   paralel bir dark cybersecurity teması sunar.
//
// 📦 İÇERİK:
//   - AppColors   → tüm renk sabitleri (web'deki CSS custom properties karşılığı)
//   - AppTextStyles → Inter + JetBrains Mono temelli metin stilleri
//   - AppTheme    → MaterialApp'e verilecek ThemeData
//
// 🚫 BURAYA KOYMA:
//   - Sabit string/sayılar → constants.dart kullan

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Renk Paleti ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Arkaplan katmanları (web: --bg-base / --bg-surface / --bg-elevated)
  static const Color bgBase     = Color(0xFF050810);
  static const Color bgSurface  = Color(0xFF0A0F1E);
  static const Color bgElevated = Color(0xFF0F1629);
  static const Color bgGlass    = Color(0x990F162D); // rgba(15,22,45,0.6)

  // Marka / Vurgu renkleri
  static const Color accentBlue   = Color(0xFF3B82F6); // electric blue
  static const Color accentIndigo  = Color(0xFF6366F1); // indigo
  static const Color accentCyan    = Color(0xFF06B6D4); // cyan

  // Semantik renkler
  static const Color success  = Color(0xFF10B981);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color danger   = Color(0xFFEF4444);
  static const Color dangerBg = Color(0x1FEF4444); // rgba(239,68,68,0.12)

  // Metin renkleri
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // Kenarlıklar
  static const Color borderSubtle = Color(0x1494A3B8); // rgba 8%
  static const Color borderActive = Color(0x803B82F6); // rgba 50%

  // Risk skoru renkleri
  static Color riskColor(int score) {
    if (score >= 70) return danger;
    if (score >= 40) return warning;
    return success;
  }
}

// ── Metin Stilleri ───────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  // Başlıklar — Inter Bold
  static TextStyle heading1 = GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static TextStyle heading2 = GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static TextStyle heading3 = GoogleFonts.inter(
    fontSize: 17, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Gövde metinleri
  static TextStyle body = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.6,
  );
  static TextStyle bodySecondary = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.6,
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textMuted, letterSpacing: 0.04,
  );

  // Monospace — terminal çıktıları, hash değerleri
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle monoHighlight = GoogleFonts.jetBrainsMono(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: AppColors.accentCyan,
  );

  // Buton
  static TextStyle button = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, letterSpacing: 0.02,
  );

  // Risk skoru
  static TextStyle riskScore = GoogleFonts.inter(
    fontSize: 36, fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
  );
}

// ── Ana Tema ─────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgBase,

    colorScheme: const ColorScheme.dark(
      primary:   AppColors.accentBlue,
      secondary: AppColors.accentIndigo,
      tertiary:  AppColors.accentCyan,
      surface:   AppColors.bgSurface,
      error:     AppColors.danger,
      onPrimary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),

    textTheme: TextTheme(
      displayLarge:  AppTextStyles.heading1,
      displayMedium: AppTextStyles.heading2,
      titleLarge:    AppTextStyles.heading3,
      bodyLarge:     AppTextStyles.body,
      bodyMedium:    AppTextStyles.bodySecondary,
      labelSmall:    AppTextStyles.caption,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor:  AppColors.bgSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.heading3,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: AppColors.bgElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
      ),
      labelStyle: AppTextStyles.bodySecondary,
      hintStyle: AppTextStyles.bodySecondary,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
    ),
  );
}
