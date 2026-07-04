// lib/screens/scan_screen.dart
//
// 📌 AMAÇ: Yeni Tehdit Analizi ekranı.
//   • Sekme 1 — URL        : tek satırlık link TextField
//   • Sekme 2 — Metin      : çok satırlı sosyal-mühendislik TextField
//   • Sekme 3 — Dosya/Görsel: dashed upload kutusu + file_picker
//   • Yükleme: siber mesajları sırayla gösteren animasyonlu kart
//   • Sonuç : mock "%85 - Kritik Tehdit" risk kartı

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../services/supabase_service.dart';
import 'result_screen.dart';

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

  // Sekme 3 — Dosya (sadece non-image: EXE, APK, PDF, ZIP vb.)
  String? _pickedFileName;

  // Durum
  bool _isLoading  = false;
  bool _showResult = false;
  String? _errorMessage;

  // Dosya (Sekme 3) — yalnızca VirusTotal için
  PlatformFile? _pickedPlatformFile;

  // SS (Sekme 2) — Gemini için ekran görüntüsü
  PlatformFile? _ssFile;
  String? _ssFileName;

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
    // Girdi doğrulama
    final tab = _tabCtrl.index;
    if (tab == 0 && _urlCtrl.text.trim().isEmpty) {
      _showSnack('Lütfen bir URL girin.');
      return;
    }
    if (tab == 1 && _textCtrl.text.trim().isEmpty && _ssFile == null) {
      _showSnack('Lütfen metin girin veya ekran görüntüsü yükleyin.');
      return;
    }
    if (tab == 2 && _pickedPlatformFile == null) {
      _showSnack('Lütfen bir dosya seçin.');
      return;
    }

    setState(() {
      _isLoading   = true;
      _showResult  = false;
      _errorMessage = null;
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

    try {
      // Auth token
      final token = SupabaseService.instance.currentSession?.accessToken;
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      http.Response? response;
      String scanType  = 'url';
      String? inputLabel;

      if (tab == 0) {
        // ── URL Tarama ──────────────────────────────────────
        scanType   = 'url';
        inputLabel = _urlCtrl.text.trim();
        headers['Content-Type'] = 'application/json';
        final user = SupabaseService.instance.currentSession?.user;
        response = await http.post(
          Uri.parse(AppConstants.scanUrlEndpoint),
          headers: headers,
          body: jsonEncode({'url': inputLabel, 'user_id': user?.id}),
        ).timeout(const Duration(seconds: 60));

      } else if (tab == 1) {
        // ── SS / Metin Analizi → Gemini ──────────────────────────
        scanType = 'text';
        final txt = _textCtrl.text.trim();
        inputLabel = _ssFileName ?? (txt.length > 60 ? '${txt.substring(0, 60)}…' : txt);

        final formData = http.MultipartRequest(
          'POST',
          Uri.parse(AppConstants.scanTextEndpoint),
        );
        formData.headers.addAll(headers);
        if (txt.isNotEmpty) formData.fields['text'] = txt;

        // Ekran görüntüsü varsa ekle → Gemini görsel + metin birlikte analiz eder
        if (_ssFile != null) {
          scanType = 'image';
          if (_ssFile!.bytes != null) {
            formData.files.add(http.MultipartFile.fromBytes(
              'image',
              _ssFile!.bytes!,
              filename: _ssFile!.name,
            ));
          } else if (_ssFile!.path != null) {
            formData.files.add(await http.MultipartFile.fromPath('image', _ssFile!.path!));
          }
        }

        final streamed = await formData.send().timeout(const Duration(seconds: 90));
        response = await http.Response.fromStream(streamed);

      } else {
        // ── Dosya Tarama (EXE/APK/PDF/ZIP vb.) → VirusTotal ──────
        // NOT: Bu sekme SADECE non-image dosyaları kabul eder.
        final pf   = _pickedPlatformFile!;
        scanType   = 'file';
        inputLabel = _pickedFileName;
        final user = SupabaseService.instance.currentSession?.user;

        final req = http.MultipartRequest(
          'POST',
          Uri.parse(AppConstants.scanFileEndpoint),
        );
        req.headers.addAll(headers);
        if (user != null) req.fields['user_id'] = user.id;

        if (pf.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes(
            'file',
            pf.bytes!,
            filename: pf.name,
          ));
        } else if (pf.path != null) {
          req.files.add(await http.MultipartFile.fromPath('file', pf.path!));
        }

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        response = await http.Response.fromStream(streamed);
      }


      _msgTimer?.cancel();

      if (response == null) {
        _onError('Sunucu bağlantı hatası: Analiz şu anda gerçekleştirilemiyor.');
        return;
      }

      // ── Backend HTTP hata kontrolü ─────────────────────────────────────────
      // Eğer backend 200 dışı bir kod dönerse (500, 503 vb.) kullanıcıyı
      // result_screen'e KESİNLİKLE yönlendirme. Sahte sonuç gösterme!
      if (response.statusCode != 200) {
        String serverMsg = 'Sunucu bağlantı hatası: Analiz şu anda gerçekleştirilemiyor.';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          if (errJson['message'] is String && (errJson['message'] as String).isNotEmpty) {
            serverMsg = 'Sunucu hatası (${response.statusCode}): ${errJson['message']}';
          }
        } catch (_) {}
        _onError(serverMsg);
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] == false) {
        _onError(json['message'] as String? ?? 'Sunucu bağlantı hatası: Analiz şu anda gerçekleştirilemiyor.');
        return;
      }

      // Veriyi çıkar
      final rawData = json['data'] as Map<String, dynamic>? ?? {};

      // Gemini yanıtında rapor `report` alanında gelir
      if (rawData['report'] != null && rawData['ai_report'] == null) {
        rawData['ai_report'] = rawData['report'];
      }

      // ── VirusTotal Polling (Bekleme) ──────────────────────────────────
      Map<String, dynamic> finalReportData = {};
      final analysisId = rawData['analysisId'];
      
      if (analysisId != null && analysisId.toString().isNotEmpty) {
        bool isDone = false;
        int attempts = 0;
        
        while (!isDone && attempts < 40) {
          await Future.delayed(const Duration(seconds: 3));
          attempts++;
          
          final pollRes = await http.get(
            Uri.parse('${AppConstants.apiBaseUrl}/api/scan/report/$analysisId'),
            headers: headers,
          ).timeout(const Duration(seconds: 15));
          
          // Polling sırasında sunucu 5xx dönerse hemen hata ver
          if (pollRes.statusCode >= 500) {
            throw Exception('Sunucu bağlantı hatası: Analiz şu anda gerçekleştirilemiyor.');
          }

          if (pollRes.statusCode == 200) {
            final pollJson = jsonDecode(pollRes.body) as Map<String, dynamic>;
            if (pollJson['success'] == true && pollJson['report'] != null) {
              final reportObj = pollJson['report'] as Map<String, dynamic>;
              if (reportObj['status'] == 'completed') {
                isDone = true;
                finalReportData = reportObj; // verdict, stats vb.
              }
            }
          }
        }
        
        if (!isDone) {
          throw Exception('VirusTotal analizi çok uzun sürdü. Raporunuz daha sonra geçmişe düşecektir.');
        }
      } else {
        // AI / Text Scan (senkron)
        finalReportData = rawData;
      }

      // Tüm verileri birleştir (POST response + Polling GET response)
      final Map<String, dynamic> mergedData = {
        ...rawData,
        ...finalReportData,
      };

      print('BACKEND YANITI (MERGED): $mergedData');

      final resultData = ScanResultData.fromJson(
        mergedData,
        scanType:   scanType,
        inputLabel: inputLabel,
      );

      if (!mounted) return;

      setState(() {
        _isLoading  = false;
        _showResult = false;
      });

      // /result rotasına yönlendir
      context.push('/result', extra: resultData);

    } on SocketException {
      _onError('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } on TimeoutException {
      _onError('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
    } catch (e) {
      _onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onError(String message) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading    = false;
      _errorMessage = message;
    });
    // Hata durumunda kırmızı SnackBar göster — sahte sonuç ekranı asla açılmaz
    _showErrorSnack(message);
  }

  /// Genel bilgi SnackBar'ı (nötr renk — girdi doğrulama vb. için)
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Sunucu / ağ hatası SnackBar'ı (kırmızı) — backend 5xx durumlarında kullanılır.
  /// result_screen'e yönlendirilmeden önce bu gösterilir; sahte 0-risk ekranı asla açılmaz.
  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F), // kırmızı — açık bir hata sinyali
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  bool _isImageFile(PlatformFile file) {
    final name = file.name.toLowerCase();
    const imageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];
    return imageExtensions.any(name.endsWith);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true, // Web için veri bytes olarak okunmalı
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final pf = result.files.first;
      setState(() {
        _pickedFileName = pf.name;
        _pickedPlatformFile = pf;
      });
    }
  }

  void _resetScan() => setState(() {
    _showResult         = false;
    _isLoading          = false;
    _errorMessage       = null;
    _pickedFileName     = null;
    _pickedPlatformFile = null;
    _ssFile             = null;
    _ssFileName         = null;
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
          Tab(text: '📧 SS / Metin'),
          Tab(text: '📄 Dosya Tara'),
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

  // ── Sekme 2: SS / Metin Analizi ─────────────────────────────────────────

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _SectionLabel(text: 'E-posta / SS Phishing Analizi → Gemini AI'),
          const SizedBox(height: 10),
          _buildTextField(),
          const SizedBox(height: 12),
          _buildSsUploadBox(),
          const SizedBox(height: 20),
          if (_isLoading) _buildLoadingCard(),
          if (_showResult) _buildResultCard(),
          if (!_isLoading && !_showResult &&
              (_textCtrl.text.trim().isNotEmpty || _ssFile != null))
            _buildAnalyzeButton(),
          if (!_isLoading && !_showResult &&
              _textCtrl.text.trim().isEmpty && _ssFile == null)
            _buildAnalyzeButton(), // disabled görünür ama tap validation halleder
          if (_showResult) ...[
            const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSsUploadBox() {
    if (_ssFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCyan.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.image_rounded, color: _kCyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _ssFileName ?? _ssFile!.name,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { _ssFile = null; _ssFileName = null; }),
              child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _pickScreenshot,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCyan.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: _kCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ekran Görüntüsü Ekle (opsiyonel)',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _kCyan,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _ssFile     = result.files.first;
        _ssFileName = result.files.first.name;
      });
    }
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
          _SectionLabel(text: 'Dosya Tara → VirusTotal (EXE, APK, PDF, ZIP vb.)'),
          const SizedBox(height: 10),
          _buildDashedUploadBox(),
          if (_pickedFileName != null) ...[
            const SizedBox(height: 12),
            _PickedFileChip(
              name: _pickedFileName!,
              onRemove: () => setState(() {
                _pickedFileName = null;
                _pickedPlatformFile = null;
              }),
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
              'Taranacak dosyayı seçmek için dokunun',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'EXE, APK, PDF, ZIP, DOC, XLSX desteklenir',
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
