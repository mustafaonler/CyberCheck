// src/controllers/authController.js
// Handles user registration and login

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/db');

const SALT_ROUNDS = 12;

// ─── Helper: Generate JWT ────────────────────────────────────────────────────
const generateToken = (userId) => {
    return jwt.sign(
        { id: userId },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
};

// ─── POST /api/auth/register ─────────────────────────────────────────────────
const register = async (req, res, next) => {
    try {
        const { full_name, email, password } = req.body;

        // Validate required fields
        if (!full_name || !email || !password) {
            return res.status(400).json({
                success: false,
                message: 'full_name, email ve password alanları zorunludur.',
            });
        }

        // Check if email already in use
        const existing = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email.toLowerCase()]
        );

        if (existing.rows.length > 0) {
            return res.status(409).json({
                success: false,
                message: 'Bu e-posta adresi zaten kayıtlı.',
            });
        }

        // Hash password
        const password_hash = await bcrypt.hash(password, SALT_ROUNDS);

        // Insert new user
        const result = await pool.query(
            `INSERT INTO users (full_name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, full_name, email, created_at`,
            [full_name, email.toLowerCase(), password_hash]
        );

        const user = result.rows[0];
        const token = generateToken(user.id);

        return res.status(201).json({
            success: true,
            message: 'Kayıt başarılı.',
            data: { user, token },
        });
    } catch (error) {
        next(error);
    }
};

// ─── POST /api/auth/login ────────────────────────────────────────────────────
const login = async (req, res, next) => {
    try {
        const { email, password } = req.body;

        // Validate required fields
        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: 'email ve password alanları zorunludur.',
            });
        }

        // Find user by email
        const result = await pool.query(
            'SELECT id, full_name, email, password_hash, created_at FROM users WHERE email = $1',
            [email.toLowerCase()]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.',
            });
        }

        const user = result.rows[0];

        // Compare passwords
        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.',
            });
        }

        const token = generateToken(user.id);

        // Strip password_hash from response
        const { password_hash, ...safeUser } = user;

        return res.status(200).json({
            success: true,
            message: 'Giriş başarılı.',
            data: { user: safeUser, token },
        });
    } catch (error) {
        next(error);
    }
};

module.exports = { register, login };
