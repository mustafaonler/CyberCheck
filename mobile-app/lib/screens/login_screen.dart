// lib/screens/login_screen.dart
//
// 📌 AMAÇ:
//   CyberCheck giriş ekranı.
//   - Supabase Auth ile e-posta + şifre doğrulaması
//   - Yükleme durumu yönetimi
//   - Başarılı girişte /dashboard'a go_router yönlendirmesi
//   - Hatalarda kırmızı SnackBar bildirimi
//
// 📦 BAĞIMLILIKLAR:
//   supabase_flutter, go_router, google_fonts
//   utils/theme.dart → AppColors, AppTextStyles
//   utils/constants.dart → AppConstants

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme.dart';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ── Odak ──────────────────────────────────────────────────────────────────
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();

  // ── Durum ─────────────────────────────────────────────────────────────────
  bool _isLoading      = false;
  bool _obscurePassword = true;
  bool _emailFocused    = false;
  bool _passwordFocused = false;

  // ── Giriş animasyonu ──────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;
  late final Animation<Offset>    _slideAnim;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Sayfa açılışında yukarıdan aşağı fade+slide animasyonu
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward();

    // Odak dinleyicileri
    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordFocused = _passwordFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Supabase Auth ─────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    // Klavyeyi kapat
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // Ekran hâlâ mount durumundaysa yönlendir
      if (mounted) {
        context.go(AppConstants.routeDashboard);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(AppConstants.errUnknown);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32,
                ),
                child: ConstrainedBox(
                  // Geniş ekranlarda kartın çok genişlememesi için
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 36),
                      _buildFormCard(),
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

  // ── Üst logo + başlık ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Kalkan ikonu — neon parlama efektli
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color:        AppColors.accentBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentBlue.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:       AppColors.accentBlue.withValues(alpha: 0.20),
                blurRadius:  24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.security_rounded,
            size:  34,
            color: AppColors.accentBlue,
          ),
        ),

        const SizedBox(height: 18),

        // "CyberCheck" — Inter ExtraBold
        Text(
          'CyberCheck',
          style: GoogleFonts.inter(
            fontSize:   28,
            fontWeight: FontWeight.w800,
            color:      AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        // Alt başlık
        Text(
          'Siber tehdit istihbaratı platformu',
          style: GoogleFonts.inter(
            fontSize:   13,
            fontWeight: FontWeight.w400,
            color:      AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Form kartı ───────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        // Hafif daha açık lacivert arka plan
        color:  AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withValues(alpha: 0.30),
            blurRadius:  32,
            offset:      const Offset(0, 8),
          ),
          // İnce mavi çerçeve parlaması
          BoxShadow(
            color:       AppColors.accentBlue.withValues(alpha: 0.06),
            blurRadius:  40,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Text(
              'Hesabına Giriş Yap',
              style: GoogleFonts.inter(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Güvenli erişim için kimliğini doğrula.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color:    AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 28),

            // ── E-posta alanı ──────────────────────────────────────────
            _buildFieldLabel('E-posta Adresi'),
            const SizedBox(height: 6),
            _buildEmailField(),

            const SizedBox(height: 18),

            // ── Şifre alanı ────────────────────────────────────────────
            _buildFieldLabel('Şifre'),
            const SizedBox(height: 6),
            _buildPasswordField(),

            const SizedBox(height: 28),

            // ── Giriş butonu ────────────────────────────────────────────
            _buildLoginButton(),

            const SizedBox(height: 20),

            // ── Kayıt ol linki ──────────────────────────────────────────
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  // ── Yardımcı: Alan etiketi ───────────────────────────────────────────────

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize:   12,
        fontWeight: FontWeight.w600,
        color:      AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  // ── E-posta TextFormField ─────────────────────────────────────────────────

  Widget _buildEmailField() {
    return AnimatedContainer(
      duration: AppConstants.animFast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _emailFocused
            ? [
                BoxShadow(
                  color:       AppColors.accentBlue.withValues(alpha: 0.25),
                  blurRadius:  12,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller:  _emailCtrl,
        focusNode:   _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(
          fontSize:   14,
          color:      AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText:  'ornek@email.com',
          filled:    true,
          fillColor: AppColors.bgBase,
          prefixIcon: Icon(
            Icons.email_outlined,
            size:  18,
            color: _emailFocused
                ? AppColors.accentBlue
                : AppColors.textMuted,
          ),
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
            borderSide: const BorderSide(
              color: AppColors.accentBlue, width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'E-posta boş bırakılamaz.';
          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
          if (!emailRegex.hasMatch(v.trim())) {
            return 'Geçerli bir e-posta adresi girin.';
          }
          return null;
        },
        onFieldSubmitted: (_) =>
            FocusScope.of(context).requestFocus(_passwordFocus),
      ),
    );
  }

  // ── Şifre TextFormField ──────────────────────────────────────────────────

  Widget _buildPasswordField() {
    return AnimatedContainer(
      duration: AppConstants.animFast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _passwordFocused
            ? [
                BoxShadow(
                  color:       AppColors.accentBlue.withValues(alpha: 0.25),
                  blurRadius:  12,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller:  _passwordCtrl,
        focusNode:   _passwordFocus,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        style: GoogleFonts.inter(
          fontSize:   14,
          color:      AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText:  '••••••••',
          filled:    true,
          fillColor: AppColors.bgBase,
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size:  18,
            color: _passwordFocused
                ? AppColors.accentBlue
                : AppColors.textMuted,
          ),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: AnimatedSwitcher(
              duration: AppConstants.animFast,
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                key: ValueKey(_obscurePassword),
                size:  18,
                color: AppColors.textMuted,
              ),
            ),
            splashRadius: 16,
          ),
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
            borderSide: const BorderSide(
              color: AppColors.accentBlue, width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Şifre boş bırakılamaz.';
          if (v.length < 6) return 'Şifre en az 6 karakter olmalıdır.';
          return null;
        },
        onFieldSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  // ── Giriş butonu ─────────────────────────────────────────────────────────

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor:         AppColors.accentBlue,
          disabledBackgroundColor: AppColors.accentBlue.withValues(alpha: 0.5),
          foregroundColor:         Colors.white,
          elevation:               0,
          shadowColor:             Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(
          // Basma efekti — hafif scale
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.12);
            }
            return Colors.white.withValues(alpha: 0.05);
          }),
        ),
        child: AnimatedSwitcher(
          duration: AppConstants.animFast,
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width:  22,
                  height: 22,
                  child:  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color:       Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Giriş Yap',
                      style: GoogleFonts.inter(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color:      Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Kayıt ol linki ───────────────────────────────────────────────────────

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hesabın yok mu?',
          style: GoogleFonts.inter(
            fontSize: 13,
            color:    AppColors.textMuted,
          ),
        ),
        TextButton(
          onPressed: () => context.go('/register'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentBlue,
            padding:         const EdgeInsets.symmetric(horizontal: 6),
            minimumSize:     Size.zero,
            tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Kayıt Ol',
            style: GoogleFonts.inter(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      AppColors.accentBlue,
            ),
          ),
        ),
      ],
    );
  }
}
