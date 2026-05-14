// lib/screens/dashboard_screen.dart
//
// 📌 AMAÇ:
//   CyberCheck SOC Dashboard — kullanıcının tarama istatistiklerini,
//   son aktivitelerini gösterir ve yeni tarama başlatma aksiyonu sunar.
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

// ── Mock veri modeli ──────────────────────────────────────────────────────────

enum ScanType { url, file, image, text }

class _ScanRecord {
  const _ScanRecord({
    required this.target,
    required this.riskScore,
    required this.type,
    required this.date,
  });
  final String   target;
  final int      riskScore;   // 0-100
  final ScanType type;
  final String   date;
}

// Gerçekçi mock veriler — ileride Supabase sorgusuyla değişecek
const List<_ScanRecord> _mockRecords = [
  _ScanRecord(
    target:    'malicious-payload.pdf',
    riskScore: 91,
    type:      ScanType.file,
    date:      '13 May, 22:48',
  ),
  _ScanRecord(
    target:    'phishing-site.ru/login',
    riskScore: 74,
    type:      ScanType.url,
    date:      '13 May, 21:15',
  ),
  _ScanRecord(
    target:    'safe-website.com',
    riskScore: 12,
    type:      ScanType.url,
    date:      '13 May, 18:30',
  ),
  _ScanRecord(
    target:    'suspicious-image.png',
    riskScore: 55,
    type:      ScanType.image,
    date:      '12 May, 14:10',
  ),
  _ScanRecord(
    target:    'invoice_march.docx',
    riskScore: 8,
    type:      ScanType.file,
    date:      '12 May, 09:22',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ── Animasyon ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  // ── Supabase kullanıcı bilgisi ────────────────────────────────────────────
  String get _userEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? 'Analist';

  // Kullanıcı adını e-postadan çıkar: "ali@mail.com" → "Ali"
  String get _displayName {
    final email = _userEmail;
    final local = email.split('@').first;
    if (local.isEmpty) return 'Analist';
    return local[0].toUpperCase() + local.substring(1);
  }

  // ── İstatistik hesaplama ─────────────────────────────────────────────────
  int get _totalScans => _mockRecords.length;
  int get _threatCount =>
      _mockRecords.where((r) => r.riskScore >= 40).length;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // signOut hatası bile olsa login'e yönlendir
    }
    if (mounted) context.go(AppConstants.routeLogin);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          color:           AppColors.accentBlue,
          backgroundColor: AppColors.bgElevated,
          onRefresh: () async {
            // TODO: Supabase'den gerçek veri çek
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeHeader(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildScanCTA(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Aktivite listesi — sliver içinde
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ActivityCard(
                      record: _mockRecords[index],
                      index:  index,
                    ),
                    childCount: _mockRecords.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:  AppColors.bgSurface,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:        AppColors.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.security_rounded,
              size:  16,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'CyberCheck',
            style: GoogleFonts.inter(
              fontSize:   17,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        // Bildirim ikonu (placeholder)
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textSecondary,
            size:  22,
          ),
          onPressed: () {},
          tooltip: 'Bildirimler',
        ),
        // Logout
        IconButton(
          icon: const Icon(
            Icons.logout_rounded,
            color: AppColors.textSecondary,
            size:  22,
          ),
          onPressed: _handleLogout,
          tooltip: 'Çıkış Yap',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Karşılama başlığı ─────────────────────────────────────────────────────

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarih etiketi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        AppColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentBlue.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SİSTEM AKTİF',
                style: GoogleFonts.jetBrainsMono(
                  fontSize:   10,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.accentBlue,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Hoş Geldiniz,',
          style: GoogleFonts.inter(
            fontSize:   14,
            fontWeight: FontWeight.w400,
            color:      AppColors.textSecondary,
          ),
        ),
        Text(
          _displayName,
          style: GoogleFonts.inter(
            fontSize:   28,
            fontWeight: FontWeight.w800,
            color:      AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          _userEmail,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color:    AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── İstatistik kartları ───────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label:     'Toplam Tarama',
            value:     '$_totalScans',
            icon:      Icons.radar_rounded,
            iconColor: AppColors.accentBlue,
            glowColor: AppColors.accentBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label:     'Tespit Edilen Tehdit',
            value:     '$_threatCount',
            icon:      Icons.gpp_bad_rounded,
            iconColor: AppColors.danger,
            glowColor: AppColors.danger,
          ),
        ),
      ],
    );
  }

  // ── CTA — Yeni Tarama Başlat ──────────────────────────────────────────────

  Widget _buildScanCTA() {
    return GestureDetector(
      onTap: () => context.go(AppConstants.routeScan),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentBlue,
              AppColors.accentIndigo,
            ],
            begin: Alignment.centerLeft,
            end:   Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:       AppColors.accentBlue.withValues(alpha: 0.35),
              blurRadius:  24,
              offset:      const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animasyonlu radar ikonu arka planı
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.radar_rounded,
                size:  28,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Tarama Başlat',
                    style: GoogleFonts.inter(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'URL, Dosya, Görsel veya Metin analizi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:    Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size:  14,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // ── "Son Aktiviteler" başlığı ─────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Son Aktiviteler',
          style: GoogleFonts.inter(
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      AppColors.textPrimary,
          ),
        ),
        Text(
          '${_mockRecords.length} kayıt',
          style: GoogleFonts.inter(
            fontSize: 12,
            color:    AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.glowColor,
  });

  final String    label;
  final String    value;
  final IconData  icon;
  final Color     iconColor;
  final Color     glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  const Color(0xFF0F1629),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color:       glowColor.withValues(alpha: 0.08),
            blurRadius:  20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),

          const SizedBox(height: 14),

          // Sayı
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize:   32,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 2),

          // Etiket
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize:   11,
              fontWeight: FontWeight.w500,
              color:      AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aktivite Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.record, required this.index});

  final _ScanRecord record;
  final int         index;

  // ── Risk rengi ──────────────────────────────────────────────────────────
  Color get _riskColor {
    if (record.riskScore >= 70) return AppColors.danger;
    if (record.riskScore >= 40) return AppColors.warning;
    return AppColors.success;
  }

  String get _riskLabel {
    if (record.riskScore >= 70) return 'YÜKSEK';
    if (record.riskScore >= 40) return 'ORTA';
    return 'DÜŞÜK';
  }

  // ── Tür ikonu ────────────────────────────────────────────────────────────
  IconData get _typeIcon {
    switch (record.type) {
      case ScanType.url:   return Icons.link_rounded;
      case ScanType.file:  return Icons.insert_drive_file_outlined;
      case ScanType.image: return Icons.image_outlined;
      case ScanType.text:  return Icons.text_snippet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _riskColor.withValues(alpha: index == 0 ? 0.30 : 0.10),
        ),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _riskColor.withValues(alpha: 0.06),
          onTap: () {
            // TODO: context.go('/report/${record.id}')
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Tür ikonu
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Icon(
                    _typeIcon,
                    size:  18,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(width: 12),

                // Hedef + Tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.target,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize:  12,
                          fontWeight: FontWeight.w500,
                          color:      AppColors.textPrimary,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        record.date,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color:    AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Risk rozeti
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Yüzde gösterge
                    Text(
                      '%${record.riskScore}',
                      style: GoogleFonts.inter(
                        fontSize:   15,
                        fontWeight: FontWeight.w800,
                        color:      _riskColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Etiket rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:        _riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _riskColor.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        _riskLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                          color:      _riskColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
