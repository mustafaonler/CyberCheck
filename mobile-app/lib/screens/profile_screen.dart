// lib/screens/profile_screen.dart
//
// 📌 AMAÇ:
//   Kullanıcı profil ve ayarlar ekranı.
//
// 📦 GELECEKTE EKLENECEK:
//   - Kullanıcı avatar + e-posta gösterimi
//   - Toplam tarama sayısı istatistikleri
//   - "Çıkış Yap" butonu → SupabaseService.instance.signOut()
//   - Uygulama sürümü bilgisi
//   - Bildirim tercihleri (ileride)

import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.bgSurface,
      ),
      body: const Center(
        child: Text(
          'Profile Screen\n(Yakında)',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
