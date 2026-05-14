// lib/screens/scan_screen.dart
//
// 📌 AMAÇ: Yeni Tehdit Analizi ekranı.
//   • Sekme 1 — URL        : tek satırlık link TextField
//   • Sekme 2 — Metin      : çok satırlı sosyal-mühendislik TextField
//   • Sekme 3 — Dosya/Görsel: dashed upload kutusu + file_picker
//   • Yükleme: siber mesajları sırayla gösteren animasyonlu kart
//   • Sonuç : mock "%85 - Kritik Tehdit" risk kartı

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

// ─── Sabitler ────────────────────────────────────────────────────────────────

const _kBgBase    = AppColors.bgBase;
const _kBgSurface = AppColors.bgSurface;
const _kBlue      = AppColors.accentBlue;
const _kCyan      = AppColors.accentCyan;
const _kDanger    = AppColors.danger;
const _kBorderSubtle = AppColors.borderSubtle;

const List<String> _kCyberMessages = [
  '🔍  Bağlam analiz ediliyor...',
  '🤖  Yapay Zeka modeli çalıştırılıyor...',
  '🌐  VirusTotal veritabanı sorgulanıyor...',
  '🛡️  Tehdit imzaları karşılaştırılıyor...',
  '📊  Risk skoru hesaplanıyor...',
];

// ─── Ana Ekran ────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Sekme 1 — URL
  final TextEditingController _urlCtrl  = TextEditingController();

  // Sekme 2 — Metin
  final TextEditingController _textCtrl = TextEditingController();

  // Sekme 3 — Dosya
  String? _pickedFileName;

  // Durum
  bool _isLoading  = false;
  bool _showResult = false;

  // Yükleme animasyonu
  int    _msgIndex = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _urlCtrl.dispose();
    _textCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // ── İş Mantığı ─────────────────────────────────────────────────────────────

  Future<void> _startAnalysis() async {
    setState(() {
      _isLoading   = true;
      _showResult  = false;
      _msgIndex    = 0;
    });

    // Siber mesajları döndür
    _msgTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (_msgIndex < _kCyberMessages.length - 1) {
        setState(() => _msgIndex++);
      } else {
        t.cancel();
      }
    });

    // Mock bekleme süresi
    await Future.delayed(const Duration(seconds: 3));
    _msgTimer?.cancel();

    setState(() {
      _isLoading  = false;
      _showResult = true;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFileName = result.files.first.name);
    }
  }

  void _resetScan() => setState(() {
    _showResult     = false;
    _isLoading      = false;
    _pickedFileName = null;
    _urlCtrl.clear();
    _textCtrl.clear();
  });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgBase,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildUrlTab(),
                _buildTextTab(),
                _buildFileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _kBgSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      title: Text(
        'Yeni Tehdit Analizi',
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: _kBorderSubtle,
        ),
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _kBgSurface,
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: _kBlue,
        indicatorWeight: 2,
        labelColor: _kBlue,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
        tabs: const [
          Tab(text: 'URL'),
          Tab(text: 'Metin'),
          Tab(text: 'Dosya / Görsel'),
        ],
      ),
    );
  }

  // ── Sekme 1: URL ──────────────────────────────────────────────────────────

  Widget _buildUrlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _SectionLabel(text: 'Şüpheli Bağlantı (URL)'),
          const SizedBox(height: 10),
          _buildUrlField(),
          const SizedBox(height: 20),
          if (_isLoading) _buildLoadingCard(),
          if (_showResult) _buildResultCard(),
          if (!_isLoading && !_showResult) _buildAnalyzeButton(),
          if (_showResult) ...[
            const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ],
      ),
    );
  }

  // ── Sekme 2: Metin ────────────────────────────────────────────────────────

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _SectionLabel(text: 'Şüpheli Metin / Sosyal Mühendislik Mesajı'),
          const SizedBox(height: 10),
          _buildTextField(),
          const SizedBox(height: 20),
          if (_isLoading) _buildLoadingCard(),
          if (_showResult) _buildResultCard(),
          if (!_isLoading && !_showResult) _buildAnalyzeButton(),
          if (_showResult) ...[
            const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ],
      ),
    );
  }

  // Tek satırlık URL alanı
  Widget _buildUrlField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _urlCtrl,
        maxLines: 1,
        keyboardType: TextInputType.url,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.link_rounded, color: _kBlue, size: 20),
          hintText: 'https://suspicious-site.xyz/offer',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.bgElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorderSubtle, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _kBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  // Çok satırlı metin alanı
  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _textCtrl,
        maxLines: 6,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText:
              'Tebrikler! Ödülünüzü almak için aşağıdaki linke tıklayın...\n\nŞüpheli e-posta, SMS veya mesajı buraya yapıştırın.',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.6,
          ),
          filled: true,
          fillColor: AppColors.bgElevated,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorderSubtle, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _kBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Sekme 2: Dosya / Görsel ───────────────────────────────────────────────

  Widget _buildFileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _SectionLabel(text: 'Şüpheli Dosya veya Görsel'),
          const SizedBox(height: 10),
          _buildDashedUploadBox(),
          if (_pickedFileName != null) ...[
            const SizedBox(height: 12),
            _PickedFileChip(
              name: _pickedFileName!,
              onRemove: () => setState(() => _pickedFileName = null),
            ),
          ],
          const SizedBox(height: 20),
          if (_isLoading) _buildLoadingCard(),
          if (_showResult) _buildResultCard(),
          if (!_isLoading && !_showResult && _pickedFileName != null)
            _buildAnalyzeButton(),
          if (_showResult) ...[
            const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildDashedUploadBox() {
    return GestureDetector(
      onTap: _pickFile,
      child: _DashedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBlue.withOpacity(0.2)),
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 30,
                color: _kBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Şüpheli dosyayı seçmek için dokunun',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'PDF, EXE, APK, PNG, JPG desteklenir',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Yükleme Kartı ─────────────────────────────────────────────────────────

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBlue.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          // Dönen ikon
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_kCyan),
            ),
          ),
          const SizedBox(height: 20),

          // Siber mesaj
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _kCyberMessages[_msgIndex],
              key: ValueKey(_msgIndex),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: _kCyan,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // İlerleme çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: _kBlue.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
              minHeight: 3,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Lütfen bekleyin — analiz sürüyor',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sonuç Kartı ───────────────────────────────────────────────────────────

  Widget _buildResultCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDanger.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: _kDanger.withOpacity(0.12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık bandı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _kDanger.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: _kDanger.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: _kDanger, size: 20),
                const SizedBox(width: 10),
                Text(
                  'KRİTİK TEHDİT TESPİT EDİLDİ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kDanger,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk skoru
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '85',
                      style: GoogleFonts.inter(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: _kDanger,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        '/ 100',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kDanger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _kDanger.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Kritik',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kDanger,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  'Risk Skoru',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 16),

                // Risk çubuğu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.85,
                    minHeight: 8,
                    backgroundColor: _kDanger.withOpacity(0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_kDanger),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: _kBorderSubtle),
                const SizedBox(height: 16),

                // Detay satırları
                _ResultDetailRow(
                  icon: Icons.bug_report_outlined,
                  label: 'Tespit',
                  value: 'Phishing / Malware',
                  valueColor: _kDanger,
                ),
                const SizedBox(height: 10),
                _ResultDetailRow(
                  icon: Icons.dns_outlined,
                  label: 'Kaynak',
                  value: 'VirusTotal — 34/72 motor',
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(height: 10),
                _ResultDetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Analiz Süresi',
                  value: '~3.1 saniye',
                  valueColor: AppColors.textSecondary,
                ),

                const SizedBox(height: 20),

                // Öneri kutusu
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bu içerikle etkileşime geçmeyin. Bağlantıyı paylaşmayın ve herhangi bir dosyayı indirmeyin.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.amber.shade200,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Butonlar ──────────────────────────────────────────────────────────────

  Widget _buildAnalyzeButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _startAnalysis,
        icon: const Icon(Icons.radar_rounded, size: 22),
        label: Text(
          'Analizi Başlat',
          style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          shadowColor: _kBlue.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetScan,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: Text('Yeni Analiz', style: GoogleFonts.inter(fontSize: 14)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: _kBorderSubtle),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ─── Yardımcı Widget'lar ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ResultDetailRow extends StatelessWidget {
  const _ResultDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PickedFileChip extends StatelessWidget {
  const _PickedFileChip({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.accentBlue.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 18, color: AppColors.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed Border Box ────────────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: AppColors.accentBlue.withOpacity(0.35),
        strokeWidth: 1.5,
        gap: 6,
        dashLength: 8,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dashLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength;
}
