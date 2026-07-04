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
import 'result_screen.dart';

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
    date:      '10 Dk Önce',
  ),
  _ScanRecord(
    target:    'phishing-site.ru/login',
    riskScore: 74,
    type:      ScanType.url,
    date:      '45 Dk Önce',
  ),
  _ScanRecord(
    target:    'safe-website.com',
    riskScore: 12,
    type:      ScanType.url,
    date:      '1 Saat Önce',
  ),
  _ScanRecord(
    target:    'suspicious-image.png',
    riskScore: 55,
    type:      ScanType.image,
    date:      '3 Saat Önce',
  ),
  _ScanRecord(
    target:    'invoice_march.docx',
    riskScore: 8,
    type:      ScanType.file,
    date:      '5 Saat Önce',
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
                      _buildThreatRatioCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 16),
                      _buildHistoryCTA(),
                      const SizedBox(height: 16),
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
        // Geçmiş Taramalar
        IconButton(
          icon: const Icon(
            Icons.history_rounded,
            color: AppColors.textSecondary,
            size:  22,
          ),
          onPressed: () => context.go('/history'),
          tooltip: 'Geçmiş Taramalar',
        ),
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

  // ── Tehdit Oranı Grafiği (Dairesel) ───────────────────────────────────────

  Widget _buildThreatRatioCard() {
    final double threatRatio = _totalScans == 0 ? 0 : _threatCount / _totalScans;
    final int ratioPercent = (threatRatio * 100).round();

    Color gaugeColor;
    if (ratioPercent >= 50) {
      gaugeColor = AppColors.danger;
    } else if (ratioPercent >= 20) {
      gaugeColor = AppColors.warning;
    } else {
      gaugeColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gaugeColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dairesel Grafik
          SizedBox(
            width: 72, height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  color: gaugeColor.withValues(alpha: 0.1),
                ),
                CircularProgressIndicator(
                  value: threatRatio,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  color: gaugeColor,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '%$ratioPercent',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: gaugeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Metinler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genel Tehdit Oranı',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Taranan $_totalScans dosyadan $_threatCount tanesinde yüksek risk tespit edildi.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            label:     'Tespit Edilen',
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

  // ── Geçmiş Taramalar CTA ──────────────────────────────────────────────────

  Widget _buildHistoryCTA() {
    return GestureDetector(
      onTap: () => context.go('/history'),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:        AppColors.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color:      AppColors.accentCyan.withValues(alpha: 0.06),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color:        AppColors.accentCyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.history_rounded,
                size:  22,
                color: AppColors.accentCyan,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geçmiş Taramalar',
                    style: GoogleFonts.inter(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Raporlarınızı görün ve PDF olarak paylaşın',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color:    AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size:  13,
              color: AppColors.accentCyan,
            ),
          ],
        ),
      ),
    );
  }

  // ── "Son Aktiviteler" başlığı ─────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Aktiviteler',
          style: GoogleFonts.inter(
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
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
              'Canlı Akış',
              style: GoogleFonts.inter(
                fontSize: 12,
                color:    AppColors.textMuted,
              ),
            ),
          ],
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
    if (record.riskScore >= 70) return 'Yüksek Risk';
    if (record.riskScore >= 40) return 'Orta Risk';
    return 'Temiz';
  }

  // ── Risk ikonu ────────────────────────────────────────────────────────────
  IconData get _riskIcon {
    if (record.riskScore >= 70) return Icons.gpp_bad_rounded;
    if (record.riskScore >= 40) return Icons.warning_amber_rounded;
    return Icons.gpp_good_rounded;
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
            // Gelişmiş AI Rapor Ekranına Yönlendir (ResultScreen)
            final verdict = record.riskScore >= 70 ? 'malicious' : record.riskScore >= 40 ? 'suspicious' : 'clean';
            
            // Web'deki ile aynı akordeon yapısını test etmek için mock AI raporu
            final mockAiReport = '''
Bu hedefte tespit edilen risk profiline göre oluşturulmuş yapay zeka analizidir.

## Tespit Edilen Taktikler
- ${record.riskScore >= 70 ? 'Kimlik Avı' : 'Şüpheli İçerik'}
- Sosyal Mühendislik
- ${record.riskScore >= 40 ? 'Gizli Yönlendirme' : 'Zararsız Dosya'}

## Detaylı Analiz
Taranan hedef (`${record.target}`) üzerinde yapılan statik ve dinamik analizlerde bazı anormal desenler görülmüştür. Oltalama kampanyalarında sık kullanılan bazı tekniklerin izleri bulunmaktadır. Özellikle alan adının yaşı ve SSL sertifikasının durumu risk seviyesini artırmaktadır.

## Kullanıcıya Tavsiye
Lütfen bu hedefe herhangi bir kişisel bilgi girmeyin. Kaynağın güvenilirliğini alternatif kanallardan (örn: resmi web sitesine kendiniz giderek) teyit edin.
            ''';

            final data = ScanResultData(
              riskScore: record.riskScore,
              verdict: verdict,
              aiReport: mockAiReport,
              threats: [], // Otomatik parse edilecek
              scanType: record.type.name,
              inputLabel: record.target,
            );

            context.push('/result', extra: data);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Sol Kısım: Risk İkonu
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        _riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    _riskIcon,
                    size:  20,
                    color: _riskColor,
                  ),
                ),

                const SizedBox(width: 12),

                // Orta Kısım: Hedef + Risk Seviyesi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.target,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize:  13,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textPrimary,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _riskLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:    _riskColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Sağ Kısım: Zaman Damgası
                Text(
                  record.date,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color:    AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
