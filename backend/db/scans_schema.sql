-- ===========================================================
-- CyberCheck — File Scan Persistence Schema (Week 5)
-- Run in Supabase SQL Editor to create the scans table.
-- ===========================================================

-- Enable UUID generation extension (already enabled by default in Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Scans Table ────────────────────────────────────────────
-- Stores every file-scan submission and its final VirusTotal result.
-- Lifecycle:  queued → in-progress → completed | failed
CREATE TABLE IF NOT EXISTS "scans" (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- File metadata (captured at upload time)
    file_name    TEXT         NOT NULL,
    file_size    BIGINT       NOT NULL,  -- bytes

    -- VirusTotal tracking
    analysis_id  TEXT         UNIQUE,    -- VT analysis ID returned after upload

    -- State machine
    status       TEXT         NOT NULL DEFAULT 'queued'
                     CHECK (status IN ('queued', 'in-progress', 'completed', 'failed')),

    -- Final verdict (NULL until analysis is complete)
    verdict      TEXT
                     CHECK (verdict IS NULL OR verdict IN ('clean', 'suspicious', 'malicious')),

    -- Raw detection counts from VirusTotal (stored as JSONB for flexibility)
    -- Example: { "malicious": 3, "suspicious": 1, "harmless": 65, "undetected": 2, "total": 71 }
    stats        JSONB,

    -- Timestamps
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Indexes ────────────────────────────────────────────────
-- Fast lookup by VirusTotal analysis ID (used by GET /api/scan/report/:id)
CREATE INDEX IF NOT EXISTS idx_scans_analysis_id ON "scans" (analysis_id);

-- Fast listing by creation time (used by dashboard queries)
CREATE INDEX IF NOT EXISTS idx_scans_created_at ON "scans" (created_at DESC);

-- ── Auto-update updated_at ─────────────────────────────────
-- Supabase / PostgreSQL trigger to keep updated_at current automatically.
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_scans_updated_at ON "scans";
CREATE TRIGGER set_scans_updated_at
    BEFORE UPDATE ON "scans"
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
