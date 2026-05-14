// lib/services/supabase_service.dart
//
// 📌 AMAÇ:
//   Supabase ile tüm doğrudan iletişimi tek bir sınıf üzerinden yönetir.
//   Auth işlemleri (giriş, kayıt, çıkış, oturum dinleme) burada tanımlanır.
//   Veritabanı sorguları (scan geçmişi okuma/yazma) da buraya eklenir.
//
// 📦 GELECEKTE EKLENECEK METODLAR:
//   - fetchScanHistory(userId)   → scans tablosundan kullanıcı geçmişi
//   - insertScan(data)           → yeni tarama kaydı ekleme
//   - uploadReport(file)         → PDF raporunu Supabase Storage'a yükleme
//
// 🔑 BAĞIMLILIK:
//   - supabase_flutter paketi
//   - AppConstants.supabaseUrl / supabaseAnonKey (.env'den okunur)

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // Supabase istemcisine kısayol
  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient   get auth   => client.auth;

  // ── Mevcut oturum ──────────────────────────────────────────────
  Session? get currentSession => auth.currentSession;
  User?    get currentUser    => auth.currentUser;
  bool     get isLoggedIn     => currentSession != null;

  // ── Auth: e-posta & şifre ile giriş ───────────────────────────
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(email: email, password: password);
  }

  // ── Auth: yeni hesap oluşturma ─────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await auth.signUp(email: email, password: password);
  }

  // ── Auth: çıkış ───────────────────────────────────────────────
  Future<void> signOut() async {
    await auth.signOut();
  }

  // ── Auth: oturum değişikliklerini dinle ────────────────────────
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  // ── Veritabanı: tarama geçmişi ────────────────────────────────
  // TODO: Sonraki adımda implemente edilecek
  // Future<List<Map<String, dynamic>>> fetchScanHistory() async { ... }

  // ── Veritabanı: tarama kaydı ekle ─────────────────────────────
  // TODO: Sonraki adımda implemente edilecek
  // Future<void> insertScan(Map<String, dynamic> data) async { ... }
}
