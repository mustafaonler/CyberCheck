// lib/utils/pdf_generator.dart
//
// 📌 AMAÇ: CyberCheck analiz sonuçlarını kurumsal "CISO" seviyesinde PDF raporuna dönüştürür.
//   • Koyu temalı renk paleti (lacivert/gri)
//   • MultiPage yapısı ile sayfa taşmalarını önler
//   • Türkçe karakter desteği için Roboto fontu kullanır
//   • Yönetici Özeti, Teknik Bulgular ve Yapay Zeka Bağlam Analizi bölümleri
//   • Footer: "Raporu Hazırlayan: Mustafa Önler - Siber Güvenlik Araştırmacısı"

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../screens/result_screen.dart';

// ── Renk Paleti (PDF için özel — dark-themed ama print uyumlu) ────────────────

const _kNavy      = PdfColor.fromInt(0xFF0F172A);   // slate-900
const _kSurface   = PdfColor.fromInt(0xFF1E293B);   // slate-800
const _kBorder    = PdfColor.fromInt(0xFF334155);   // slate-700
const _kBlue      = PdfColor.fromInt(0xFF3B82F6);   // electric blue
const _kCyan      = PdfColor.fromInt(0xFF06B6D4);   // cyan
const _kWhite     = PdfColors.white;
const _kSlate200  = PdfColor.fromInt(0xFFE2E8F0);   // metin ana
const _kSlate400  = PdfColor.fromInt(0xFF94A3B8);   // metin ikincil
const _kSlate600  = PdfColor.fromInt(0xFF475569);   // metin muted

PdfColor _riskPdfColor(int score) {
  if (score >= 70) return const PdfColor.fromInt(0xFFEF4444); // kırmızı
  if (score >= 40) return const PdfColor.fromInt(0xFFF59E0B); // sarı
  return const PdfColor.fromInt(0xFF10B981);                  // yeşil
}

String _riskLabel(int score) {
  if (score >= 70) return 'YÜKSEK RİSK';
  if (score >= 40) return 'ORTA RİSK';
  return 'DÜŞÜK RİSK';
}

// ── PDF Üretici ───────────────────────────────────────────────────────────────

class PdfGenerator {
  PdfGenerator._();

  /// Analiz verisinden kurumsal PDF baytları üretir.
  static Future<Uint8List> generate(ScanResultData data) async {
    final pdf = pw.Document(
      title:    'CyberCheck - Siber Tehdit Analiz Raporu',
      author:   'Mustafa Önler',
      creator:  'CyberCheck Enterprise',
    );

    // Türkçe karakter güvenliği için Roboto fontunu indirip kullanıyoruz
    final ttf = await PdfGoogleFonts.robotoRegular();
    final ttfBold = await PdfGoogleFonts.robotoBold();

    final riskColor = _riskPdfColor(data.riskScore);
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttfBold,
        ),
        
        // ── Kurumsal Header ──────────────────────────────────────────────────
        header: (context) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _kNavy,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CYBERCHECK',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 24,
                          color: _kBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Siber Tehdit Analiz Raporu',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 12,
                          color: _kSlate400,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Rapor Tarihi: $dateStr',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 10,
                          color: _kSlate400,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 10,
                          color: _kSlate600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
          ],
        ),

        // ── Kurumsal Footer ──────────────────────────────────────────────────
        footer: (context) => pw.Column(
          children: [
            pw.SizedBox(height: 12),
            pw.Divider(color: _kBorder, thickness: 1),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GİZLİ - CyberCheck Enterprise Platform',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _kSlate600),
                ),
                pw.Text(
                  'Raporu Hazırlayan: Mustafa Önler - Siber Güvenlik Araştırmacısı',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _kSlate400),
                ),
              ],
            ),
          ],
        ),

        // ── Ana İçerik Gövdesi ───────────────────────────────────────────────
        build: (context) => [
          
          // 1. YÖNETİCİ ÖZETİ
          _buildSectionTitle(ttfBold, '1. YÖNETİCİ ÖZETİ (EXECUTIVE SUMMARY)'),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _kSurface,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _kBorder),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Risk Kadranı
                pw.Container(
                  width: 110, height: 110,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: _kNavy,
                    border: pw.Border.all(color: riskColor, width: 5),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${data.riskScore}',
                          style: pw.TextStyle(font: ttfBold, fontSize: 38, color: riskColor),
                        ),
                        pw.Text(
                          '/ 100',
                          style: pw.TextStyle(font: ttf, fontSize: 13, color: _kSlate400),
                        ),
                      ],
                    ),
                  ),
                ),
                
                pw.SizedBox(width: 32),
                
                // Hedef Bilgileri
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: riskColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          _riskLabel(data.riskScore),
                          style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _kNavy, letterSpacing: 1),
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      _buildInfoRow(ttf, ttfBold, 'Tarama Türü:', data.scanType.toUpperCase()),
                      if (data.inputLabel != null && data.inputLabel!.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        _buildInfoRow(ttf, ttfBold, 'Hedef (URL/Dosya):', data.inputLabel!),
                      ],
                      pw.SizedBox(height: 8),
                      _buildInfoRow(ttf, ttfBold, 'Genel Sonuç:', _verdictTr(data.verdict)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),

          // 2. TEKNİK BULGULAR
          if (data.threats.isNotEmpty) ...[
            _buildSectionTitle(ttfBold, '2. TEKNİK BULGULAR VE TEHDİT LİSTESİ'),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _kSurface,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: _kBorder),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: data.threats.map((threat) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 5, right: 10),
                          child: pw.Container(
                            width: 6, height: 6,
                            decoration: pw.BoxDecoration(color: riskColor, shape: pw.BoxShape.circle),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            threat,
                            style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _kSlate200),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 28),
          ],

          // 3. YAPAY ZEKA BAĞLAM ANALİZİ
          if (data.aiReport.isNotEmpty) ...[
            _buildSectionTitle(
              ttfBold, 
              data.threats.isNotEmpty 
                  ? '3. YAPAY ZEKA BAĞLAM ANALİZİ VE ÇÖZÜM ÖNERİLERİ' 
                  : '2. YAPAY ZEKA BAĞLAM ANALİZİ VE ÇÖZÜM ÖNERİLERİ'
            ),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: _kSurface,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: _kBorder),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _parseMarkdownToWidgets(data.aiReport, ttf, ttfBold),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ── Yardımcı Fonksiyonlar ──────────────────────────────────────────────────

  static pw.Widget _buildSectionTitle(pw.Font ttfBold, String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14, top: 8),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4, height: 18, 
            decoration: pw.BoxDecoration(
              color: _kCyan, 
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2))
            )
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            title, 
            style: pw.TextStyle(font: ttfBold, fontSize: 14, color: _kCyan, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(pw.Font ttf, pw.Font ttfBold, String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 12, color: _kSlate400)),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _kSlate200)),
        ),
      ],
    );
  }

  /// AI Raporundaki basit Markdown etiketlerini işler ve PDF widget'larına dönüştürür.
  static List<pw.Widget> _parseMarkdownToWidgets(String text, pw.Font ttf, pw.Font ttfBold) {
    final lines = text.split('\n');
    final widgets = <pw.Widget>[];

    for (var line in lines) {
      if (line.startsWith('## ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
          child: pw.Text(line.substring(3), style: pw.TextStyle(font: ttfBold, fontSize: 14, color: _kWhite)),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 10),
          child: pw.Text(line.substring(2), style: pw.TextStyle(font: ttfBold, fontSize: 16, color: _kWhite)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5, right: 10),
                child: pw.Container(
                  width: 4, height: 4, 
                  decoration: const pw.BoxDecoration(color: _kCyan, shape: pw.BoxShape.circle)
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  _cleanMarkdownBold(line.substring(2)), 
                  style: pw.TextStyle(font: ttf, fontSize: 11, color: _kSlate200, lineSpacing: 4)
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim() == '---') {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 14),
          child: pw.Divider(color: _kBorder, thickness: 1),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
      } else {
        // Normal paragraf metni
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            _cleanMarkdownBold(line), 
            style: pw.TextStyle(font: ttf, fontSize: 11, color: _kSlate200, lineSpacing: 4)
          ),
        ));
      }
    }
    return widgets;
  }

  /// Metin içindeki kalın (**) işaretlerini PDF'te kötü görünmemesi için temizler.
  static String _cleanMarkdownBold(String text) {
    return text.replaceAll('**', '').trim();
  }

  static String _verdictTr(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'malicious': return 'Zararlı';
      case 'suspicious': return 'Şüpheli';
      case 'clean': return 'Temiz (Güvenli)';
      default: return 'Bilinmiyor';
    }
  }
}
