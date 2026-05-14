// lib/widgets/README.dart
//
// 📌 BU KLASÖR NE İÇİN?
//   Birden fazla ekranda tekrar kullanılan küçük UI bileşenlerini barındırır.
//   "Dumb" (aptal/saf) widget'lar burada tanımlanır — iş mantığı içermez,
//   sadece veriyi alıp görsel olarak sunarlar.
//
// 📦 EKLENECEK WIDGET'LAR:
//
//   cyber_button.dart
//     → Gradient arka planlı, glow efektli CyberCheck buton bileşeni
//     → Parametreler: label, onPressed, isLoading, variant (primary/outline/ghost)
//
//   risk_score_badge.dart
//     → 0-100 arası risk skorunu renk kodlu (kırmızı/sarı/yeşil) gösteren rozet
//     → AppColors.riskColor(score) kullanır
//
//   scan_history_card.dart
//     → Dashboard listesindeki her tarama kaydı için kart bileşeni
//     → Scan tipi ikonu + tarih + risk skoru + verdict badge içerir
//
//   verdict_badge.dart
//     → "clean" | "suspicious" | "malicious" etiketlerini gösteren chip
//
//   loading_overlay.dart
//     → Tarama sırasında ekranı kaplayan yarı-şeffaf yükleme göstergesi
//
//   glass_card.dart
//     → Glassmorphism efektli backdrop-blur kart (tüm ekranlarda kullanılır)
//
// 🚫 BURAYA KOYMA:
//   - Tam ekran widget'ları → screens/ klasörüne koy
//   - İş mantığı (API çağrısı vb.) → services/ klasörüne koy

// Bu dosya yalnızca dokümantasyon amaçlıdır.
// ignore_for_file: unused_import
library;
