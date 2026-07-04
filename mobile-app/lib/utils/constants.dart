// lib/utils/constants.dart
//
// 📌 AMAÇ:
//   Uygulamanın genelinde kullanılan sabit değerleri merkezi bir yerde tutar.
//   Magic string / magic number kullanımını önler.
//
// 📦 İÇERİK:
//   - API endpoint'leri ve route path'leri
//   - Supabase tablo/bucket adları
//   - Uygulama genelindeki boyut/süre sabitleri
//   - Hata mesajları ve etiketler
//
// 🚫 BURAYA KOYMA:
//   - Tema renkleri → theme.dart kullan
//   - API anahtarları → .env kullan (flutter_dotenv ile oku)

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._(); // instantiate edilemesin

  // ── Backend API ─────────────────────────────────────────────────
  static String get apiBaseUrl =>
      dotenv.env['BACKEND_API_URL'] ?? 'http://localhost:5000';

  static String get scanUrlEndpoint    => '$apiBaseUrl/api/scan/url';
  static String get scanFileEndpoint   => '$apiBaseUrl/api/scan/upload';
  static String get scanImageEndpoint  => '$apiBaseUrl/api/scan/image';
  static String get scanTextEndpoint   => '$apiBaseUrl/api/scan/text';
  static String get historyEndpoint    => '$apiBaseUrl/api/scan/history';

  // ── Supabase ────────────────────────────────────────────────────
  static String get supabaseUrl     => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static const String tableScans    = 'scans';
  static const String bucketReports = 'reports';

  // ── go_router Route İsimleri ─────────────────────────────────────
  static const String routeSplash    = '/';
  static const String routeLogin     = '/login';
  static const String routeDashboard = '/dashboard';
  static const String routeScan      = '/scan';
  static const String routeReport    = '/report/:id';
  static const String routeProfile   = '/profile';

  // ── UI Sabitleri ─────────────────────────────────────────────────
  static const double paddingPage   = 20.0;
  static const double paddingCard   = 16.0;
  static const double radiusCard    = 16.0;
  static const double radiusButton  = 12.0;

  // ── Animasyon Süreleri ───────────────────────────────────────────
  static const Duration animFast   = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow   = Duration(milliseconds: 500);

  // ── Hata Mesajları ───────────────────────────────────────────────
  static const String errNetwork    = 'Sunucuya bağlanılamadı. İnternet bağlantını kontrol et.';
  static const String errUnknown    = 'Beklenmedik bir hata oluştu.';
  static const String errFileTooBig = 'Dosya boyutu 10 MB\'ı aşamaz.';
}
