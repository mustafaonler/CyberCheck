// lib/screens/history_screen.dart
//
// 📌 AMAÇ: Kullanıcının geçmiş taramalarını Supabase'den çeker ve listeler.
//   • Supabase 'scans' tablosundan kullanıcıya ait kayıtlar çekilir
//   • ListView.builder ile kart formatında gösterilir
//   • Her kart: Hedef, tarih, risk rozeti + PDF paylaş butonu
//   • PDF paylaşımı için PdfGenerator motoru tetiklenir

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme.dart';
import '../utils/pdf_generator.dart';
import 'result_screen.dart';

// ── Supabase Scan Modeli ──────────────────────────────────────────────────────

class _HistoryScan {
  final String  id;
  final String  target;      // file_name veya analysis_id
  final String  scanType;    // url | file | text | image
  final String  verdict;     // clean | suspicious | malicious
  final int     riskScore;
  final String  aiReport;
  final String  createdAt;

  const _HistoryScan({
    required this.id,
    required this.target,
    required this.scanType,
    required this.verdict,
    required this.riskScore,
    required this.aiReport,
    required this.createdAt,
  });

  factory _HistoryScan.fromJson(Map<String, dynamic> j) {
    // risk_score: Supabase'deki alan ya int ya da stats JSON'ında olabilir
    int score = 0;
    if (j['risk_score'] is int) {
      score = j['risk_score'] as int;
    } else if (j['stats'] is Map) {
      final stats = j['stats'] as Map<String, dynamic>;
      score = (stats['risk_score'] as num?)?.toInt() ?? 0;
    }

    // verdict → risk_score tahmini
    final verd = j['verdict'] as String? ?? 'unknown';
    if (score == 0) {
      if (verd == 'malicious') score = 80;
      else if (verd == 'suspicious') score = 50;
      else if (verd == 'clean') score = 10;
    }

    // AI raporu: stats.report_content veya ai_report
    String report = '';
    if (j['ai_report'] is String) {
      report = j['ai_report'] as String;
    } else if (j['stats'] is Map) {
      final s = j['stats'] as Map<String, dynamic>;
      report = s['report_content'] as String? ?? '';
    }

    // Tarih formatı
    String dateStr = '';
    try {
      final dt = DateTime.parse(j['created_at'] as String).toLocal();
      dateStr =
          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      dateStr = j['created_at']?.toString() ?? '';
    }

    return _HistoryScan(
      id:        j['id']?.toString() ?? '',
      target:    j['file_name'] as String? ?? j['analysis_id'] as String? ?? 'Bilinmiyor',
      scanType:  j['type'] as String? ?? 'unknown',
      verdict:   verd,
      riskScore: score,
      aiReport:  report,
      createdAt: dateStr,
    );
  }
}

// ── Ana Ekran ─────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_HistoryScan> _scans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Veri Yükleme ─────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Giriş yapılmamış.');

      final response = await Supabase.instance.client
          .from('scans')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> rows = response as List<dynamic>;
      setState(() {
        _scans     = rows.map((r) => _HistoryScan.fromJson(r as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error     = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── PDF Paylaşımı ─────────────────────────────────────────────────────────

  Future<void> _sharePdf(_HistoryScan scan) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔄 PDF hazırlanıyor...',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppColors.bgElevated,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 2),
          shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );

      final resultData = ScanResultData.fromJson(
        {
          'risk_score': scan.riskScore,
          'verdict':    scan.verdict,
          'ai_report':  scan.aiReport,
        },
        scanType:   scan.scanType,
        inputLabel: scan.target,
      );

      final bytes = await PdfGenerator.generate(resultData);
      await Printing.sharePdf(
        bytes:    bytes,
        filename: 'CyberCheck_Rapor_${scan.id.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF oluşturulurken hata: $e',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppColors.danger,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor:  AppColors.bgSurface,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () {
          if (context.canPop()) context.pop();
          else context.go('/dashboard');
        },
      ),
      title: Text(
        'Geçmiş Taramalar',
        style: GoogleFonts.inter(
          fontSize:   17,
          fontWeight: FontWeight.w600,
          color:      AppColors.textPrimary,
        ),
      ),
      actions: [
        // Yenile
        IconButton(
          icon:    const Icon(Icons.refresh_rounded, size: 22),
          color:   AppColors.textSecondary,
          onPressed: _loadHistory,
          tooltip: 'Yenile',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.borderSubtle),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_scans.isEmpty) return _buildEmptyState();
    return _buildList();
  }

  // ── Yükleme ───────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
              strokeWidth:  2.5,
              valueColor:   AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tarama geçmişi yükleniyor...',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13, color: AppColors.accentCyan,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hata ─────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color:        AppColors.danger.withValues(alpha: 0.1),
                shape:        BoxShape.circle,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'Veriler yüklenemedi',
              style: GoogleFonts.inter(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon:  const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Boş ───────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color:        AppColors.accentBlue.withValues(alpha: 0.08),
              shape:        BoxShape.circle,
              border: Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.history_rounded,
                color: AppColors.accentBlue, size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz tarama yok',
            style: GoogleFonts.inter(
              fontSize:   16,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk analizini başlatmak için\nTarama ekranına git.',
            style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/scan'),
            icon:  const Icon(Icons.radar_rounded, size: 18),
            label: const Text('Yeni Tarama Başlat'),
          ),
        ],
      ),
    );
  }

  // ── Liste ─────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return RefreshIndicator(
      color:           AppColors.accentBlue,
      backgroundColor: AppColors.bgElevated,
      onRefresh:       _loadHistory,
      child: ListView.builder(
        padding:     const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount:   _scans.length,
        itemBuilder: (context, i) => _ScanHistoryCard(
          scan:    _scans[i],
          onShare: () => _sharePdf(_scans[i]),
        ),
      ),
    );
  }
}

// ── Scan History Card ─────────────────────────────────────────────────────────

class _ScanHistoryCard extends StatelessWidget {
  const _ScanHistoryCard({required this.scan, required this.onShare});

  final _HistoryScan   scan;
  final VoidCallback   onShare;

  // Risk rengi
  Color get _riskColor {
    if (scan.riskScore >= 70) return AppColors.danger;
    if (scan.riskScore >= 40) return AppColors.warning;
    return AppColors.success;
  }

  String get _riskLabel {
    if (scan.riskScore >= 70) return 'YÜKSEK';
    if (scan.riskScore >= 40) return 'ORTA';
    return 'DÜŞÜK';
  }

  // Tür ikonu
  IconData get _typeIcon {
    switch (scan.scanType) {
      case 'url':   return Icons.link_rounded;
      case 'file':  return Icons.insert_drive_file_outlined;
      case 'image': return Icons.image_outlined;
      case 'text':  return Icons.text_snippet_outlined;
      default:      return Icons.radar_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _riskColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color:      _riskColor.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor:  _riskColor.withValues(alpha: 0.05),
          onTap:        () {}, // İleride detail sayfasına yönlendirilebilir
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Tür ikonu
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color:        AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Icon(_typeIcon, size: 20, color: AppColors.textSecondary),
                ),

                const SizedBox(width: 12),

                // Hedef + Tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.target,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize:  11,
                          fontWeight: FontWeight.w500,
                          color:      AppColors.textPrimary,
                        ),
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            scan.createdAt,
                            style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Risk rozeti
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '%${scan.riskScore}',
                      style: GoogleFonts.inter(
                        fontSize:   14,
                        fontWeight: FontWeight.w800,
                        color:      _riskColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        _riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _riskColor.withValues(alpha: 0.30)),
                      ),
                      child: Text(
                        _riskLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize:  8,
                          fontWeight: FontWeight.w700,
                          color:      _riskColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 10),

                // PDF Paylaş butonu
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        AppColors.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.accentBlue.withValues(alpha: 0.25)),
                  ),
                  child: IconButton(
                    padding:  EdgeInsets.zero,
                    icon:     const Icon(
                      Icons.picture_as_pdf_rounded,
                      size:  18,
                      color: AppColors.accentBlue,
                    ),
                    tooltip:  'PDF Paylaş',
                    onPressed: onShare,
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
