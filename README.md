# 🛡️ CyberCheck

Siber güvenlik izleme ve kontrol platformu. Üç ana bileşenden oluşur:

---

## 📁 Proje Yapısı

```
CyberCheck/
├── backend/          # Node.js + Express.js REST API
├── frontend-web/     # React.js + Vite web paneli
└── mobile-app/       # Flutter mobil uygulaması
```

---

## 🚀 Hızlı Başlangıç

### 1. Backend

```bash
cd backend
npm install
# .env dosyasını düzenle (DB bilgilerini gir)
npm run dev
# → http://localhost:5000
```

### 2. Frontend Web

```bash
cd frontend-web
npm install
npm run dev
# → http://localhost:3000
```

### 3. Mobile App

```bash
cd mobile-app
flutter pub get
flutter run
```

---

## �️ Teknoloji Yığını

| Katman       | Teknoloji                              |
|--------------|----------------------------------------|
| Backend      | Node.js, Express.js, PostgreSQL (pg)   |
| Frontend Web | React 18, Vite 5                       |
| Mobil        | Flutter 3, Dart 3                      |

---

## 📋 Gereksinimler

- **Node.js** >= 18
- **Flutter** >= 3.x / **Dart** >= 3.3
- **PostgreSQL** >= 14
