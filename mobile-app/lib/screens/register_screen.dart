// lib/screens/register_screen.dart
//
// 📌 AMAÇ:
//   CyberCheck kayıt ekranı.
//   - Ad Soyad, E-posta, Şifre, Şifre Tekrar alanları
//   - Gerçek zamanlı şifre güç göstergesi
//   - Supabase Auth ile kayıt (signUp)
//   - Doğrulama e-postası gönderildi bilgilendirmesi
//   - Kapsamlı form validasyonu

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme.dart';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey         = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();

  // ── Odak ──────────────────────────────────────────────────────────────────
  final _nameFocus     = FocusNode();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  // ── Durum ─────────────────────────────────────────────────────────────────
  bool _isLoading         = false;
  bool _obscurePassword   = true;
  bool _obscureConfirm    = true;
  bool _nameFocused       = false;
  bool _emailFocused      = false;
  bool _passwordFocused   = false;
  bool _confirmFocused    = false;
  bool _acceptedTerms     = false;
  int  _passwordStrength  = 0; // 0-4
  bool _registrationSent  = false;

  // ── Animasyon ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

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
    _nameFocus.addListener(()     => setState(() => _nameFocused     = _nameFocus.hasFocus));
    _emailFocus.addListener(()    => setState(() => _emailFocused    = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _confirmFocus.addListener(()  => setState(() => _confirmFocused  = _confirmFocus.hasFocus));

    // Şifre değişimi — güç hesapla
    _passwordCtrl.addListener(_calculatePasswordStrength);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Şifre gücü hesaplama ─────────────────────────────────────────────────

  void _calculatePasswordStrength() {
    final p = _passwordCtrl.text;
    int score = 0;
    if (p.length >= 8)                            score++;
    if (p.length >= 12)                           score++;
    if (RegExp(r'[A-Z]').hasMatch(p))             score++;
    if (RegExp(r'[0-9]').hasMatch(p))             score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) score++;
    setState(() => _passwordStrength = score.clamp(0, 4));
  }

  // ── Supabase Kayıt ────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      _showError('Devam etmek için kullanım koşullarını kabul etmelisiniz.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        data: {
          'full_name': _nameCtrl.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _registrationSent = true);
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
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                  color:      Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin:   const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _registrationSent
                          ? _buildSuccessCard()
                          : _buildFormCard(),
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
        Text(
          'CyberCheck',
          style: GoogleFonts.inter(
            fontSize:      28,
            fontWeight:    FontWeight.w800,
            color:         AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Yeni hesap oluştur',
          style: GoogleFonts.inter(
            fontSize:   13,
            fontWeight: FontWeight.w400,
            color:      AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Başarı kartı ─────────────────────────────────────────────────────────

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:        AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF22C55E).withValues(alpha: 0.10),
            blurRadius: 32,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color:        const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size:  32,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Doğrulama E-postası Gönderildi!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize:   18,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_emailCtrl.text.trim()} adresine bir doğrulama bağlantısı gönderdik. '
            'E-postanı kontrol ederek hesabını etkinleştir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color:    AppColors.textSecondary,
              height:   1.6,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.go(AppConstants.routeLogin),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Giriş Yap',
                style: GoogleFonts.inter(
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form kartı ───────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.30),
            blurRadius: 32,
            offset:     const Offset(0, 8),
          ),
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
            Text(
              'Hesap Oluştur',
              style: GoogleFonts.inter(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tüm alanları eksiksiz ve doğru doldurun.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
            ),

            const SizedBox(height: 28),

            // ── Ad Soyad ──────────────────────────────────────────────
            _fieldLabel('Ad Soyad'),
            const SizedBox(height: 6),
            _buildNameField(),

            const SizedBox(height: 18),

            // ── E-posta ───────────────────────────────────────────────
            _fieldLabel('E-posta Adresi'),
            const SizedBox(height: 6),
            _buildEmailField(),

            const SizedBox(height: 18),

            // ── Şifre ────────────────────────────────────────────────
            _fieldLabel('Şifre'),
            const SizedBox(height: 6),
            _buildPasswordField(),

            // Şifre güç göstergesi
            if (_passwordCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPasswordStrengthBar(),
            ],

            const SizedBox(height: 18),

            // ── Şifre Tekrar ──────────────────────────────────────────
            _fieldLabel('Şifre Tekrar'),
            const SizedBox(height: 6),
            _buildConfirmPasswordField(),

            const SizedBox(height: 20),

            // ── Koşullar onayı ────────────────────────────────────────
            _buildTermsCheckbox(),

            const SizedBox(height: 24),

            // ── Kayıt butonu ──────────────────────────────────────────
            _buildRegisterButton(),

            const SizedBox(height: 20),

            // ── Giriş yap linki ───────────────────────────────────────
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // ── Alan etiketi ─────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize:      12,
        fontWeight:    FontWeight.w600,
        color:         AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  // ── Input dekorasyon yardımcısı ───────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool focused,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText:  hintText,
      filled:    true,
      fillColor: AppColors.bgBase,
      prefixIcon: Icon(
        prefixIcon,
        size:  18,
        color: focused ? AppColors.accentBlue : AppColors.textMuted,
      ),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ── Ad Soyad alanı ───────────────────────────────────────────────────────

  Widget _buildNameField() {
    return _focusGlow(
      focused: _nameFocused,
      child: TextFormField(
        controller:      _nameCtrl,
        focusNode:       _nameFocus,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDecoration(
          hintText:   'Adınız Soyadınız',
          prefixIcon: Icons.person_outline_rounded,
          focused:    _nameFocused,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Ad Soyad boş bırakılamaz.';
          if (v.trim().length < 3) return 'En az 3 karakter giriniz.';
          if (!v.trim().contains(' ')) return 'Lütfen adınızı ve soyadınızı girin.';
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
      ),
    );
  }

  // ── E-posta alanı ────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return _focusGlow(
      focused: _emailFocused,
      child: TextFormField(
        controller:      _emailCtrl,
        focusNode:       _emailFocus,
        keyboardType:    TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDecoration(
          hintText:   'ornek@email.com',
          prefixIcon: Icons.email_outlined,
          focused:    _emailFocused,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'E-posta boş bırakılamaz.';
          final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
          if (!emailRegex.hasMatch(v.trim())) return 'Geçerli bir e-posta adresi girin.';
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
      ),
    );
  }

  // ── Şifre alanı ──────────────────────────────────────────────────────────

  Widget _buildPasswordField() {
    return _focusGlow(
      focused: _passwordFocused,
      child: TextFormField(
        controller:      _passwordCtrl,
        focusNode:       _passwordFocus,
        obscureText:     _obscurePassword,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDecoration(
          hintText:   '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          focused:    _passwordFocused,
          suffixIcon: _toggleVisibilityIcon(
            obscure:   _obscurePassword,
            onTap:     () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Şifre boş bırakılamaz.';
          if (v.length < 8) return 'Şifre en az 8 karakter olmalıdır.';
          if (!RegExp(r'[A-Z]').hasMatch(v)) return 'En az bir büyük harf kullanın.';
          if (!RegExp(r'[0-9]').hasMatch(v)) return 'En az bir rakam kullanın.';
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmFocus),
      ),
    );
  }

  // ── Şifre güç göstergesi ─────────────────────────────────────────────────

  Widget _buildPasswordStrengthBar() {
    final labels = ['Çok Zayıf', 'Zayıf', 'Orta', 'Güçlü', 'Çok Güçlü'];
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF22C55E),
      const Color(0xFF10B981),
    ];
    final level = _passwordStrength.clamp(0, 4);
    final color = colors[level];
    final label = labels[level];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i <= level
                      ? color
                      : AppColors.borderSubtle.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(
          'Şifre gücü: $label',
          style: GoogleFonts.inter(
            fontSize:   11,
            fontWeight: FontWeight.w500,
            color:      color,
          ),
        ),
      ],
    );
  }

  // ── Şifre tekrar alanı ───────────────────────────────────────────────────

  Widget _buildConfirmPasswordField() {
    return _focusGlow(
      focused: _confirmFocused,
      child: TextFormField(
        controller:      _confirmCtrl,
        focusNode:       _confirmFocus,
        obscureText:     _obscureConfirm,
        textInputAction: TextInputAction.done,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDecoration(
          hintText:   '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          focused:    _confirmFocused,
          suffixIcon: _toggleVisibilityIcon(
            obscure: _obscureConfirm,
            onTap:   () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Şifreyi tekrar girin.';
          if (v != _passwordCtrl.text) return 'Şifreler eşleşmiyor.';
          return null;
        },
        onFieldSubmitted: (_) => _handleRegister(),
      ),
    );
  }

  // ── Koşullar onayı ───────────────────────────────────────────────────────

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22, height: 22,
          child: Checkbox(
            value:          _acceptedTerms,
            onChanged:      (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor:    AppColors.accentBlue,
            checkColor:     Colors.white,
            side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color:    AppColors.textSecondary,
                  height:   1.5,
                ),
                children: [
                  const TextSpan(text: 'Devam ederek '),
                  TextSpan(
                    text:  'Kullanım Koşulları',
                    style: GoogleFonts.inter(
                      fontSize:   12.5,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.accentBlue,
                    ),
                  ),
                  const TextSpan(text: '\'nı ve '),
                  TextSpan(
                    text:  'Gizlilik Politikası',
                    style: GoogleFonts.inter(
                      fontSize:   12.5,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.accentBlue,
                    ),
                  ),
                  const TextSpan(text: '\'nı kabul etmiş olursunuz.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Kayıt butonu ─────────────────────────────────────────────────────────

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
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
                  key:    ValueKey('loading'),
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
                    const Icon(Icons.person_add_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Hesap Oluştur',
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

  // ── Giriş yap linki ──────────────────────────────────────────────────────

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Zaten hesabın var mı?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
        TextButton(
          onPressed: () => context.go(AppConstants.routeLogin),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentBlue,
            padding:         const EdgeInsets.symmetric(horizontal: 6),
            minimumSize:     Size.zero,
            tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Giriş Yap',
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

  // ── Yardımcı: Odak parlaması sarmalayıcısı ───────────────────────────────

  Widget _focusGlow({required bool focused, required Widget child}) {
    return AnimatedContainer(
      duration: AppConstants.animFast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: focused
            ? [
                BoxShadow(
                  color:       AppColors.accentBlue.withValues(alpha: 0.25),
                  blurRadius:  12,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: child,
    );
  }

  // ── Yardımcı: Görünürlük ikonunu aç/kapat ────────────────────────────────

  Widget _toggleVisibilityIcon({
    required bool obscure,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed:    onTap,
      splashRadius: 16,
      icon: AnimatedSwitcher(
        duration: AppConstants.animFast,
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key:   ValueKey(obscure),
          size:  18,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
