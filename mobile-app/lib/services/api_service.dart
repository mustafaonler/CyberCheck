// lib/services/api_service.dart
//
// 📌 AMAÇ:
//   CyberCheck Node.js backend'iyle tüm HTTP iletişimini yönetir.
//   Her tarama türü (URL, Dosya, Görsel, Metin) için ayrı metod barındırır.
//   Hata yönetimi ve JWT token ekleme işlemleri merkezi olarak burada yapılır.
//
// 📦 MEVCUT METODLAR:
//   - scanUrl(url)        → POST /api/scan/url
//   - scanFile(file)      → POST /api/scan/file   (multipart)
//   - scanImage(image)    → POST /api/scan/image  (multipart)
//   - scanText(text)      → POST /api/scan/text
//   - fetchHistory()      → GET  /api/scan/history
//
// 🔑 BAĞIMLILIK:
//   - http paketi
//   - SupabaseService (JWT token almak için)
//   - AppConstants (endpoint URL'leri için)

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';
import '../utils/constants.dart';

// Tarama sonucunu temsil eden veri modeli (ileride models/ klasörüne taşınabilir)
class ScanResult {
  final String  id;
  final int     riskScore;
  final String  verdict;       // 'clean' | 'suspicious' | 'malicious'
  final String  aiReport;
  final String  scanType;
  final DateTime createdAt;

  const ScanResult({
    required this.id,
    required this.riskScore,
    required this.verdict,
    required this.aiReport,
    required this.scanType,
    required this.createdAt,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    id:        json['id']         as String,
    riskScore: json['risk_score'] as int,
    verdict:   json['verdict']    as String,
    aiReport:  json['ai_report']  as String,
    scanType:  json['scan_type']  as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Yardımcı: auth header'ı ────────────────────────────────────
  Map<String, String> get _authHeaders {
    final token = SupabaseService.instance.currentSession?.accessToken;
    return {
      'Content-Type':  'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Yardımcı: hata kontrolü ─────────────────────────────────────
  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Sunucu hatası: ${res.statusCode}');
    }
  }

  // ── URL Tarama ──────────────────────────────────────────────────
  Future<ScanResult> scanUrl(String url) async {
    final res = await http.post(
      Uri.parse(AppConstants.scanUrlEndpoint),
      headers: _authHeaders,
      body: jsonEncode({'url': url}),
    );
    _checkStatus(res);
    return ScanResult.fromJson(jsonDecode(res.body)['data']);
  }

  // ── Metin / Ekran Görüntüsü Tarama ──────────────────────────────
  Future<ScanResult> scanText(String text) async {
    final res = await http.post(
      Uri.parse(AppConstants.scanTextEndpoint),
      headers: _authHeaders,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(res);
    return ScanResult.fromJson(jsonDecode(res.body)['data']);
  }

  // ── Dosya Tarama (PDF, belge) ────────────────────────────────────
  Future<ScanResult> scanFile(File file) async {
    final token = SupabaseService.instance.currentSession?.accessToken;
    final req = http.MultipartRequest('POST', Uri.parse(AppConstants.scanFileEndpoint));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return ScanResult.fromJson(jsonDecode(res.body)['data']);
  }

  // ── Görsel Tarama (ekran görüntüsü) ─────────────────────────────
  Future<ScanResult> scanImage(File image) async {
    final token = SupabaseService.instance.currentSession?.accessToken;
    final req = http.MultipartRequest('POST', Uri.parse(AppConstants.scanImageEndpoint));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('image', image.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return ScanResult.fromJson(jsonDecode(res.body)['data']);
  }

  // ── Tarama Geçmişi ───────────────────────────────────────────────
  Future<List<ScanResult>> fetchHistory() async {
    final res = await http.get(
      Uri.parse(AppConstants.historyEndpoint),
      headers: _authHeaders,
    );
    _checkStatus(res);
    final List data = jsonDecode(res.body)['data'];
    return data.map((e) => ScanResult.fromJson(e)).toList();
  }
}
