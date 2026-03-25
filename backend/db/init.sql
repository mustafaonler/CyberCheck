-- ===========================================================
-- CyberCheck — Database Schema Initialization
-- Run once (or on startup) to create tables if they don't exist
-- ===========================================================

-- Enable the pgcrypto extension for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Users ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "users" (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name     VARCHAR(255) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ── Scans ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "scans" (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES "users"(id) ON DELETE CASCADE,
    scan_type           VARCHAR(20) NOT NULL CHECK (scan_type IN ('LINK', 'IMAGE_SS')),
    content             TEXT        NOT NULL,
    risk_score          INTEGER,
    ai_analysis_report  TEXT,
    vt_analysis_report  TEXT,
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
