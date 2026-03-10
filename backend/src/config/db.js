// src/config/db.js
// PostgreSQL bağlantı yapılandırması — pg (node-postgres) kullanılıyor

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

pool.on('connect', () => {
  console.log('✅ PostgreSQL veritabanına bağlandı.');
});

pool.on('error', (err) => {
  console.error('❌ PostgreSQL bağlantı hatası:', err.message);
  process.exit(1);
});

/**
 * Veritabanı bağlantısını test eder.
 * Uygulama başlarken çağrılabilir.
 */
const connectDB = async () => {
  try {
    const client = await pool.connect();
    console.log(`✅ DB Bağlantısı başarılı → ${process.env.DB_NAME}@${process.env.DB_HOST}:${process.env.DB_PORT}`);
    client.release();
  } catch (error) {
    console.error('❌ Veritabanına bağlanılamadı:', error.message);
    // process.exit(1); // Üretimde aktif edin
  }
};

module.exports = { pool, connectDB };
