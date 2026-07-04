# 🛡️ CyberCheck: Yapay Zeka Destekli Tehdit İstihbarat Platformu

> *"Geleneksel güvenlik duvarları yıkıldı. Artık sistemlerin en zayıf halkası kodlar değil, insan psikolojisidir."*

Her saniye milyonlarca yeni oltalama (phishing) e-postası, gizlenmiş fidye yazılımı (ransomware) ve manipüle edilmiş bağlantı dijital dünyamıza sızıyor. **CyberCheck**, bu asimetrik siber savaşta kullanıcıları ve kurumları korumak için tasarlanmış, **bulut tabanlı ve yapay zeka destekli yeni nesil bir proaktif tehdit istihbarat platformudur.**

Şüpheli bir bağlantıya tıklamadan veya tehlikeli bir dosyayı cihazınıza indirmeden önce; CyberCheck onu sizin yerinize izole bir ortamda analiz eder, 80'den fazla global güvenlik motorunda eşzamanlı olarak tarar ve yapay zekanın analitik gücüyle saldırının asıl motivasyonunu deşifre eder.

## 🎯 Tehdit Avcılığı: Neleri Durduruyoruz?

Günümüzde siber saldırılar karmaşıklaşırken CyberCheck üç ana cephede savunma hattı kurar:
* 🎣 **Zihin Hack'ini (Phishing) Çökertme:** İnsan psikolojisini hedef alan aciliyet temalı sahte e-postaları derin dil modelleriyle analiz ederek "Sosyal Mühendislik" taktiklerini ifşa eder.
* 🦠 **Fidye Yazılımı ve Malware Kalkanı:** Cihazınızı şifrelemeyi hedefleyen zararlı dosyalar, donanımınıza temas etmeden saniyeler önce küresel tehdit istihbarat ağında çapraz sorguya alınır.
* 🧠 **Sıfırıncı Gün (Zero-Day) Algısı:** İmza tabanlı klasik antivirüslerin aksine, tehlikenin sadece koduna değil "niyetine" odaklanarak görünmez tehlikeleri gün yüzüne çıkarır.

---

## ✨ Temel Özellikler

| Özellik | Açıklama |
| :--- | :--- |
| 🧠 **AI Destekli Analiz** | Gemini 2.5 Flash ile tehditlerin mantıksal, sözdizimsel ve hedef analizi. |
| 🦠 **Küresel Tarama** | VirusTotal API entegrasyonu ile saniyeler içinde 80+ motorda tarama. |
| 💻 **Web SOC Dashboard** | Güvenlik operasyon merkezlerinden ilham alan detaylı, panoramik kontrol paneli. |
| 📱 **Mobil Uygulama** | "Fail-Safe" mimarisiyle hareket halindeyken bile anlık tehdit istihbaratı. |
| 📄 **Kurumsal PDF Raporlama** | Tespit edilen tehditlerin ve çözüm önerilerinin şık PDF formatında dışa aktarımı. |

---

## 🖥️ Web Platformu (SOC Dashboard)

![Web Ana Dashboard](https://github.com/user-attachments/assets/fc417081-bedd-48fc-96c3-521972ac1955)
![Web Analiz Sonucu](https://github.com/user-attachments/assets/7ea593c0-767a-4d77-aad4-eaea3af8e5fe)
![Web Raporlama Sistemi](https://github.com/user-attachments/assets/04ae3cdc-9ffd-45b8-b5c6-74379139027a)

## 📱 Mobil Platform

<div style="display:flex; gap: 10px;">
  <img src="https://github.com/user-attachments/assets/a9086c9f-a88e-40e4-99c0-02acbefba131" width="30%" />
  <img src="https://github.com/user-attachments/assets/1ade9d37-8cc4-462e-b2fb-74de42925161" width="30%" />
  <img src="https://github.com/user-attachments/assets/0c2602c6-148d-4a7e-92be-4dac6d402458" width="30%" />
</div>

---

## 🏗️ Sistem Mimarisi

```text
┌─────────────────┐         ┌──────────────────┐         ┌──────────────┐
│   📱 Mobil      │         │   🖥️ Express.js   │         │  🗄️ Supabase  │
│  (Flutter UI)   │────────▶│    REST API      │────────▶│ (PostgreSQL) │
└─────────────────┘         └────────┬─────────┘         └──────────────┘
                                     │
┌─────────────────┐                  │
│   🌐 Web (SOC)  │                  │
│ (React & Vite)  │─────────────────▶│
└─────────────────┘         ┌────────▼─────────┐
                            │  🤖 İstihbarat   │
                            │  Gemini 2.5 AI & │
                            │  VirusTotal API  │
                            └──────────────────┘
