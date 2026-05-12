// pages/ReportPage.jsx
// Detailed report view for a single scan — fetched from Supabase by ID.
// Features: circular risk gauge · tactics list · html2pdf PDF export

import React, { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import ReactMarkdown from 'react-markdown';
import './ReportPage.css';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Derives a 0-100 risk score from verdict + stats */
function calcRiskScore(scan) {
    const { verdict, stats } = scan;
    if (verdict === 'malicious')  return stats?.malicious ? Math.min(100, 60 + Math.round((stats.malicious / Math.max(stats.total || 1, 1)) * 40)) : 90;
    if (verdict === 'suspicious') return stats?.suspicious ? Math.min(70, 35 + Math.round((stats.suspicious / Math.max(stats.total || 1, 1)) * 35)) : 50;
    if (verdict === 'clean')      return stats?.total ? Math.max(0, 10 - Math.round((stats.harmless / Math.max(stats.total, 1)) * 10)) : 5;

    // Gemini-based: extract from AI report text
    if (scan.stats?.report_content) {
        const lower = scan.stats.report_content.toLowerCase();
        if (lower.includes('kritik')) return 92;
        if (lower.includes('yüksek')) return 75;
        if (lower.includes('orta'))   return 48;
        if (lower.includes('düşük'))  return 18;
        if (lower.includes('temiz'))  return 5;
    }
    return 0;
}

/** Extracts bullet-point "tactics" from Gemini AI report text */
function extractTactics(text = '') {
    const lines = text.split('\n');
    const tactics = [];
    for (const line of lines) {
        const trimmed = line.replace(/^[-*•]\s*/, '').replace(/\*\*/g, '').trim();
        if (trimmed.length > 15 && trimmed.length < 200 && !trimmed.startsWith('#')) {
            tactics.push(trimmed);
            if (tactics.length >= 8) break;
        }
    }
    return tactics;
}

/** Derives label & color from risk score */
function riskMeta(score) {
    if (score >= 80) return { label: 'Kritik', color: '#ef4444', glow: 'rgba(239,68,68,0.5)',  bg: 'rgba(239,68,68,0.08)' };
    if (score >= 55) return { label: 'Yüksek', color: '#f97316', glow: 'rgba(249,115,22,0.4)', bg: 'rgba(249,115,22,0.07)' };
    if (score >= 35) return { label: 'Orta',   color: '#f59e0b', glow: 'rgba(245,158,11,0.4)', bg: 'rgba(245,158,11,0.07)' };
    if (score >= 10) return { label: 'Düşük',  color: '#22d3ee', glow: 'rgba(34,211,238,0.3)',  bg: 'rgba(34,211,238,0.06)' };
    return              { label: 'Güvenli', color: '#10b981', glow: 'rgba(16,185,129,0.4)',  bg: 'rgba(16,185,129,0.07)' };
}

// ── Circular Gauge ─────────────────────────────────────────────────────────────

function RiskGauge({ score }) {
    const meta = riskMeta(score);
    const R = 70;
    const CIRCUMFERENCE = 2 * Math.PI * R;
    const [animated, setAnimated] = useState(0);

    useEffect(() => {
        const timer = setTimeout(() => setAnimated(score), 120);
        return () => clearTimeout(timer);
    }, [score]);

    const dashOffset = CIRCUMFERENCE - (animated / 100) * CIRCUMFERENCE;

    return (
        <div className="rp-gauge__wrapper" style={{ filter: `drop-shadow(0 0 20px ${meta.glow})` }}>
            <svg className="rp-gauge__svg" viewBox="0 0 180 180" fill="none">
                {/* Track */}
                <circle cx="90" cy="90" r={R}
                    stroke="rgba(255,255,255,0.06)"
                    strokeWidth="14"
                    fill="none"
                />
                {/* Progress arc */}
                <circle cx="90" cy="90" r={R}
                    stroke={meta.color}
                    strokeWidth="14"
                    fill="none"
                    strokeLinecap="round"
                    strokeDasharray={CIRCUMFERENCE}
                    strokeDashoffset={dashOffset}
                    transform="rotate(-90 90 90)"
                    style={{ transition: 'stroke-dashoffset 1.2s cubic-bezier(.4,0,.2,1)' }}
                />
                {/* Score text */}
                <text x="90" y="84" textAnchor="middle" fill={meta.color}
                    fontSize="36" fontWeight="700" fontFamily="Inter, sans-serif">
                    {score}
                </text>
                <text x="90" y="104" textAnchor="middle" fill="rgba(255,255,255,0.45)"
                    fontSize="12" fontFamily="Inter, sans-serif">
                    / 100
                </text>
                <text x="90" y="122" textAnchor="middle" fill={meta.color}
                    fontSize="13" fontWeight="600" fontFamily="Inter, sans-serif">
                    {meta.label}
                </text>
            </svg>
        </div>
    );
}

// ── Scan type helpers ─────────────────────────────────────────────────────────

function typeLabel(type) {
    switch (type) {
        case 'url':      return { icon: '🔗', text: 'URL Taraması' };
        case 'image':    return { icon: '🖼️', text: 'Görsel Analizi' };
        case 'document': return { icon: '📄', text: 'Belge Analizi' };
        case 'text':     return { icon: '📝', text: 'Metin Analizi' };
        default:         return { icon: '🤖', text: 'AI Analizi' };
    }
}

function verdictLabel(verdict) {
    if (verdict === 'clean')      return { icon: '✅', text: 'Güvenli',  cls: 'clean' };
    if (verdict === 'malicious')  return { icon: '🚨', text: 'Kritik',   cls: 'malicious' };
    if (verdict === 'suspicious') return { icon: '⚠️', text: 'Şüpheli', cls: 'suspicious' };
    return { icon: '⏳', text: 'Analiz Ediliyor', cls: 'unknown' };
}

// ── Main component ────────────────────────────────────────────────────────────

export default function ReportPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const reportRef = useRef(null);

    const [scan,    setScan]    = useState(null);
    const [loading, setLoading] = useState(true);
    const [error,   setError]   = useState(null);
    const [pdfBusy, setPdfBusy] = useState(false);

    // ── Fetch scan from Supabase ───────────────────────────────────────────
    useEffect(() => {
        async function fetchScan() {
            const { data, error: err } = await supabase
                .from('scans')
                .select('*')
                .eq('id', id)
                .single();

            if (err || !data) {
                setError('Tarama bulunamadı veya erişim izniniz yok.');
            } else {
                setScan(data);
            }
            setLoading(false);
        }
        fetchScan();
    }, [id]);

    // ── PDF export ────────────────────────────────────────────────────────
    const handleDownloadPDF = async () => {
        if (!reportRef.current || pdfBusy) return;
        setPdfBusy(true);
        try {
            const html2pdf = (await import('html2pdf.js')).default;
            const filename = `CyberCheck_Report_${id.slice(0, 8)}.pdf`;
            await html2pdf()
                .set({
                    margin:      [12, 12, 12, 12],
                    filename,
                    html2canvas: { scale: 2, useCORS: true, logging: false },
                    jsPDF:       { unit: 'mm', format: 'a4', orientation: 'portrait' },
                    pagebreak:   { mode: ['avoid-all', 'css', 'legacy'] },
                })
                .from(reportRef.current)
                .save();
        } catch (e) {
            console.error('PDF export error:', e);
        } finally {
            setPdfBusy(false);
        }
    };

    // ── Loading / Error states ────────────────────────────────────────────
    if (loading) {
        return (
            <div className="rp-center">
                <div className="rp-spinner" />
                <p style={{ color: 'var(--text-muted)', marginTop: 16 }}>Rapor yükleniyor…</p>
            </div>
        );
    }

    if (error || !scan) {
        return (
            <div className="rp-center">
                <p style={{ color: 'var(--color-danger)', fontSize: '1.1rem' }}>{error || 'Bilinmeyen hata.'}</p>
                <button className="rp-btn rp-btn--ghost" style={{ marginTop: 24 }} onClick={() => navigate(-1)}>
                    ← Geri Dön
                </button>
            </div>
        );
    }

    // ── Derived data ──────────────────────────────────────────────────────
    const score    = calcRiskScore(scan);
    const meta     = riskMeta(score);
    const typeMeta = typeLabel(scan.scan_type || scan.type);
    const vMeta    = verdictLabel(scan.verdict);
    const aiText   = scan.stats?.report_content ?? '';
    const tactics  = scan.verdict
        ? []                          // VT scans — use stats table instead
        : extractTactics(aiText);     // Gemini scans

    const vtStats  = scan.stats && typeof scan.stats === 'object' && !scan.stats.report_content
        ? (({ url_meta, ...rest }) => Object.keys(rest).length > 0 ? rest : null)(scan.stats)
        : null;

    const urlMeta  = scan.stats?.url_meta ?? null;

    const scanDate = new Date(scan.created_at).toLocaleString('tr-TR', {
        dateStyle: 'long', timeStyle: 'short',
    });

    return (
        <div className="rp-page">
            {/* ── Sticky action bar (not in PDF) ── */}
            <div className="rp-action-bar no-print">
                <button className="rp-btn rp-btn--ghost" onClick={() => navigate(-1)}>
                    ← Geri Dön
                </button>
                <button
                    className="rp-btn rp-btn--primary"
                    onClick={handleDownloadPDF}
                    disabled={pdfBusy}
                >
                    {pdfBusy ? (
                        <><span className="rp-btn-spinner" /> Hazırlanıyor…</>
                    ) : (
                        <><DownloadIcon /> PDF Olarak İndir</>
                    )}
                </button>
            </div>

            {/* ── PDF content region ── */}
            <div className="rp-content" ref={reportRef}>

                {/* PDF-only header */}
                <div className="rp-pdf-header pdf-only">
                    <span className="rp-pdf-brand">⚡ CyberCheck</span>
                    <span className="rp-pdf-subtitle">Tehdit Analiz Raporu</span>
                </div>

                {/* ── Hero section ── */}
                <div className="rp-hero" style={{ background: meta.bg }}>
                    <div className="rp-hero__left">
                        <div className="rp-hero__type-chip">
                            <span>{typeMeta.icon}</span>
                            <span>{typeMeta.text}</span>
                        </div>

                        <h1 className="rp-hero__title" title={scan.file_name}>
                            {scan.file_name?.length > 60
                                ? scan.file_name.substring(0, 60) + '…'
                                : scan.file_name || 'Bilinmeyen Hedef'}
                        </h1>

                        <div className="rp-hero__meta-row">
                            <MetaChip label="Tarih"    value={scanDate} />
                            <MetaChip label="Boyut"    value={scan.file_size ? formatBytes(scan.file_size) : '—'} />
                            <MetaChip label="Durum"
                                value={<span className={`status-badge ${scan.status?.toLowerCase()}`}>{scan.status}</span>}
                            />
                        </div>

                        <div className={`rp-verdict-banner rp-verdict-banner--${vMeta.cls}`}>
                            <span className="rp-verdict-banner__icon">{vMeta.icon}</span>
                            <div>
                                <p className="rp-verdict-banner__title">Risk Sonucu: {vMeta.text}</p>
                                {scan.analysis_id && (
                                    <p className="rp-verdict-banner__sub">Analiz ID: {scan.analysis_id.slice(0, 30)}…</p>
                                )}
                            </div>
                        </div>
                    </div>

                    <div className="rp-hero__right">
                        <p className="rp-gauge__label">Risk Skoru</p>
                        <RiskGauge score={score} />
                    </div>
                </div>

                {/* ── VirusTotal stats ── */}
                {vtStats && (
                    <section className="rp-section">
                        <h2 className="rp-section__title">🛡️ VirusTotal Motor Sonuçları</h2>
                        <div className="rp-stats-grid">
                            <StatBox label="Zararlı"        value={vtStats.malicious   ?? 0} variant="malicious" />
                            <StatBox label="Şüpheli"        value={vtStats.suspicious  ?? 0} variant="suspicious" />
                            <StatBox label="Temiz"          value={vtStats.harmless    ?? 0} variant="harmless" />
                            <StatBox label="Tespit Edilmedi" value={vtStats.undetected ?? 0} variant="undetected" />
                            <StatBox label="Toplam Motor"   value={vtStats.total       ?? 0} variant="total" />
                        </div>
                    </section>
                )}

                {/* ── URL Identity Card ── */}
                {urlMeta && (
                    <UrlIdentityCard meta={urlMeta} targetUrl={scan.file_name} />
                )}

                {/* ── Tactics / findings (Gemini scans) ── */}
                {tactics.length > 0 && (
                    <section className="rp-section">
                        <h2 className="rp-section__title">🎯 Tespit Edilen Taktikler ve Bulgular</h2>
                        <ul className="rp-tactics-list">
                            {tactics.map((t, i) => (
                                <li key={i} className="rp-tactics-list__item">
                                    <span className="rp-tactics-list__bullet" />
                                    {t}
                                </li>
                            ))}
                        </ul>
                    </section>
                )}

                {/* ── Full AI report ── */}
                {aiText && (
                    <section className="rp-section">
                        <h2 className="rp-section__title">🤖 Yapay Zeka Analiz Raporu</h2>
                        <div className="rp-ai-report">
                            <ReactMarkdown>{aiText}</ReactMarkdown>
                        </div>
                    </section>
                )}

                {/* PDF footer */}
                <div className="rp-pdf-footer pdf-only">
                    <span>CyberCheck — Otomatik Tehdit Analiz Platformu</span>
                    <span>{new Date().toLocaleDateString('tr-TR')}</span>
                </div>
            </div>
        </div>
    );
}

// ── Sub-components ────────────────────────────────────────────────────────────

function MetaChip({ label, value }) {
    return (
        <div className="rp-meta-chip">
            <span className="rp-meta-chip__label">{label}</span>
            <span className="rp-meta-chip__value">{value}</span>
        </div>
    );
}

// ── URL Identity Card ─────────────────────────────────────────────────────

function UrlIdentityCard({ meta, targetUrl }) {
    const sslValid   = meta.ssl?.is_valid;
    const sslColor   = sslValid === true ? '#10b981' : sslValid === false ? '#ef4444' : '#94a3b8';
    const sslLabel   = sslValid === true ? '✅ Geçerli SSL' : sslValid === false ? '❌ Süresi Dolmuş' : '❓ SSL Bilgisi Yok';
    const sslBg      = sslValid === true ? 'rgba(16,185,129,0.12)' : sslValid === false ? 'rgba(239,68,68,0.12)' : 'rgba(148,163,184,0.08)';

    const repScore   = meta.reputation ?? null;
    const repColor   = repScore === null ? '#94a3b8' : repScore >= 0 ? '#10b981' : '#ef4444';
    const repLabel   = repScore === null ? '—' : repScore >= 0 ? `+${repScore} (Olumlu)` : `${repScore} (Olumsuz)`;

    const fmtDate = (iso) => iso
        ? new Date(iso).toLocaleDateString('tr-TR', { dateStyle: 'medium' })
        : '—';

    return (
        <section className="rp-section rp-id-card">
            <h2 className="rp-section__title">🪪 URL Kimlik Kartı</h2>

            <div className="rp-id-card__grid">

                {/* ── Left column ── */}
                <div className="rp-id-card__col">

                    {/* Target URL */}
                    <div className="rp-id-row">
                        <span className="rp-id-row__key">🌐 Hedef URL</span>
                        <a
                            href={targetUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="rp-id-row__val rp-id-row__val--link"
                            title={targetUrl}
                        >
                            {targetUrl?.length > 55 ? targetUrl.substring(0, 55) + '…' : targetUrl}
                        </a>
                    </div>

                    {/* Page title */}
                    {meta.title && (
                        <div className="rp-id-row">
                            <span className="rp-id-row__key">📝 Sayfa Başlığı</span>
                            <span className="rp-id-row__val">{meta.title}</span>
                        </div>
                    )}

                    {/* Final redirect URL */}
                    {meta.final_url && meta.final_url !== targetUrl && (
                        <div className="rp-id-row">
                            <span className="rp-id-row__key">🔀 Yönlendirme</span>
                            <a
                                href={meta.final_url}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="rp-id-row__val rp-id-row__val--link rp-id-row__val--redirect"
                                title={meta.final_url}
                            >
                                {meta.final_url.length > 55
                                    ? meta.final_url.substring(0, 55) + '…'
                                    : meta.final_url}
                            </a>
                        </div>
                    )}

                    {/* Reputation */}
                    <div className="rp-id-row">
                        <span className="rp-id-row__key">⭐ İtibar Skoru</span>
                        <span className="rp-id-row__val" style={{ color: repColor, fontWeight: 600 }}>
                            {repLabel}
                        </span>
                    </div>

                    {/* Submission stats */}
                    {meta.times_submitted != null && (
                        <div className="rp-id-row">
                            <span className="rp-id-row__key">📤 Gönderim Sayısı</span>
                            <span className="rp-id-row__val">{meta.times_submitted.toLocaleString('tr-TR')}</span>
                        </div>
                    )}

                    <div className="rp-id-row">
                        <span className="rp-id-row__key">📅 İlk Görülme</span>
                        <span className="rp-id-row__val">{fmtDate(meta.first_seen)}</span>
                    </div>

                    <div className="rp-id-row">
                        <span className="rp-id-row__key">📅 Son Görülme</span>
                        <span className="rp-id-row__val">{fmtDate(meta.last_seen)}</span>
                    </div>
                </div>

                {/* ── Right column ── */}
                <div className="rp-id-card__col">

                    {/* SSL Badge */}
                    <div className="rp-id-ssl" style={{ background: sslBg, borderColor: sslColor + '50' }}>
                        <span className="rp-id-ssl__badge" style={{ color: sslColor }}>{sslLabel}</span>
                        {meta.ssl && (
                            <>
                                {meta.ssl.issuer && (
                                    <div className="rp-id-row rp-id-row--tight">
                                        <span className="rp-id-row__key">🏛️ Veren</span>
                                        <span className="rp-id-row__val">{meta.ssl.issuer}</span>
                                    </div>
                                )}
                                {meta.ssl.subject_cn && (
                                    <div className="rp-id-row rp-id-row--tight">
                                        <span className="rp-id-row__key">🔤 Konu (CN)</span>
                                        <span className="rp-id-row__val">{meta.ssl.subject_cn}</span>
                                    </div>
                                )}
                                {meta.ssl.valid_until && (
                                    <div className="rp-id-row rp-id-row--tight">
                                        <span className="rp-id-row__key">📅 Bitiş</span>
                                        <span className="rp-id-row__val" style={{ color: sslColor }}>
                                            {fmtDate(meta.ssl.valid_until)}
                                        </span>
                                    </div>
                                )}
                            </>
                        )}
                    </div>

                    {/* Categories */}
                    {meta.categories && meta.categories.length > 0 && (
                        <div className="rp-id-categories">
                            <span className="rp-id-row__key" style={{ marginBottom: 8, display: 'block' }}>
                                🏷️ Kategoriler
                            </span>
                            <div className="rp-id-categories__tags">
                                {meta.categories.map((cat, i) => (
                                    <span key={i} className="rp-id-category-tag">{cat}</span>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </section>
    );
}

function StatBox({ label, value, variant }) {
    const colors = {
        malicious:  { bg: 'rgba(239,68,68,0.12)',   color: '#ef4444' },
        suspicious: { bg: 'rgba(245,158,11,0.12)',   color: '#f59e0b' },
        harmless:   { bg: 'rgba(16,185,129,0.12)',   color: '#10b981' },
        undetected: { bg: 'rgba(148,163,184,0.10)',  color: '#94a3b8' },
        total:      { bg: 'rgba(59,130,246,0.10)',   color: '#3b82f6' },
    };
    const c = colors[variant] ?? colors.total;
    return (
        <div className="rp-stat-box" style={{ background: c.bg, borderColor: c.color + '40' }}>
            <span className="rp-stat-box__value" style={{ color: c.color }}>{value}</span>
            <span className="rp-stat-box__label">{label}</span>
        </div>
    );
}

function DownloadIcon() {
    return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
        </svg>
    );
}

function formatBytes(bytes) {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}
