# 🛡️ CyberCheck: Yapay Zeka Destekli Tehdit İstihbarat Platformu

> *"Geleneksel güvenlik duvarları yıkıldı. Artık sistemlerin en zayıf halkası kodlar değil, insan psikolojisidir."*

Her saniye milyonlarca yeni oltalama (phishing) e-postası, gizlenmiş fidye yazılımı (ransomware) ve manipüle edilmiş bağlantı dijital dünyamıza sızıyor. **CyberCheck**, bu asimetrik siber savaşta kullanıcıları ve kurumları korumak için tasarlanmış, **bulut tabanlı ve yapay zeka destekli yeni nesil bir proaktif tehdit istihbarat platformudur.**

Şüpheli bir bağlantıya tıklamadan veya tehlikeli bir dosyayı cihazınıza indirmeden önce; CyberCheck onu sizin yerinize izole bir ortamda analiz eder, 80'den fazla global güvenlik motorunda eşzamanlı olarak tarar ve yapay zekanın analitik gücüyle saldırının asıl motivasyonunu deşifre eder. Kullanıcıya sadece teknik bir uyarı değil, hayati bir aksiyon planı sunar.

## 🎯 Tehdit Avcılığı: Neleri Durduruyoruz?

* 🎣 **Zihin Hack'ini (Phishing) Çökertme:** İnsan psikolojisini hedef alan aciliyet ve korku temalı sahte e-postaları derin dil modelleriyle (LLM) analiz eder. Sistem, kullanıcı oltaya takılmadan önce saldırganın kullandığı "Sosyal Mühendislik" taktiklerini adım adım ifşa eder.
* 🦠 **Fidye Yazılımı ve Malware Kalkanı:** Cihazınızı şifrelemeyi hedefleyen zararlı dosyalar, donanımınıza temas etmeden saniyeler önce küresel tehdit istihbarat ağında (VirusTotal) çapraz sorguya alınır ve etkisiz hale getirilir.
* 🧠 **Sıfırıncı Gün (Zero-Day) Algısı:** İmza tabanlı klasik antivirüslerin aksine, tehlikenin sadece koduna değil "niyetine" odaklanır. Yapay zeka motoru, daha önce hiç görülmemiş karmaşık tehdit senaryolarını mantıksal olarak ayrıştırarak görünmez tehlikeleri gün yüzüne çıkarır.

---

## 💻 Web Platformu (SOC Dashboard)

Profesyonel Siber Güvenlik Operasyon Merkezlerinden (SOC) ilham alınarak tasarlanan web arayüzümüz, güvenlik analistlerine ve son kullanıcılara anlık, panoramik bir tehdit izleme deneyimi sunar.

![Web Ana Dashboard](<img width="1901" height="906" alt="image" src="https://github.com/user-attachments/assets/fc417081-bedd-48fc-96c3-521972ac1955" />
)

![Web Analiz Sonucu](<img width="1912" height="821" alt="image" src="https://github.com/user-attachments/assets/7ea593c0-767a-4d77-aad4-eaea3af8e5fe" />
)

![Web Raporlama Sistemi](<img width="1893" height="845" alt="image" src="https://github.com/user-attachments/assets/04ae3cdc-9ffd-45b8-b5c6-74379139027a" />
)
<img width="1896" height="818" alt="image" src="https://github.com/user-attachments/assets/cfd364e2-5ddd-43fb-9da0-243ba1ace36b" />


---

## 📱 Mobil Platform

Gerçek siber güvenliğin mekandan bağımsız olması gerektiği inancıyla inşa edilen mobil uygulamamız; hareket halindeyken bile siber istihbarat ağlarına tam erişim, anlık tarama ve "Fail-Safe" (Hata anında güvenli kalma) mimarisiyle kesintisiz koruma sağlar.

![Mobil Ana Ekran](<img width="501" height="797" alt="image" src="https://github.com/user-attachments/assets/a9086c9f-a88e-40e4-99c0-02acbefba131" />
)

![Mobil Sonuç Ekranı](<img width="496" height="797" alt="image" src="https://github.com/user-attachments/assets/1ade9d37-8cc4-462e-b2fb-74de42925161" />
)
<img width="497" height="797" alt="image" src="https://github.com/user-attachments/assets/0c2602c6-148d-4a7e-92be-4dac6d402458" />

---

## 🛠️ Teknolojik Yığın (Tech Stack)

Bu proje, yüksek trafikli güvenlik analizlerini kaldırabilmesi için modern, asenkron ve ölçeklenebilir bir mimari üzerine inşa edilmiştir:

* **Tehdit İstihbaratı ve AI:** Google Gemini 2.5 Flash AI, VirusTotal Intelligence API
* **Backend (Sunucu Mimarisi):** Node.js, Express.js (RESTful API Tasarımı)
* **Veritabanı ve Güvenli Kimlik Doğrulama:** Supabase (PostgreSQL, Row Level Security)
* **Frontend (Web):** React.js, Tailwind CSS, Vite
* **Frontend (Mobil):** Flutter, GoRouter, fl_chart (Dinamik Veri Görselleştirme), printing (PDF Raporlama)

# 4. Mobil Uygulamayı Başlatın
cd ../mobile-app
flutter pub get
flutter run
