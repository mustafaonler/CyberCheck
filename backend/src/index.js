// src/index.js
// CyberCheck Backend — Ana Giriş Noktası

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { connectDB } = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const scanRoutes = require('./routes/scanRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// ─── Middleware'ler ─────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── Sağlık Kontrolü (Health Check) ────────────────────────────────────────
app.get('/', (req, res) => {
    res.json({
        success: true,
        message: '🚀 CyberCheck API çalışıyor!',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
    });
});

// ─── API Rotaları ──────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/scan', scanRoutes);

// ─── 404 Handler ────────────────────────────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({ success: false, message: 'Endpoint bulunamadı.' });
});

// ─── Global Hata Handler ───────────────────────────────────────────────────
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ success: false, message: 'Sunucu hatası.' });
});

// ─── Sunucuyu Başlat ────────────────────────────────────────────────────────
const startServer = async () => {
    await connectDB(); // PostgreSQL bağlantısını test et
    app.listen(PORT, () => {
        console.log(`🚀 CyberCheck API → http://localhost:${PORT}`);
        console.log(`📌 Ortam: ${process.env.NODE_ENV || 'development'}`);
    });
};

startServer();
