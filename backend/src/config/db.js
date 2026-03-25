// PostgreSQL bağlantı yapılandırması — pg (node-postgres) kullanılıyor

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false } // Supabase bulut onayı
});

pool.on('error', (err) => {
  console.error('❌ PostgreSQL beklenmedik hata:', err.message);
  process.exit(1);
});

/**
 * DB bağlantısını test eder ve schema'yı başlatır (init.sql).
 */
const connectDB = async () => {
  try {
    const client = await pool.connect();
    console.log(`✅ DB Bağlantısı başarılı! Supabase'e giriş yapıldı.`);

    // Run schema initialization (CREATE TABLE IF NOT EXISTS …)
    const initPath = path.join(__dirname, '../../db/init.sql');
    if (fs.existsSync(initPath)) {
      const sql = fs.readFileSync(initPath, 'utf8');
      await client.query(sql);
      console.log('✅ Veritabanı şeması başarıyla başlatıldı (init.sql).');
    }

    client.release();
  } catch (error) {
    console.error('❌ Veritabanına bağlanılamadı:', error.message);
  }
};

module.exports = { pool, connectDB };