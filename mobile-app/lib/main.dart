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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/result_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'utils/constants.dart';

// ── GoRouter ──────────────────────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true, // geliştirme sırasında rota loglarını göster

  routes: [
    // Ana karşılama ekranı — Giriş Yap / Kayıt Ol
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const _LandingScreen(),
    ),

    GoRoute(
      path: AppConstants.routeLogin,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
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
      path: '/result',
      name: 'result',
      builder: (context, state) {
        final data = state.extra as ScanResultData?;
        if (data == null) {
          Future.microtask(() => context.go('/scan'));
          return const Scaffold(
            backgroundColor: Color(0xFF050810),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ResultScreen(data: data);
      },
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
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
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

// ── Karşılama Ekranı ──────────────────────────────────────────────────────────

class _LandingScreen extends StatefulWidget {
  const _LandingScreen();

  @override
  State<_LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<_LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Sayfa giriş animasyonu
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    // Kalkan ikonu nabız animasyonu
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildShieldIcon(),
                      const SizedBox(height: 32),
                      _buildBranding(),
                      const SizedBox(height: 48),
                      _buildActionButtons(context),
                      const SizedBox(height: 40),
                      _buildSecurityBadges(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Kalkan ikonu — nabız efektli ─────────────────────────────────────────

  Widget _buildShieldIcon() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          width:  100,
          height: 100,
          decoration: BoxDecoration(
            color:        const Color(0xFF3B82F6).withValues(alpha: 0.10 * _pulseAnim.value),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.35 * _pulseAnim.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:       const Color(0xFF3B82F6).withValues(alpha: 0.25 * _pulseAnim.value),
                blurRadius:  32 * _pulseAnim.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.security_rounded,
            size:  48,
            color: Color(0xFF3B82F6),
          ),
        );
      },
    );
  }

  // ── Marka ismi ve alt başlık ──────────────────────────────────────────────

  Widget _buildBranding() {
    return Column(
      children: [
        Text(
          'CyberCheck',
          style: GoogleFonts.inter(
            fontSize:      40,
            fontWeight:    FontWeight.w800,
            color:         const Color(0xFFF1F5F9),
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Siber güvenliğinizi\nbir adım öne taşıyın.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize:   15,
            fontWeight: FontWeight.w400,
            color:      const Color(0xFF64748B),
            height:     1.6,
          ),
        ),
      ],
    );
  }

  // ── Aksiyon butonları — Giriş Yap + Kayıt Ol ─────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Giriş Yap — Dolu (birincil)
        SizedBox(
          width:  double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => context.go(AppConstants.routeLogin),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation:       0,
              shadowColor:     Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.15);
                }
                return Colors.white.withValues(alpha: 0.06);
              }),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Giriş Yap',
                  style: GoogleFonts.inter(
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Kayıt Ol — Kenarlıklı (ikincil)
        SizedBox(
          width:  double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () => context.go('/register'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.06),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.pressed)) {
                  return const Color(0xFF3B82F6).withValues(alpha: 0.15);
                }
                return const Color(0xFF3B82F6).withValues(alpha: 0.04);
              }),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Kayıt Ol',
                  style: GoogleFonts.inter(
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Güvenlik rozetleri ────────────────────────────────────────────────────

  Widget _buildSecurityBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _badge(Icons.lock_outline_rounded, 'Şifreli Bağlantı'),
        const SizedBox(width: 20),
        _badge(Icons.verified_user_rounded, 'Güvenli Auth'),
        const SizedBox(width: 20),
        _badge(Icons.shield_outlined, 'Veri Gizliliği'),
      ],
    );
  }

  Widget _badge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF475569)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize:   9.5,
            color:      const Color(0xFF475569),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
