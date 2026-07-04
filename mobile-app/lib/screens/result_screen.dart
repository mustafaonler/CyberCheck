// lib/screens/result_screen.dart
//
// ğŸ“Œ AMAÃ‡: Backend'den dÃ¶nen tarama sonucunu gÃ¶rselleÅŸtirir.
//   â€¢ Ãœst kÄ±sÄ±m  â†’ Devasa neon dairesel risk skoru gauge + hedef hap kartÄ±
//   â€¢ Orta kÄ±sÄ±m â†’ Tespit edilen taktikler (ikonlu, renkli Chip rozetleri)
//   â€¢ Alt kÄ±sÄ±m  â†’ ExpansionTile akordeon: DetaylÄ± Analiz + Tavsiye

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../utils/theme.dart';
import '../utils/pdf_generator.dart';

// â”€â”€â”€ Veri Modeli â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ScanResultData {
  final int riskScore;        // 0â€“100
  final String verdict;       // 'clean' | 'suspicious' | 'malicious' | 'unknown'
  final String aiReport;      // Gemini raporu (ham metin)
  final List<String> threats; // Tespit edilen tehdit tÃ¼rleri
  final String scanType;      // 'url' | 'text' | 'file' | 'image'
  final String? inputLabel;   // Taranan URL / metin Ã¶zeti

  const ScanResultData({
    required this.riskScore,
    required this.verdict,
    required this.aiReport,
    required this.threats,
    required this.scanType,
    this.inputLabel,
  });

  /// Backend JSON'ından oluştur
  factory ScanResultData.fromJson(Map<String, dynamic> json,
      {String? scanType, String? inputLabel}) {
    // AI Raporu
    String report = json['ai_report'] as String? ?? json['report'] as String? ?? '';
    if (report.isEmpty && json['stats'] is Map) {
      report = (json['stats'] as Map<String, dynamic>)['report_content'] as String? ?? '';
    }

    // ── Risk score & verdict — öncelik sırası: ────────────────────────────────
    // 1) Backend server-side parse sonucu (risk_score + verdict alanları)
    // 2) Gemini metni parse (Flutter tarafı)
    // 3) VirusTotal istatistikleri
    int score = 0;
    String verd = 'unknown';

    // 1) Backend bize hazır risk_score ve verdict döndürdüyse direkt kullan
    final backendScore   = (json['risk_score']  as num?)?.toInt();
    final backendVerdict = json['verdict']       as String?;
    final backendLevel   = json['risk_level']    as String?;

    // Debug: backend'den ne geldiğini logla
    // ignore: avoid_print
    print('[ScanResultData] backend risk_score=$backendScore verdict=$backendVerdict risk_level=$backendLevel');

    if (backendScore != null && backendScore > 0) {
      score = backendScore;
      verd  = backendVerdict ?? 'suspicious';
    } else {
      // 2) Gemini raporu varsa Flutter-side parse
      final bool isGeminiReport = report.isNotEmpty && (
        report.contains('Risk Seviyesi') ||
        report.contains('Tespit Edilen Taktikler') ||
        report.contains('Detaylı Analiz') ||
        json['analysisId'] == null
      );

      if (isGeminiReport) {
        final parsed = _parseGeminiRisk(report);
        score = parsed.$1;
        verd  = parsed.$2;
      } else if (json['stats'] is Map) {
        // 3) VirusTotal istatistikleri
        final stats = json['stats'] as Map<String, dynamic>;
        final malicious  = (stats['malicious']  as num?)?.toInt() ?? 0;
        final suspicious = (stats['suspicious'] as num?)?.toInt() ?? 0;
        if (malicious  > 0) { score = 85; verd = 'malicious'; }
        else if (suspicious > 0) { score = 50; verd = 'suspicious'; }
        else { score = 10; verd = json['verdict'] as String? ?? 'clean'; }
      }
    }

    // Tehditleri çıkar: JSON'da olabilir veya rapor metninden parse et
    List<String> threats = [];
    if (json['threats'] is List) {
      threats = (json['threats'] as List).map((e) => e.toString()).toList();
    } else {
      threats = _parseThreatsFromReport(report, verd);
    }

    return ScanResultData(
      riskScore:  score,
      verdict:    verd,
      aiReport:   report,
      threats:    threats,
      scanType:   scanType ?? (json['scan_type'] as String? ?? 'unknown'),
      inputLabel: inputLabel,
    );
  }

  /// Gemini rapor metninden risk skoru ve verdict üretir.
  /// Önce "Risk Seviyesi: X" formatını arar (yeni prompt formatı),
  /// bulamazsa tüm metinde anahtar kelime taraması yapar.
  static (int, String) _parseGeminiRisk(String report) {
    final lower = report.toLowerCase();

    // ── 1) Yeni prompt formatı: "Risk Seviyesi: Kritik/Yüksek/..." ──────────
    // "1. Risk Seviyesi: Yüksek" veya "Risk Seviyesi: **Kritik**" gibi satırları yakala
    final riskLineRe = RegExp(
      r'risk\s+seviyesi\s*[:\-]?\s*\*{0,2}(kritik|yüksek|orta|düşük|temiz|güvenli)\*{0,2}',
      caseSensitive: false,
    );
    final lineMatch = riskLineRe.firstMatch(lower);
    if (lineMatch != null) {
      final level = lineMatch.group(1)!.toLowerCase().trim();
      if (level == 'kritik')               return (92, 'malicious');
      if (level == 'yüksek')               return (78, 'malicious');
      if (level == 'orta')                 return (50, 'suspicious');
      if (level == 'düşük')                return (22, 'clean');
      if (level == 'temiz' || level == 'güvenli') return (5, 'clean');
    }

    // ── 2) Eski / genel format: tüm metinde anahtar kelime tara ─────────────
    // Phishing belirtisi varken "düşük" kelimesi geçiyorsa skoru düşürme!
    final hasPhishingSignals = lower.contains('phishing') ||
        lower.contains('kimlik avı') ||
        lower.contains('sahte') ||
        lower.contains('aciliyet') ||
        lower.contains('kişisel bilgi') ||
        lower.contains('şüpheli') ||
        lower.contains('oltalama') ||
        lower.contains('manipülasyon') ||
        lower.contains('zararlı');

    if (lower.contains('kritik')) return (92, 'malicious');
    if (lower.contains('yüksek')) return (78, 'malicious');
    // "orta" veya "şüpheli" geçiyorsa, ya da phishing sinyalleri varken "düşük" diyorsa
    if (lower.contains('orta') || lower.contains('şüpheli')) return (50, 'suspicious');
    if (hasPhishingSignals && lower.contains('düşük')) return (70, 'malicious');
    if (lower.contains('düşük')) return (22, 'clean');
    if (lower.contains('temiz') || lower.contains('güvenli')) return (5, 'clean');

    // Hiçbir seviye bulunamazsa — bilinmeyen içerik için temkinli davran
    return (40, 'suspicious');
  }

  /// Rapor metninden tehdit anahtar kelimelerini ve Gemini'nin
  /// "Tespit Edilen Taktikler" bölümündeki maddeleri çıkarır.
  static List<String> _parseThreatsFromReport(String report, String verdict) {
    final lower = report.toLowerCase();
    final found = <String>{};

    // â”€â”€ 1) Anahtar kelime taramasÄ± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final Map<String, String> keywords = {
      'phishing':           'Kimlik Avı',
      'kimlik avı':         'Kimlik Avı',
      'malware':            'Kötü Amaçlı Yazılım',
      'ransomware':         'Fidye Yazılımı',
      'trojan':             'Truva Atı',
      'scam':               'Dolandırıcılık',
      'social engineering': 'Sosyal Mühendislik',
      'sosyal mühendislik': 'Sosyal Mühendislik',
      'spam':               'Spam / İstenmeyen',
      'virüs':              'Virüs',
      'virus':              'Virüs',
      'backdoor':           'Arka Kapı',
      'exploit':            'Güvenlik Açığı',
      'worm':               'Solucan (Worm)',
      'spyware':            'Casus Yazılım',
      'adware':             'Reklam Yazılımı',
      'aciliyet':           'Aciliyet Hissi',
      'urgency':            'Aciliyet Hissi',
      'sahte':              'Sahte İçerik',
      'otorite':            'Otorite Taklidi',
      'impersonation':      'Kimlik Taklidi',
      'credential':         'Kimlik Bilgisi Hırsızlığı',
      'parola':             'Parola Çalma',
      'şifre':              'Parola Çalma',
    };

    for (final entry in keywords.entries) {
      if (lower.contains(entry.key)) {
        found.add(entry.value);
      }
    }

    // â”€â”€ 2) Gemini "Tespit Edilen Taktikler" bÃ¶lÃ¼mÃ¼nden madde Ã§Ä±kar â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final RegExp sectionRe = RegExp(
      r'(?:tespit edilen taktikler|detected tactics)[^\n]*\n([\s\S]*?)(?:\n\s*\n|\n\s*\d\.|\n##|$)',
      caseSensitive: false,
    );
    final sectionMatch = sectionRe.firstMatch(report);
    if (sectionMatch != null) {
      final body = sectionMatch.group(1) ?? '';
      final lines = body.split('\n');
      for (final line in lines) {
        final trimmed = line.replaceAll(RegExp(r'^[\s\-â€¢\*\d\.]+'), '').trim();
        // BaÅŸlÄ±k ve (**...**) formatÄ±nÄ± temizle
        final clean = trimmed.replaceAll(RegExp(r'\*+'), '').trim();
        if (clean.length > 3 && clean.length < 60) {
          found.add(clean);
        }
      }
    }

    if (found.isEmpty) {
      if (verdict == 'malicious') found.add('Zararlı İçerik');
      else if (verdict == 'suspicious') found.add('Şüpheli Aktivite');
      else if (verdict == 'clean') found.add('Temiz — Risk Yok');
    }

    return found.toList();
  }

  /// "Detaylı Analiz" bölümünü rapor metninden çıkar
  String get detailedAnalysis => _extractSection(
        aiReport,
        [r'detayl[ıi]\s*analiz', r'detailed analysis', r'3\.'],
        [r'kullan[ıi]c[ıi]ya\s*tavsiye', r'öneri', r'recommendation', r'4\.'],
      );

  /// "Kullanıcıya Tavsiye" bölümünü rapor metninden çıkar
  String get userAdvice => _extractSection(
        aiReport,
        [r'kullan[ıi]c[ıi]ya\s*tavsiye', r'öneri', r'recommendation', r'4\.'],
        [],
      );

  static String _extractSection(
    String text,
    List<String> startPatterns,
    List<String> endPatterns,
  ) {
    if (text.isEmpty) return '';

    // Başlangıç pozisyonunu bul
    int start = -1;
    for (final p in startPatterns) {
      final re = RegExp(p, caseSensitive: false, multiLine: true);
      final m = re.firstMatch(text);
      if (m != null) {
        start = m.end;
        break;
      }
    }
    if (start == -1) return text; // bölüm bulunamadıysa tüm metni döndür

    // Bitiş pozisyonunu bul
    int end = text.length;
    for (final p in endPatterns) {
      final re = RegExp(p, caseSensitive: false, multiLine: true);
      final m = re.firstMatch(text.substring(start));
      if (m != null) {
        final candidate = start + m.start;
        if (candidate < end) end = candidate;
        break;
      }
    }

    return text.substring(start, end).trim();
  }
}

// ——— Yardımcı: Risk Rengi & Etiketi ——————————————————————————————————————————

Color _riskColor(int score) {
  if (score >= 70) return AppColors.danger;
  if (score >= 40) return AppColors.warning;
  return AppColors.success;
}

String _riskLabel(int score) {
  if (score >= 70) return 'YÜKSEK RİSK';
  if (score >= 40) return 'ORTA RİSK';
  if (score >= 5)  return 'DÜŞÜK RİSK';
  return 'GÜVENLİ';
}

String _riskSubLabel(int score) {
  if (score >= 70) return 'Bu içerikle etkileşime geçmeyin!';
  if (score >= 40) return 'Dikkatli olunması önerilir.';
  if (score >= 5)  return 'Düşük tehdit seviyesi tespit edildi.';
  return 'Herhangi bir tehdit tespit edilmedi.';
}

IconData _riskIcon(int score) {
  if (score >= 70) return Icons.gpp_bad_rounded;
  if (score >= 40) return Icons.warning_amber_rounded;
  return Icons.verified_user_rounded;
}

// â”€â”€â”€ Taktik Ã‡ipi Konfig â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TacticConfig {
  final IconData icon;
  final Color color;
  _TacticConfig(this.icon, this.color);
}

_TacticConfig _tacticConfig(String label) {
  final l = label.toLowerCase();
  if (l.contains('kimlik avı') || l.contains('phishing'))
    return _TacticConfig(Icons.phishing_rounded, const Color(0xFFEF4444));
  if (l.contains('sosyal') || l.contains('social'))
    return _TacticConfig(Icons.psychology_rounded, const Color(0xFFF97316));
  if (l.contains('aciliyet') || l.contains('urgency'))
    return _TacticConfig(Icons.alarm_rounded, const Color(0xFFF59E0B));
  if (l.contains('sahte') || l.contains('fake') || l.contains('taklid'))
    return _TacticConfig(Icons.masks_rounded, const Color(0xFFEC4899));
  if (l.contains('parola') || l.contains('credential') || l.contains('şifre'))
    return _TacticConfig(Icons.lock_open_rounded, const Color(0xFFEF4444));
  if (l.contains('malware') || l.contains('yazılım'))
    return _TacticConfig(Icons.bug_report_rounded, const Color(0xFFEF4444));
  if (l.contains('fidye') || l.contains('ransomware'))
    return _TacticConfig(Icons.lock_rounded, const Color(0xFFDC2626));
  if (l.contains('truva') || l.contains('trojan'))
    return _TacticConfig(Icons.shield_rounded, const Color(0xFFB91C1C));
  if (l.contains('spam'))
    return _TacticConfig(Icons.mail_rounded, const Color(0xFF6366F1));
  if (l.contains('casus') || l.contains('spyware'))
    return _TacticConfig(Icons.visibility_rounded, const Color(0xFF8B5CF6));
  if (l.contains('arka kapı') || l.contains('backdoor'))
    return _TacticConfig(Icons.door_back_door_rounded, const Color(0xFFDC2626));
  if (l.contains('güvenlik açığı') || l.contains('exploit'))
    return _TacticConfig(Icons.security_rounded, const Color(0xFFF59E0B));
  if (l.contains('temiz') || l.contains('güvenli'))
    return _TacticConfig(Icons.check_circle_rounded, AppColors.success);
  return _TacticConfig(Icons.warning_amber_rounded, const Color(0xFFF59E0B));
}

// â”€â”€â”€ Neon Gauge CustomPainter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RiskGaugePainter extends CustomPainter {
  final double progress; // 0.0â€“1.0
  final Color  color;
  final Color  trackColor;

  _RiskGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center     = Offset(size.width / 2, size.height / 2);
    final radius     = size.width / 2 - 16;
    const strokeW    = 18.0;
    const startAngle = math.pi * 0.75;   // 135Â°
    const sweepTotal = math.pi * 1.5;    // 270Â°

    // â”€â”€ Track (arka plan) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final trackPaint = Paint()
      ..color       = trackColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false, trackPaint,
    );

    if (progress <= 0) return;

    // â”€â”€ Glow (dÄ±ÅŸ hale) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final glowPaint = Paint()
      ..color       = color.withValues(alpha: 0.35)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeW + 12
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal * progress, false, glowPaint,
    );

    // â”€â”€ Value arc (deÄŸer) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final valuePaint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal * progress, false, valuePaint,
    );

    // â”€â”€ UÃ§ nokta parlak nokta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final endAngle = startAngle + sweepTotal * progress;
    final tipX     = center.dx + radius * math.cos(endAngle);
    final tipY     = center.dy + radius * math.sin(endAngle);
    canvas.drawCircle(
      Offset(tipX, tipY), strokeW / 2,
      Paint()
        ..color      = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(tipX, tipY), strokeW / 2 - 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RiskGaugePainter old) =>
      old.progress != progress || old.color != color;
}

// â”€â”€â”€ Ana Ekran â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ResultScreen extends StatefulWidget {
  final ScanResultData data;
  const ResultScreen({super.key, required this.data});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double>   _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _gaugeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ——— PDF ———————————————————————————————————————————————————————————————————————

  Future<void> _sharePdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🔄 PDF raporu hazırlanıyor...',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.bgElevated,
        behavior:        SnackBarBehavior.floating,
        duration:        const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      final bytes = await PdfGenerator.generate(widget.data);
      await Printing.sharePdf(
        bytes:    bytes,
        filename: 'CyberCheck_Analiz_Raporu.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF oluşturulurken hata: $e',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final d      = widget.data;
    final rColor = _riskColor(d.riskScore);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: _buildAppBar(context, d),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ 1. Neon Gauge Paneli â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildHeroGauge(d, rColor),
            const SizedBox(height: 16),

            // â”€â”€ 2. Hedef Hap KartÄ± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (d.inputLabel != null && d.inputLabel!.isNotEmpty) ...[
              _buildTargetPill(d),
              const SizedBox(height: 16),
            ],

            // â”€â”€ 3. Taktik Ã‡ipleri â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (d.threats.isNotEmpty) ...[
              _buildTacticsSection(d.threats, rColor),
              const SizedBox(height: 16),
            ],

            // â”€â”€ 4. Akordeon: DetaylÄ± Analiz â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildAccordionCard(
              icon:  'ğŸ”',
              title: 'Detaylı Siber Analiz Raporu',
              color: AppColors.accentCyan,
              child: _buildReportContent(
                d.detailedAnalysis.isNotEmpty ? d.detailedAnalysis : d.aiReport,
                AppColors.accentCyan,
              ),
            ),
            const SizedBox(height: 12),

            // â”€â”€ 5. Akordeon: Tavsiyeler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildAccordionCard(
              icon:  'ğŸ›¡ï¸',
              title: 'Çözüm ve Aksiyon Planı',
              color: AppColors.accentBlue,
              child: _buildReportContent(
                d.userAdvice.isNotEmpty ? d.userAdvice : d.aiReport,
                AppColors.accentBlue,
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ 6. PDF Butonu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildPdfButton(),
            const SizedBox(height: 12),

            // â”€â”€ 7. Yeni Tarama â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildNewScanButton(context),
          ],
        ),
      ),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  AppBar _buildAppBar(BuildContext context, ScanResultData d) {
    return AppBar(
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () {
          if (context.canPop()) context.pop();
          else context.go('/dashboard');
        },
      ),
      title: Text(
        'Analiz Sonucu',
        style: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon:    const Icon(Icons.picture_as_pdf_rounded, size: 22),
          color:   AppColors.accentBlue,
          tooltip: 'PDF İndir',
          onPressed: _sharePdf,
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        AppColors.accentBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
          ),
          child: Text(
            d.scanType.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AppColors.accentBlue,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.borderSubtle),
      ),
    );
  }

  // â”€â”€ 1. Hero Gauge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeroGauge(ScanResultData d, Color rColor) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: rColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:      rColor.withValues(alpha: 0.18),
            blurRadius: 48,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // â”€â”€ Neon Gauge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animasyonlu daire
                AnimatedBuilder(
                  animation: _gaugeAnim,
                  builder: (_, __) => CustomPaint(
                    size: const Size(240, 240),
                    painter: _RiskGaugePainter(
                      progress:   _gaugeAnim.value * d.riskScore / 100,
                      color:      rColor,
                      trackColor: rColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // Merkez iÃ§erik
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ä°kon arka planÄ±
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color:        rColor.withValues(alpha: 0.12),
                        shape:        BoxShape.circle,
                        border:       Border.all(color: rColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(_riskIcon(d.riskScore), color: rColor, size: 24),
                    ),
                    const SizedBox(height: 8),

                    // Animasyonlu skor
                    AnimatedBuilder(
                      animation: _gaugeAnim,
                      builder: (_, __) => Text(
                        '${(_gaugeAnim.value * d.riskScore).toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: rColor,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: rColor.withValues(alpha: 0.6),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: GoogleFonts.inter(
                        fontSize: 15, color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // â”€â”€ Risk Etiketi + Alt AÃ§Ä±klama â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color:        rColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border:       Border.all(color: rColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              _riskLabel(d.riskScore),
              style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: rColor, letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _riskSubLabel(d.riskScore),
            style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // â”€â”€ Risk Ä°lerleme Ã‡ubuÄŸu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: _gaugeAnim,
              builder: (_, __) => LinearProgressIndicator(
                value:           _gaugeAnim.value * d.riskScore / 100,
                minHeight:       10,
                backgroundColor: rColor.withValues(alpha: 0.1),
                valueColor:      AlwaysStoppedAnimation<Color>(rColor),
              ),
            ),
          ),

          // Min/Maks etiketleri
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Güvenli',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.success)),
                Text('Tehlikeli',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ 2. Hedef Hap KartÄ± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTargetPill(ScanResultData d) {
    final iconMap = {
      'url':      Icons.link_rounded,
      'text':     Icons.article_rounded,
      'file':     Icons.insert_drive_file_rounded,
      'image':    Icons.image_rounded,
      'document': Icons.description_rounded,
    };
    final icon = iconMap[d.scanType] ?? Icons.radar_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Tip ikonu
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: AppColors.accentBlue, size: 18),
          ),
          const SizedBox(width: 12),

          // Etiketler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TARANAN HEDEF',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  d.inputLabel!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Scan type rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColors.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.25)),
            ),
            child: Text(
              d.scanType.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ 3. Taktik Ã‡ipleri (Wrap + Chip) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTacticsSection(List<String> tactics, Color rColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BaÅŸlÄ±k
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color:        rColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.radar_rounded, color: rColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'TESPİT EDİLEN TAKTİKLER',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        rColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tactics.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: rColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // â”€â”€ Wrap + ikonlu Chip'ler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tactics.map((tactic) {
              final cfg = _tacticConfig(tactic);
              return _TacticChip(label: tactic, icon: cfg.icon, color: cfg.color);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // â”€â”€ 4 & 5. Akordeon KartÄ± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAccordionCard({
    required String   icon,
    required String   title,
    required Color    color,
    required Widget   child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color:      color.withValues(alpha: 0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          // ExpansionTile splash rengini Ã¶zelleÅŸtir
          data: Theme.of(context).copyWith(
            dividerColor:             Colors.transparent,
            splashColor:              color.withValues(alpha: 0.08),
            highlightColor:           color.withValues(alpha: 0.04),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor:           color,
            collapsedIconColor:  AppColors.textMuted,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 16)),
              ),
            ),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Detayları görüntülemek için dokunun',
              style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted,
              ),
            ),
            children: [
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Rapor Ä°Ã§erik Renderer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildReportContent(String text, Color accentColor) {
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Bu bÃ¶lÃ¼m iÃ§in iÃ§erik mevcut deÄŸil.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    return _ReportRenderer(text: text, accentColor: accentColor);
  }

  // â”€â”€ PDF Butonu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPdfButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _sharePdf,
        icon:  const Icon(Icons.picture_as_pdf_rounded, size: 20),
        label: Text(
          'Raporu Ä°ndir (PDF)',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: AppColors.accentBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.4)),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // â”€â”€ Yeni Tarama Butonu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildNewScanButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go('/scan'),
      icon:  const Icon(Icons.radar_rounded, size: 20),
      label: Text(
        'Yeni Tehdit Analizi',
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentBlue,
        side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

// â”€â”€â”€ Taktik Chip Widget'Ä± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TacticChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;

  const _TacticChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:      color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Rapor Metin Renderer (Markdown-benzeri) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReportRenderer extends StatelessWidget {
  final String text;
  final Color  accentColor;

  const _ReportRenderer({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _renderLine(line)).toList(),
    );
  }

  Widget _renderLine(String line) {
    // ## BaÅŸlÄ±k
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          line.substring(3).replaceAll('**', ''),
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
      );
    }
    // # BÃ¼yÃ¼k baÅŸlÄ±k
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          line.substring(2).replaceAll('**', ''),
          style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    // **KalÄ±n** (satÄ±r baÅŸÄ±)
    if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          line.substring(2, line.length - 2),
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    // NumaralÄ± madde: "1." veya "2." vb.
    final numberedRe = RegExp(r'^(\d+)\.\s+(.+)');
    final numMatch   = numberedRe.firstMatch(line);
    if (numMatch != null) {
      final num  = numMatch.group(1)!;
      final body = numMatch.group(2)!.replaceAll('**', '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22, height: 22,
              margin: const EdgeInsets.only(top: 1, right: 10),
              decoration: BoxDecoration(
                color:        accentColor.withValues(alpha: 0.12),
                shape:        BoxShape.circle,
                border:       Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  num,
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.65,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // - veya â€¢ liste Ã¶ÄŸesi
    if (line.startsWith('- ') || line.startsWith('â€¢ ')) {
      final body = line.substring(2).replaceAll('**', '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 10),
              child: Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:      accentColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Divider
    if (line.trim() == '---') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(color: AppColors.borderSubtle),
      );
    }
    // BoÅŸ satÄ±r
    if (line.trim().isEmpty) return const SizedBox(height: 6);

    // Normal metin (**kalÄ±n** etiketleri temizle)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        line.replaceAll('**', ''),
        style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textSecondary, height: 1.65,
        ),
      ),
    );
  }
}

