// lib/main.dart
// CyberCheck Mobil — Ana Giriş Noktası
//
// Başlatma sırası:
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. dotenv.load()      → .env dosyasından ortam değişkenlerini çek
//   3. Supabase.initialize() → veritabanı & auth bağlantısını başlat
//   4. runApp()           → MaterialApp.router ile uygulamayı başlat
//
// Rotalar (go_router):
//   /        → HomeScreen (geçici — ileride auth yönlendirmesi eklenecek)
//   /login   → LoginScreen
//   /dashboard → DashboardScreen
//   /scan    → ScanScreen
//   /profile → ProfileScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/constants.dart';

// ── GoRouter ──────────────────────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true, // geliştirme sırasında rota loglarını göster

  routes: [
    // Geçici ana rota — ileride auth redirect + SplashScreen eklenecek
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const _HomeScreen(),
    ),

    GoRoute(
      path: AppConstants.routeLogin,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppConstants.routeDashboard,
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppConstants.routeScan,
      name: 'scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: AppConstants.routeProfile,
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);

// ── Başlatma ──────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Durum çubuğunu şeffaf yap — tam immersive dark deneyimi için
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:            Colors.transparent,
    statusBarIconBrightness:   Brightness.light,
    systemNavigationBarColor:  Color(0xFF0F172A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // 1. .env dosyasını yükle — debug sarmalayıcısı ile
  try {
    await dotenv.load(fileName: '.env');
    print('RADAR KONTROL: .env başarıyla okundu!');
    print('HEDEF URL: ${dotenv.env['SUPABASE_URL']}');
  } catch (e) {
    print('KRİTİK HATA: .env DOSYASI OKUNAMADI! Detay: $e');
  }

  // 2. Supabase bağlantısını başlat
  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']     ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const CyberCheckApp());
}

// ── Kök Widget ────────────────────────────────────────────────────────────────

class CyberCheckApp extends StatelessWidget {
  const CyberCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CyberCheck',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: _buildTheme(),
    );
  }

  // ── Siber Tema ─────────────────────────────────────────────────────────────
  ThemeData _buildTheme() {
    // Temel metin teması — Google Fonts Inter
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness:   Brightness.dark,

      // Renk şeması
      colorScheme: const ColorScheme.dark(
        // Tailwind slate-900 — web tarafındaki --bg-surface ile uyumlu
        surface:    Color(0xFF0F172A),
        // Neon mavi vurgu — web tarafındaki --accent-primary
        primary:    Color(0xFF3B82F6),
        // İndigo ikincil vurgu
        secondary:  Color(0xFF6366F1),
        // Cyan üçüncül vurgu
        tertiary:   Color(0xFF06B6D4),
        // Hata rengi
        error:      Color(0xFFEF4444),
        onPrimary:  Colors.white,
        onSurface:  Color(0xFFF1F5F9), // slate-100
      ),

      // Arka plan — Tailwind slate-950 (web: --bg-base)
      scaffoldBackgroundColor: const Color(0xFF020617),

      // Tipografi — Inter ağırlıklı, JetBrains Mono terminal/kod alanları için
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF1F5F9),
          letterSpacing: -0.5,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF1F5F9),
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF1F5F9),
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: const Color(0xFFF1F5F9),
          height: 1.6,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF94A3B8), // slate-400
          height: 1.6,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color:          const Color(0xFF475569), // slate-600
          letterSpacing:  0.08,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:     const Color(0xFF0F172A),
        elevation:           0,
        centerTitle:         false,
        surfaceTintColor:    Colors.transparent,
        titleTextStyle:      GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: const Color(0xFFF1F5F9),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
      ),

      // Card
      cardTheme: CardThemeData(
        color:     const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0x1494A3B8), // slate-400 %8 saydamlık
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: const Color(0xFF1E293B), // slate-800
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0x1494A3B8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0x1494A3B8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle:  const TextStyle(color: Color(0xFF475569)),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:   const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color:     Color(0x1494A3B8),
        thickness: 1,
      ),
    );
  }
}

// ── Geçici Ana Ekran ──────────────────────────────────────────────────────────
// Sonraki adımda LoginScreen ile değiştirilecek.

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shield ikonu
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color:        cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                ),
                child: Icon(Icons.security_rounded, size: 40, color: cs.primary),
              ),

              const SizedBox(height: 24),

              Text('CyberCheck', style: tt.displayMedium),

              const SizedBox(height: 8),

              Text(
                'Siber Güvenlik Kontrol Paneli',
                style: tt.bodyMedium,
              ),

              const SizedBox(height: 32),

              // Versiyon etiketi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color:        cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withOpacity(0.25)),
                ),
                child: Text(
                  'v1.0.0 — Mimari Hazır ✓',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color:    cs.primary.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Rotaları test et
              Text('Rotaları Test Et', style: tt.labelSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _NavChip(label: 'Login',     route: AppConstants.routeLogin),
                  _NavChip(label: 'Dashboard', route: AppConstants.routeDashboard),
                  _NavChip(label: 'Scan',      route: AppConstants.routeScan),
                  _NavChip(label: 'Profile',   route: AppConstants.routeProfile),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.route});
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label:         Text(label),
      onPressed:     () => context.go(route),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: GoogleFonts.inter(
        fontSize: 12, color: const Color(0xFF94A3B8),
      ),
      side: const BorderSide(color: Color(0x1494A3B8)),
    );
  }
}
