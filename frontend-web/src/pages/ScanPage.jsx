// pages/ScanPage.jsx
// Full scan flow: upload → polling → verdict report.

import React, { useState, useCallback, useEffect, useRef } from 'react';
import DropZone from '../components/DropZone.jsx';
import ErrorBanner from '../components/ErrorBanner.jsx';
import '../components/ScanPage.css';
import ReactMarkdown from 'react-markdown';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

const API_BASE = 'http://localhost:5000';
const POLL_INTERVAL = 3000; // ms between each report fetch
const MAX_POLLS = 40;   // stop after ~2 minutes

// ── State machine ─────────────────────────────────────────────
const STATE = {
    IDLE: 'idle',      // waiting for file/url/text
    UPLOADING: 'uploading', // POST in flight
    POLLING: 'polling',   // waiting for VT to finish
    DONE: 'done',      // final verdict ready
    ERROR: 'error',     // unrecoverable error
};

// ── SVG Icons ─────────────────────────────────────────────────

const DownloadIcon = ({ size = 20, ...props }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
        <polyline points="7 10 12 15 17 10"></polyline>
        <line x1="12" y1="15" x2="12" y2="3"></line>
    </svg>
);

const ShieldIcon = ({ size = 24, ...props }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="1.8"
        strokeLinecap="round" strokeLinejoin="round" {...props}>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
);

const CheckIcon = () => (
    <svg width="38" height="38" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2.2"
        strokeLinecap="round" strokeLinejoin="round">
        <polyline points="20 6 9 17 4 12" />
    </svg>
);

const AlertTriangleIcon = () => (
    <svg width="38" height="38" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round">
        <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
);

const ScanIcon = () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round">
        <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
    </svg>
);

const RefreshIcon = () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2.2"
        strokeLinecap="round" strokeLinejoin="round">
        <polyline points="23 4 23 10 17 10" />
        <polyline points="1 20 1 14 7 14" />
        <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
    </svg>
);

const LockIcon = () => (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
);

const LinkIcon = () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
        className="url-input-icon">
        <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
        <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
    </svg>
);

const TextIcon = () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
        className="text-input-icon">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
        <polyline points="14 2 14 8 20 8"></polyline>
        <line x1="16" y1="13" x2="8" y2="13"></line>
        <line x1="16" y1="17" x2="8" y2="17"></line>
        <polyline points="10 9 9 9 8 9"></polyline>
    </svg>
);

const ImageIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
        className="ss-upload-zone__icon">
        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
        <circle cx="8.5" cy="8.5" r="1.5"></circle>
        <polyline points="21 15 16 10 5 21"></polyline>
    </svg>
);


// ── Helpers ───────────────────────────────────────────────────

const truncateId = (id) => {
    if (!id || id.length <= 22) return id;
    return `${id.slice(0, 11)}…${id.slice(-9)}`;
};

const formatBytes = (bytes) => {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
};

// ── Main component ────────────────────────────────────────────

export default function ScanPage() {
    const [activeTab, setActiveTab] = useState('file'); // 'file' | 'url' | 'text'
    const [file, setFile] = useState(null);
    const [urlInput, setUrlInput] = useState('');
    const [textInput, setTextInput] = useState('');
    const [ssFile, setSsFile] = useState(null);

    const [uiState, setUiState] = useState(STATE.IDLE);
    const [error, setError] = useState(null);    // { title, message }
    const [uploadData, setUploadData] = useState(null);    // { analysisId, scanId, fileName, fileSizeBytes }
    const [report, setReport] = useState(null);    // final VT report object
    const [pollCount, setPollCount] = useState(0);

    const pollTimerRef = useRef(null);
    const abortRef = useRef(null); // AbortController for in-flight fetch

    // ── Cleanup on unmount ─────────────────────────────────
    useEffect(() => () => {
        clearTimeout(pollTimerRef.current);
        abortRef.current?.abort();
    }, []);

    // ── File selections ────────────────────────────────────
    const handleFile = useCallback((picked, errorMsg) => {
        setError(null);
        if (errorMsg) {
            setError({ title: 'Geçersiz dosya türü', message: errorMsg });
            setFile(null);
        } else {
            setFile(picked);
        }
    }, []);

    const handleSsFile = (e) => {
        setError(null);
        const picked = e.target.files[0];
        if (!picked) return;
        if (!picked.type.startsWith('image/')) {
            setError({ title: 'Geçersiz dosya', message: 'Lütfen sadece görsel yükleyin.' });
            return;
        }
        setSsFile(picked);
        // Clear text if user uploads SS, as they might be mutually exclusive or preferred
        // setTextInput(''); 
    };

    // ── Full reset ─────────────────────────────────────────
    const handleReset = useCallback(() => {
        clearTimeout(pollTimerRef.current);
        abortRef.current?.abort();
        setFile(null);
        setUrlInput('');
        setTextInput('');
        setSsFile(null);
        setUiState(STATE.IDLE);
        setError(null);
        setUploadData(null);
        setReport(null);
        setPollCount(0);
    }, []);

    // ── Polling logic ──────────────────────────────────────
    const fetchReport = useCallback(async (analysisId, attempt) => {
        if (attempt > MAX_POLLS) {
            setError({
                title: 'Zaman aşımı',
                message: 'VirusTotal analizi çok uzun sürdü. Lütfen daha sonra tekrar deneyin.',
            });
            setUiState(STATE.ERROR);
            return;
        }

        try {
            abortRef.current = new AbortController();
            const res = await fetch(
                `${API_BASE}/api/scan/report/${analysisId}`,
                { signal: abortRef.current.signal }
            );
            const json = await res.json();

            if (!res.ok || !json.success) {
                throw new Error(json?.message || `HTTP ${res.status}`);
            }

            const vtStatus = json.report?.status;

            if (vtStatus === 'completed') {
                const vtReport = json.report;
                setReport(vtReport);
                setUiState(STATE.DONE);

                // ── Verdict toast ─────────────────────────────────────────
                if (vtReport.verdict === 'malicious') {
                    toast.error('🚨 Kritik tehdit tespit edildi! Bu içerik zararlı.', { duration: 7000 });
                } else if (vtReport.verdict === 'suspicious') {
                    toast('⚠️ Şüpheli içerik tespit edildi. Dikkatli olun.', {
                        duration: 5000,
                        icon: '⚠️',
                        style: { borderLeft: '4px solid #f59e0b' },
                    });
                } else {
                    toast.success('✅ İçerik temiz görünüyor.', { duration: 4000 });
                }
            } else {
                // queued | in-progress → keep polling
                setPollCount(attempt);
                pollTimerRef.current = setTimeout(
                    () => fetchReport(analysisId, attempt + 1),
                    POLL_INTERVAL
                );
            }
        } catch (err) {
            if (err.name === 'AbortError') return; // intentional cancel
            console.error('[ScanPage] Poll error:', err.message);
            toast.error('Rapor alınamadı: ' + (err.message || 'Sunucu yanıt vermedi.'), { duration: 5000 });
            setError({
                title: 'Rapor alınamadı',
                message: err.message || 'Sunucu yanıt vermedi.',
            });
            setUiState(STATE.ERROR);
        }
    }, []);

    // ── Upload / Scan ─────────────────────────────────────────────
    const handleScan = async () => {
        if (activeTab === 'file' && !file) return;
        if (activeTab === 'url' && !urlInput.trim()) return;
        if (activeTab === 'text' && !textInput.trim() && !ssFile) return;

        setUiState(STATE.UPLOADING);
        setError(null);
        setReport(null);
        setPollCount(0);

        // ── Loading toast ────────────────────────────────────────────
        const loadingToastId = toast.loading(
            activeTab === 'text' ? '🤖 Yapay zeka analiz ediyor…' :
            activeTab === 'url'  ? '🔍 URL taranıyor…' :
                                   '📄 Dosya yükleniyor…',
            { duration: Infinity }
        );

        try {
            abortRef.current = new AbortController();
            let res;
            const { data: { user } } = await supabase.auth.getUser();
            const userId = user?.id || '';

            if (activeTab === 'file') {
                const formData = new FormData();
                formData.append('file', file);
                formData.append('user_id', userId);
                res = await fetch(`${API_BASE}/api/scan/upload`, {
                    method: 'POST',
                    body: formData,
                    signal: abortRef.current.signal,
                });
            } else if (activeTab === 'url') {
                res = await fetch(`${API_BASE}/api/scan/url`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ url: urlInput.trim(), user_id: userId }),
                    signal: abortRef.current.signal,
                });
            } else if (activeTab === 'text') {
                const formData = new FormData();
                if (textInput.trim()) formData.append('text', textInput.trim());
                if (ssFile) formData.append('image', ssFile);

                res = await fetch(`${API_BASE}/api/scan/text`, {
                    method: 'POST',
                    body: formData,
                    signal: abortRef.current.signal,
                });
            }

            const json = await res.json();

            if (!res.ok || !json.success) {
                throw new Error(json?.message || `HTTP ${res.status} — Bilinmeyen hata.`);
            }

            const data = json.data;

            // ── Text sekme: mode'a göre farklı akış ──────────────────────────
            if (activeTab === 'text') {
                // Gemini analysis completes immediately (no polling)
                setUploadData({
                    ...data,
                    url: null,
                    fileName: data.fileName ?? null,
                });
                setReport({
                    status: 'completed',
                    isGemini: true,
                    aiReport: data.report,
                    // Backend'den gelen server-side parse sonuçları
                    backendRiskScore:  data.risk_score   ?? null,
                    backendRiskLevel:  data.risk_level   ?? null,
                    backendVerdict:    data.verdict      ?? null,
                });
                setUiState(STATE.DONE);

                // Insert into Supabase 'scans' table
                try {
                    const { data: { user } } = await supabase.auth.getUser();
                    if (user) {
                        let riskVerdict = 'unknown';
                        const lowerVt = data.report?.toLowerCase() || '';
                        if (lowerVt.includes('kritik') || lowerVt.includes('yüksek')) {
                            riskVerdict = 'malicious';
                        } else if (lowerVt.includes('orta') || lowerVt.includes('şüpheli')) {
                            riskVerdict = 'suspicious';
                        } else if (lowerVt.includes('düşük') || lowerVt.includes('temiz')) {
                            riskVerdict = 'clean';
                        }

                        await supabase.from('scans').insert([
                            { 
                                user_id: user.id,
                                file_name: textInput ? textInput.substring(0, 100) : "Yapay Zeka Analizi", 
                                file_size: ssFile ? ssFile.size : 0, 
                                analysis_id: `ai_scan_${Date.now()}_${Math.random().toString(36).substring(7)}`, 
                                status: 'completed',
                                verdict: riskVerdict,
                                stats: { report_content: data.report },
                                type: ssFile ? 'image' : 'text'
                            }
                        ]);

                        // ── Dashboard notification toast ────────────────────────
                        toast('📊 Tarama Dashboard\'a eklendi.', {
                            duration: 3500,
                            icon: '📊',
                        });
                    }
                } catch (dbErr) {
                    console.error("Supabase Kayıt Hatası:", dbErr);
                }

                return; // handleScan bitti
            }

            // ── Dosya / URL sekmeleri: normalleştirilmiş uploadData + polling ─
            setUploadData({
                ...data,
                url: data.url ?? null,
                fileName: data.fileName ?? null,
            });

            // ── Dismiss loading, kick off polling ────────────────────────
            toast.dismiss(loadingToastId);
            toast('⏳ VirusTotal analiz ediyor, sonuç bekleniyor…', {
                duration: 4000,
                icon: '⏳',
            });
            setUiState(STATE.POLLING);
            fetchReport(data.analysisId, 1);

        } catch (err) {
            if (err.name === 'AbortError') return;
            console.error('[ScanPage] Upload error:', err.message);
            toast.dismiss(loadingToastId);
            toast.error(err.message || 'Sunucuya bağlanılamadı.', { duration: 5000 });
            setError({
                title: 'Analiz başlatılamadı',
                message: err.message || 'Sunucuya bağlanılamadı. Backend API bulunamıyor olabilir.',
            });
            setUiState(STATE.IDLE);
        }
    };

    const getScanButtonText = () => {
        if (activeTab === 'file') return 'Tara';
        if (activeTab === 'url') return "URL'yi Tara";
        return 'Analiz Et';
    };

    const getLoadingText = () => {
        if (activeTab === 'file') return 'Dosya yükleniyor…';
        if (activeTab === 'url') return 'URL analiz ediliyor…';
        return 'Veri işleniyor…';
    };

    // ── Render ─────────────────────────────────────────────
    return (
        <div className="scan-page">

            {/* Header */}
            <header className="scan-page__header">
                <div className="scan-page__logo">
                    <ShieldIcon size={44} className="scan-page__logo-icon" />
                    <span className="scan-page__logo-text">CyberCheck</span>
                </div>
                <p className="scan-page__tagline">Tehdit İstihbarat Platformu</p>
            </header>

            {/* Main card */}
            <main className="scan-page__card" aria-label="Tarama paneli">

                {/* ── DONE: Final verdict ── */}
                {uiState === STATE.DONE && report ? (
                    <VerdictReport
                        report={report}
                        uploadData={uploadData}
                        onReset={handleReset}
                    />
                ) : (
                    <>
                        {/* Tabs (Hide when polling/uploading) */}
                        {(uiState === STATE.IDLE || uiState === STATE.ERROR) && (
                            <div className="scan-tabs" role="tablist" aria-label="Tarama türü seçimi">
                                <button
                                    role="tab"
                                    aria-selected={activeTab === 'file'}
                                    className={`scan-tab ${activeTab === 'file' ? 'scan-tab--active' : ''}`}
                                    onClick={() => {
                                        setActiveTab('file');
                                        setError(null);
                                    }}
                                    title="Dosya Tarama"
                                >
                                    📄 <span style={{ display: 'none' }} className="mobile-hide">Dosya</span>
                                </button>
                                <button
                                    role="tab"
                                    aria-selected={activeTab === 'url'}
                                    className={`scan-tab ${activeTab === 'url' ? 'scan-tab--active' : ''}`}
                                    onClick={() => {
                                        setActiveTab('url');
                                        setError(null);
                                    }}
                                    title="URL Tarama"
                                >
                                    🔗 <span style={{ display: 'none' }} className="mobile-hide">URL</span>
                                </button>
                                <button
                                    role="tab"
                                    aria-selected={activeTab === 'text'}
                                    className={`scan-tab ${activeTab === 'text' ? 'scan-tab--active' : ''}`}
                                    onClick={() => {
                                        setActiveTab('text');
                                        setError(null);
                                    }}
                                    title="Metin / SS Analizi"
                                >
                                    📧 Metin / SS Analizi
                                </button>
                            </div>
                        )}

                        {/* Error banner */}
                        {error && (
                            <ErrorBanner
                                title={error.title}
                                message={error.message}
                                onDismiss={() => {
                                    setError(null);
                                    if (uiState === STATE.ERROR) setUiState(STATE.IDLE);
                                }}
                            />
                        )}

                        {/* Dynamic Input Zone — hide while polling/uploading */}
                        {(uiState === STATE.IDLE || uiState === STATE.ERROR) && (
                            <>
                                {activeTab === 'file' && (
                                    <>
                                        <p className="scan-page__section-label">Dosya Seçin</p>
                                        <DropZone
                                            file={file}
                                            onFile={handleFile}
                                            onClear={handleReset}
                                        />
                                    </>
                                )}

                                {activeTab === 'url' && (
                                    <div className="url-input-container">
                                        <p className="scan-page__section-label">Bağlantı Adresi (URL) veya IP</p>
                                        <div className="url-input-wrap">
                                            <input
                                                type="text"
                                                className="url-input"
                                                placeholder="Şüpheli linki veya IP adresini buraya yapıştırın..."
                                                value={urlInput}
                                                onChange={(e) => setUrlInput(e.target.value)}
                                            />
                                            <LinkIcon />
                                        </div>
                                    </div>
                                )}

                                {activeTab === 'text' && (
                                    <div className="text-analysis-container">
                                        <p className="scan-page__section-label">Şüpheli İçerik Analizi</p>

                                        {/* Text Input */}
                                        <div className="text-input-wrap">
                                            <textarea
                                                className="text-input"
                                                placeholder="Şüpheli e-posta metnini veya mesajı buraya yapıştırın..."
                                                value={textInput}
                                                onChange={(e) => setTextInput(e.target.value)}
                                            />
                                            <TextIcon />
                                        </div>

                                        {/* SS Upload Zone */}
                                        {ssFile ? (
                                            <div className="ss-upload-zone ss-upload-zone--has-file">
                                                <ImageIcon />
                                                <span className="ss-upload-zone__text" title={ssFile.name}>
                                                    {ssFile.name}
                                                </span>
                                                <button
                                                    type="button"
                                                    className="ss-upload-zone__clear"
                                                    onClick={() => setSsFile(null)}
                                                    aria-label="Dosyayı kaldır"
                                                >
                                                    ✖ Sil
                                                </button>
                                            </div>
                                        ) : (
                                            <label className="ss-upload-zone" aria-label="Ekran görüntüsü yükle">
                                                <ImageIcon />
                                                <span className="ss-upload-zone__text">
                                                    Veya OCR için bir ekran görüntüsü (SS) yükleyin
                                                </span>
                                                <input
                                                    type="file"
                                                    accept="image/*"
                                                    className="ss-upload-zone__input"
                                                    onChange={handleSsFile}
                                                />
                                            </label>
                                        )}
                                    </div>
                                )}
                            </>
                        )}

                        {/* Uploading spinner */}
                        {uiState === STATE.UPLOADING && (
                            <div className="loading-state" role="status" aria-live="polite">
                                <div className="loading-state__ring" aria-hidden="true" />
                                <p className="loading-state__text">{getLoadingText()}</p>
                                <p className="loading-state__sub">
                                    {activeTab === 'text' ? 'Tehdit algoritmaları çalıştırılıyor...' : 'VirusTotal\'e gönderiliyor, lütfen bekleyin.'}
                                </p>
                            </div>
                        )}

                        {/* Polling radar */}
                        {uiState === STATE.POLLING && (
                            <PollingState pollCount={pollCount} />
                        )}

                        {/* Scan button */}
                        {((activeTab === 'file' && file) ||
                            (activeTab === 'url' && urlInput.trim()) ||
                            (activeTab === 'text' && (textInput.trim() || ssFile))
                        ) && uiState === STATE.IDLE && (
                                <>
                                    <div className="divider" />
                                    <button
                                        id="btn-scan"
                                        className="btn-scan"
                                        onClick={handleScan}
                                        aria-label="Taramayı başlat"
                                    >
                                        <ScanIcon />
                                        {getScanButtonText()}
                                    </button>
                                </>
                            )}

                        {/* New scan button when error/timeout occurred during polling */}
                        {(uiState === STATE.ERROR) && (
                            <>
                                <div className="divider" />
                                <button
                                    id="btn-new-scan-error"
                                    className="btn-new-scan"
                                    onClick={handleReset}
                                >
                                    <RefreshIcon />
                                    Yeni Tarama
                                </button>
                            </>
                        )}
                    </>
                )}
            </main>

            {/* Footer */}
            <p className="scan-page__footer-note">
                <LockIcon />
                {activeTab === 'file' ? 'Dosyalar yalnızca bellekte işlenir — diske kaydedilmez.' : 'Tüm taramalar şifrelenerek güvenlik motorlarına iletilir.'}
            </p>
        </div>
    );
}

// ── PollingState ──────────────────────────────────────────────

function PollingState({ pollCount }) {
    return (
        <div className="polling-state" role="status" aria-live="polite">
            {/* Radar */}
            <div className="radar" aria-hidden="true">
                <div className="radar__ring" />
                <div className="radar__ring" />
                <div className="radar__ring" />
                <div className="radar__sweep" />
                <div className="radar__dot" />
                <div className="radar__shield">
                    <ShieldIcon size={28} />
                </div>
            </div>

            <p className="polling-state__title">
                Güvenlik motorları analiz ediyor
            </p>
            <p className="polling-state__sub">
                Lütfen bekleyin{' '}
                <span className="polling-state__dots" aria-hidden="true">
                    <span>.</span><span>.</span><span>.</span>
                </span>
                {pollCount > 1 && (
                    <span style={{ marginLeft: 8, color: 'var(--text-muted)' }}>
                        ({pollCount * 3}s)
                    </span>
                )}
            </p>
        </div>
    );
}

// ── VerdictReport ─────────────────────────────────────────────

function VerdictReport({ report, uploadData, onReset }) {
    const reportRef = useRef(null);

    if (report.isGemini) {
        return (
            <GeminiReport
                report={report}
                uploadData={uploadData}
                onReset={onReset}
                reportRef={reportRef}
            />
        );
    }

    const { verdict, stats, status, date } = report;
    const { malicious, suspicious, harmless, undetected, total } = stats ?? {};

    const isThreat = verdict === 'malicious' || verdict === 'suspicious';
    const variantKey = isThreat ? 'threat' : 'clean';

    // Proportional bar widths (guard against 0 total)
    const pct = (n) => (total > 0 ? Math.round((n / total) * 100) : 0);

    return (
        <>
            {/* Verdict hero */}
            <div className="verdict-hero">
                <div className={`verdict-hero__icon-wrap verdict-hero__icon-wrap--${variantKey}`}>
                    <div className={`verdict-hero__icon verdict-hero__icon--${variantKey}`}>
                        {isThreat ? <AlertTriangleIcon /> : <CheckIcon />}
                    </div>
                </div>

                <p className={`verdict-hero__label verdict-hero__label--${variantKey}`}>
                    {verdict === 'malicious' && '⚠️ Tehlikeli İçerik Tespit Edildi'}
                    {verdict === 'suspicious' && '⚠️ Şüpheli İçerik Tespit Edildi'}
                    {verdict === 'clean' && '✅ İçerik Temiz'}
                </p>

                <p className="verdict-hero__sub">
                    {verdict === 'malicious' &&
                        'Bu analiz birden fazla antivirüs motoru tarafından zararlı olarak işaretlendi. Dikkatli olun.'}
                    {verdict === 'suspicious' &&
                        'Bu analiz bazı motorlar tarafından şüpheli bulundu. Dikkatli olun.'}
                    {verdict === 'clean' &&
                        'Hiçbir motor bu analizi tehdit olarak işaretlemedi. Görünürde güvenli.'}
                </p>
            </div>

            <div className="divider" />

            {/* Stats grid */}
            <div className="stats-grid">
                <StatCell
                    variant="malicious"
                    label="Zararlı"
                    value={malicious ?? 0}
                    pct={pct(malicious)}
                />
                <StatCell
                    variant="suspicious"
                    label="Şüpheli"
                    value={suspicious ?? 0}
                    pct={pct(suspicious)}
                />
                <StatCell
                    variant="harmless"
                    label="Temiz"
                    value={harmless ?? 0}
                    pct={pct(harmless)}
                />
                <StatCell
                    variant="undetected"
                    label="Tespit Edilmedi"
                    value={undetected ?? 0}
                    pct={pct(undetected)}
                />
            </div>

            {/* File & analysis meta */}
            <div className="report-meta">
                {uploadData?.fileName && (
                    <div className="report-meta__row">
                        <span className="report-meta__label">Hedef</span>
                        <span className="report-meta__value" title={uploadData.fileName}>
                            {uploadData.fileName}
                        </span>
                    </div>
                )}
                {uploadData?.url && (
                    <div className="report-meta__row">
                        <span className="report-meta__label">Taranan URL</span>
                        <span className="report-meta__value" title={uploadData.url}>
                            {uploadData.url}
                        </span>
                    </div>
                )}
                {uploadData?.fileSizeBytes != null && (
                    <div className="report-meta__row">
                        <span className="report-meta__label">Boyut</span>
                        <span className="report-meta__value">
                            {formatBytes(uploadData.fileSizeBytes)}
                        </span>
                    </div>
                )}
                <div className="report-meta__row">
                    <span className="report-meta__label">Toplam Motor</span>
                    <span className="report-meta__value">{total ?? '—'}</span>
                </div>
                {uploadData?.analysisId && (
                    <div className="report-meta__row">
                        <span className="report-meta__label">Analiz ID</span>
                        <span className="report-meta__value" title={uploadData.analysisId}>
                            {truncateId(uploadData.analysisId)}
                        </span>
                    </div>
                )}
                {date && (
                    <div className="report-meta__row">
                        <span className="report-meta__label">Tarih</span>
                        <span className="report-meta__value">
                            {new Date(date).toLocaleString('tr-TR')}
                        </span>
                    </div>
                )}
            </div>

            {/* New scan button */}
            <button
                id="btn-new-scan"
                className="btn-new-scan"
                onClick={onReset}
                aria-label="Yeni tarama başlat"
            >
                <RefreshIcon />
                Yeni Tarama
            </button>
        </>
    );
}

// ── StatCell ──────────────────────────────────────────────────

function StatCell({ variant, label, value, pct }) {
    return (
        <div className={`stat-cell stat-cell--${variant}`}>
            <span className="stat-cell__label">{label}</span>
            <span className="stat-cell__value">{value}</span>
            <div className="stat-cell__bar">
                <div
                    className="stat-cell__bar-fill"
                    style={{ width: `${pct}%` }}
                    role="progressbar"
                    aria-valuenow={value}
                    aria-valuemin={0}
                    aria-valuemax={100}
                />
            </div>
        </div>
    );
}

// ══════════════════════════════════════════════════════════════
// ── Gemini AI Rapor Bileşeni (infografik tasarım) ─────────────
// ══════════════════════════════════════════════════════════════

/**
 * Gemini'nin döndürdüğü uzun ham metni 4 mantıksal bölüme ayırır.
 * Döndürdüğü nesne: { riskLevel, riskVariant, tactics, detailedAnalysis, advice, raw }
 */
function parseGeminiReport(text) {
    if (!text) return { riskLevel: 'Bilinmiyor', riskVariant: 'unknown', tactics: [], detailedAnalysis: '', advice: '', raw: '' };

    const lower = text.toLowerCase();

    // ── Risk seviyesi tespiti ───────────────────────────────────────────
    let riskLevel = 'Bilinmiyor';
    let riskVariant = 'unknown';
    if (lower.includes('kritik'))       { riskLevel = 'Kritik';    riskVariant = 'critical'; }
    else if (lower.includes('yüksek')) { riskLevel = 'Yüksek';    riskVariant = 'high'; }
    else if (lower.includes('orta'))   { riskLevel = 'Orta';      riskVariant = 'medium'; }
    else if (lower.includes('düşük'))  { riskLevel = 'Düşük';     riskVariant = 'low'; }

    // ── Taktik çıkarma: önce Gemini bölümü, sonra keyword taraması ─────
    const tactics = new Set();

    // 1) "Tespit Edilen Taktikler" veya "2." bölümünü bul
    const sectionRe = /(?:tespit edilen taktikler|detected tactics|2\.)([\s\S]*?)(?:\n\s*\n|\n\s*\d\.|\n##|\n\*\*\d|$)/i;
    const sectionMatch = sectionRe.exec(text);
    if (sectionMatch) {
        const body = sectionMatch[1];
        body.split('\n').forEach(line => {
            const clean = line.replace(/^[\s\-•*\d.]+/, '').replace(/\*\*/g, '').trim();
            if (clean.length > 2 && clean.length < 70) tactics.add(clean);
        });
    }

    // 2) Keyword taraması (fallback + ek taktikler)
    const kwMap = {
        'phishing':           '🎣 Kimlik Avı',
        'kimlik avı':         '🎣 Kimlik Avı',
        'sosyal mühendislik': '🧠 Sosyal Mühendislik',
        'social engineering': '🧠 Sosyal Mühendislik',
        'aciliyet':           '⏰ Aciliyet Hissi',
        'urgency':            '⏰ Aciliyet Hissi',
        'sahte':              '🎭 Sahte İçerik',
        'otorite':            '🎭 Otorite Taklidi',
        'parola':             '🔓 Parola Çalma',
        'şifre':              '🔓 Parola Çalma',
        'credential':         '🔓 Kimlik Bilgisi',
        'malware':            '🦠 Kötü Amaçlı Yazılım',
        'kötü amaçlı':       '🦠 Kötü Amaçlı Yazılım',
        'ransomware':         '🔒 Fidye Yazılımı',
        'trojan':             '🐴 Truva Atı',
        'scam':               '💸 Dolandırıcılık',
        'spam':               '📧 Spam',
        'backdoor':           '🚪 Arka Kapı',
        'exploit':            '⚡ Güvenlik Açığı',
        'spyware':            '👁️ Casus Yazılım',
    };
    Object.entries(kwMap).forEach(([kw, label]) => {
        if (lower.includes(kw)) tactics.add(label);
    });

    // ── Detaylı Analiz bölümü ───────────────────────────────────────────
    const detailedRe = /(?:detayl[ıi]\s*analiz|detailed analysis|3\.)([\s\S]*?)(?:\n\s*\n(?=\s*(?:\d+\.|##|\*\*\d))|\n##|\nkullan[ıi]c[ıi]ya|\n4\.|$)/i;
    const detailedMatch = detailedRe.exec(text);
    const detailedAnalysis = detailedMatch ? detailedMatch[1].trim() : '';

    // ── Tavsiye bölümü ──────────────────────────────────────────────────
    const adviceRe = /(?:kullan[ıi]c[ıi]ya\s*tavsiye|öneri|recommendation|4\.)([\s\S]*?)$/i;
    const adviceMatch = adviceRe.exec(text);
    const advice = adviceMatch ? adviceMatch[1].trim() : '';

    return {
        riskLevel,
        riskVariant,
        tactics: Array.from(tactics).slice(0, 12), // max 12 rozet
        detailedAnalysis,
        advice,
        raw: text,
    };
}

/** Risk seviyesine göre CSS renk token'ı döndürür */
const RISK_STYLES = {
    critical: {
        border: 'rgba(239,68,68,0.5)',
        glow:   'rgba(239,68,68,0.2)',
        bg:     'rgba(239,68,68,0.08)',
        text:   '#ef4444',
        badge:  'rgba(239,68,68,0.15)',
        label:  '⚠️ Kritik Risk Tespit Edildi!',
    },
    high: {
        border: 'rgba(239,68,68,0.4)',
        glow:   'rgba(239,68,68,0.15)',
        bg:     'rgba(239,68,68,0.06)',
        text:   '#f87171',
        badge:  'rgba(239,68,68,0.12)',
        label:  '⚠️ Yüksek Risk Tespit Edildi',
    },
    medium: {
        border: 'rgba(245,158,11,0.4)',
        glow:   'rgba(245,158,11,0.15)',
        bg:     'rgba(245,158,11,0.06)',
        text:   '#f59e0b',
        badge:  'rgba(245,158,11,0.12)',
        label:  '⚠️ Orta Düzey Risk Tespit Edildi',
    },
    low: {
        border: 'rgba(16,185,129,0.4)',
        glow:   'rgba(16,185,129,0.15)',
        bg:     'rgba(16,185,129,0.06)',
        text:   '#10b981',
        badge:  'rgba(16,185,129,0.12)',
        label:  '✅ İçerik Temiz Görünüyor',
    },
    unknown: {
        border: 'rgba(148,163,184,0.25)',
        glow:   'rgba(148,163,184,0.08)',
        bg:     'rgba(148,163,184,0.04)',
        text:   '#94a3b8',
        badge:  'rgba(148,163,184,0.1)',
        label:  'Yapay Zeka Analiz Raporu',
    },
};

/** Tek bir akordeon (HTML details + summary) */
function AccordionSection({ icon, title, subtitle, children }) {
    return (
        <details className="gemini-accordion" style={{
            background: 'rgba(15,22,41,0.7)',
            border: '1px solid rgba(148,163,184,0.12)',
            borderRadius: 14,
            overflow: 'hidden',
            marginBottom: 12,
        }}>
            <summary style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                padding: '16px 20px',
                cursor: 'pointer',
                listStyle: 'none',
                userSelect: 'none',
            }}>
                {/* İkon kutusu */}
                <span style={{
                    width: 38, height: 38,
                    borderRadius: 10,
                    background: 'rgba(59,130,246,0.1)',
                    border: '1px solid rgba(59,130,246,0.2)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 18, flexShrink: 0,
                }}>{icon}</span>

                {/* Metin */}
                <span style={{ flex: 1 }}>
                    <span style={{ display: 'block', fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-primary)' }}>
                        {title}
                    </span>
                    <span style={{ display: 'block', fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: 2 }}>
                        {subtitle}
                    </span>
                </span>

                {/* Ok ikonu (CSS ile döner) */}
                <span className="accordion-chevron" style={{
                    width: 28, height: 28,
                    borderRadius: '50%',
                    background: 'rgba(59,130,246,0.08)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                    transition: 'transform 250ms ease',
                    fontSize: 13,
                    color: 'var(--accent-primary)',
                }}>▾</span>
            </summary>

            <div style={{
                padding: '4px 20px 20px',
                borderTop: '1px solid rgba(148,163,184,0.08)',
                animation: 'fadeIn 200ms ease',
            }}>
                {children}
            </div>
        </details>
    );
}

/** Gemini metninin bir bölümünü satır satır işleyip render eder */
function SectionRenderer({ text, accentColor }) {
    if (!text) return (
        <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', padding: '8px 0' }}>
            Bu bölüm için içerik mevcut değil.
        </p>
    );

    const lines = text.split('\n');
    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 8 }}>
            {lines.map((line, i) => {
                const trimmed = line.trim();
                if (!trimmed) return <div key={i} style={{ height: 6 }} />;

                // Sayılı madde: "1. " veya "2. "
                const numMatch = trimmed.match(/^(\d+)\.\s+(.+)/);
                if (numMatch) {
                    const body = numMatch[2].replace(/\*\*/g, '');
                    return (
                        <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '3px 0' }}>
                            <span style={{
                                minWidth: 24, height: 24,
                                borderRadius: '50%',
                                background: `${accentColor}20`,
                                border: `1px solid ${accentColor}40`,
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                fontSize: '0.7rem', fontWeight: 800, color: accentColor,
                                flexShrink: 0, marginTop: 1,
                            }}>{numMatch[1]}</span>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.65 }}>{body}</span>
                        </div>
                    );
                }

                // Madde imi: "- " veya "• "
                if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
                    const body = trimmed.substring(2).replace(/\*\*/g, '');
                    return (
                        <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '2px 0' }}>
                            <span style={{
                                width: 6, height: 6, borderRadius: '50%',
                                background: accentColor,
                                boxShadow: `0 0 6px ${accentColor}80`,
                                flexShrink: 0, marginTop: 8,
                            }} />
                            <span style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.65 }}>{body}</span>
                        </div>
                    );
                }

                // ## Başlık
                if (trimmed.startsWith('## ')) {
                    return (
                        <p key={i} style={{
                            fontWeight: 700, fontSize: '0.9rem',
                            color: accentColor, marginTop: 12, marginBottom: 2,
                        }}>{trimmed.substring(3).replace(/\*\*/g, '')}</p>
                    );
                }

                // Normal metin
                return (
                    <p key={i} style={{
                        color: 'var(--text-secondary)', fontSize: '0.88rem',
                        lineHeight: 1.65,
                    }}>{trimmed.replace(/\*\*/g, '')}</p>
                );
            })}
        </div>
    );
}

/** Ana Gemini infografik rapor bileşeni */
function GeminiReport({ report, uploadData, onReset, reportRef }) {
    const aiText  = report.aiReport || '';
    const parsed  = parseGeminiReport(aiText);

    // ── Backend'den gelen kesin risk değerleri varsa override et ──────────────
    // Bu sayede web ve mobil her zaman aynı sonucu gösterir.
    if (report.backendRiskLevel) {
        const lvl = report.backendRiskLevel.toLowerCase();
        if (lvl === 'kritik')                       { parsed.riskLevel = 'Kritik';    parsed.riskVariant = 'critical'; }
        else if (lvl === 'yüksek')                  { parsed.riskLevel = 'Yüksek';    parsed.riskVariant = 'high'; }
        else if (lvl === 'orta')                    { parsed.riskLevel = 'Orta';      parsed.riskVariant = 'medium'; }
        else if (lvl === 'düşük')                   { parsed.riskLevel = 'Düşük';     parsed.riskVariant = 'low'; }
        else if (lvl === 'temiz' || lvl === 'güvenli') { parsed.riskLevel = 'Temiz';  parsed.riskVariant = 'low'; }
    }
    // Eğer backend verdict varsa ve riskVariant hâlâ 'unknown'sa, verdict'ten türet
    if (parsed.riskVariant === 'unknown' && report.backendVerdict) {
        if (report.backendVerdict === 'malicious')  { parsed.riskVariant = 'critical'; parsed.riskLevel = 'Yüksek'; }
        else if (report.backendVerdict === 'suspicious') { parsed.riskVariant = 'medium'; parsed.riskLevel = 'Orta'; }
        else if (report.backendVerdict === 'clean') { parsed.riskVariant = 'low';  parsed.riskLevel = 'Temiz'; }
    }

    const st = RISK_STYLES[parsed.riskVariant] || RISK_STYLES.unknown;

    const handleDownloadPDF = () => window.print();

    // Fallback: bölüm metni yoksa ham metni kullan
    const analysisText = parsed.detailedAnalysis || aiText;
    const adviceText   = parsed.advice || aiText;

    return (
        <div className="verdict-report-wrapper">
            <div
                id="pdf-report-container"
                ref={reportRef}
                className="pdf-target-container"
                style={{ padding: '20px 24px', borderRadius: 16 }}
            >

                {/* ════════════════════════════════════════════════════
                    BÖLÜM 1 — Risk Skoru Gauge (büyük, renkli, dairesel)
                ════════════════════════════════════════════════════ */}
                <div style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: 16,
                    padding: '28px 24px',
                    background: st.bg,
                    border: `1px solid ${st.border}`,
                    borderRadius: 20,
                    boxShadow: `0 0 48px ${st.glow}`,
                    marginBottom: 20,
                }}>

                    {/* Dairesel risk göstergesi */}
                    <div style={{
                        position: 'relative',
                        width: 160, height: 160,
                        borderRadius: '50%',
                        background: `conic-gradient(${st.text} 0%, ${st.text} ${
                            parsed.riskVariant === 'critical' ? '90%' :
                            parsed.riskVariant === 'high'     ? '72%' :
                            parsed.riskVariant === 'medium'   ? '50%' :
                            parsed.riskVariant === 'low'      ? '20%' : '35%'
                        }, rgba(30,41,59,0.6) 0%)`,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        boxShadow: `0 0 36px ${st.glow}, inset 0 0 24px rgba(5,8,16,0.8)`,
                    }}>
                        {/* İç daire (beyaz yüzey) */}
                        <div style={{
                            position: 'absolute',
                            width: 124, height: 124,
                            borderRadius: '50%',
                            background: 'var(--bg-elevated)',
                            display: 'flex', flexDirection: 'column',
                            alignItems: 'center', justifyContent: 'center',
                            gap: 2,
                        }}>
                            {/* İkon */}
                            <span style={{ fontSize: 26 }}>
                                {parsed.riskVariant === 'low' ? '✅' : parsed.riskVariant === 'unknown' ? '🤖' : '⚠️'}
                            </span>
                            {/* Risk seviyesi metni */}
                            <span style={{
                                fontWeight: 900,
                                fontSize: '1.35rem',
                                color: st.text,
                                lineHeight: 1,
                                textShadow: `0 0 16px ${st.text}`,
                                letterSpacing: '-0.5px',
                            }}>{parsed.riskLevel}</span>
                            <span style={{ fontSize: '0.65rem', color: 'var(--text-muted)', letterSpacing: '0.04em' }}>RİSK SEVİYESİ</span>
                        </div>
                    </div>

                    {/* Durum etiketi rozeti */}
                    <div style={{
                        padding: '8px 24px',
                        borderRadius: 30,
                        background: st.badge,
                        border: `1px solid ${st.border}`,
                        color: st.text,
                        fontWeight: 700,
                        fontSize: '0.95rem',
                        letterSpacing: '0.03em',
                    }}>{st.label}</div>

                    {/* Hedef bilgisi */}
                    {(uploadData?.fileName || uploadData?.url) && (
                        <div style={{
                            display: 'flex', alignItems: 'center', gap: 8,
                            padding: '8px 16px',
                            background: 'rgba(15,22,41,0.6)',
                            borderRadius: 10,
                            border: '1px solid rgba(148,163,184,0.1)',
                            maxWidth: '100%',
                        }}>
                            <span style={{ fontSize: 13, opacity: 0.6 }}>🎯</span>
                            <span style={{
                                fontFamily: 'JetBrains Mono, monospace',
                                fontSize: '0.75rem',
                                color: 'var(--text-secondary)',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                                whiteSpace: 'nowrap',
                                maxWidth: 320,
                            }} title={uploadData?.url || uploadData?.fileName}>
                                {uploadData?.url || uploadData?.fileName}
                            </span>
                        </div>
                    )}
                </div>

                {/* ════════════════════════════════════════════════════
                    BÖLÜM 2 — Taktik Rozetleri (Wrap + Badge)
                ════════════════════════════════════════════════════ */}
                {parsed.tactics.length > 0 && (
                    <div style={{
                        padding: '16px 20px',
                        background: 'rgba(15,22,41,0.7)',
                        border: '1px solid rgba(148,163,184,0.12)',
                        borderRadius: 14,
                        marginBottom: 12,
                    }}>
                        {/* Başlık */}
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
                            <span style={{
                                width: 30, height: 30, borderRadius: 8,
                                background: `${st.text}18`,
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                fontSize: 15,
                            }}>🎯</span>
                            <span style={{ fontWeight: 700, fontSize: '0.8rem', color: 'var(--text-secondary)', letterSpacing: '0.07em', textTransform: 'uppercase' }}>
                                Tespit Edilen Taktikler
                            </span>
                            <span style={{
                                marginLeft: 'auto',
                                padding: '2px 10px',
                                borderRadius: 12,
                                background: `${st.text}18`,
                                color: st.text,
                                fontSize: '0.75rem',
                                fontWeight: 700,
                            }}>{parsed.tactics.length}</span>
                        </div>

                        {/* Rozet'ler */}
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                            {parsed.tactics.map((tactic, idx) => (
                                <span key={idx} style={{
                                    padding: '5px 12px',
                                    borderRadius: 20,
                                    background: `${st.text}12`,
                                    border: `1px solid ${st.text}35`,
                                    color: st.text,
                                    fontSize: '0.82rem',
                                    fontWeight: 600,
                                    boxShadow: `0 2px 8px ${st.text}18`,
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    gap: 4,
                                }}>
                                    {tactic}
                                </span>
                            ))}
                        </div>
                    </div>
                )}

                {/* ════════════════════════════════════════════════════
                    BÖLÜM 3 — Akordeon: Detaylı Analiz
                ════════════════════════════════════════════════════ */}
                <AccordionSection
                    icon="🔍"
                    title="Detaylı Siber Analiz Raporu"
                    subtitle="Tehdit mekanizması ve teknik bulgular — detay için tıklayın"
                >
                    <SectionRenderer text={analysisText} accentColor="#06b6d4" />
                </AccordionSection>

                {/* ════════════════════════════════════════════════════
                    BÖLÜM 4 — Akordeon: Tavsiye & Aksiyon Planı
                ════════════════════════════════════════════════════ */}
                <AccordionSection
                    icon="🛡️"
                    title="Çözüm ve Aksiyon Planı"
                    subtitle="Kullanıcıya özel koruma tavsiyeleri — detay için tıklayın"
                >
                    <SectionRenderer text={adviceText} accentColor="#3b82f6" />
                </AccordionSection>

                {/* ════════════════════════════════════════════════════
                    BÖLÜM 5 — Dosya Metadata
                ════════════════════════════════════════════════════ */}
                {uploadData?.fileName && (
                    <div className="report-meta" style={{ marginTop: 8 }}>
                        <div className="report-meta__row">
                            <span className="report-meta__label">Görsel</span>
                            <span className="report-meta__value" title={uploadData.fileName}>
                                {uploadData.fileName}
                            </span>
                        </div>
                        {uploadData?.fileSizeBytes != null && (
                            <div className="report-meta__row">
                                <span className="report-meta__label">Boyut</span>
                                <span className="report-meta__value">{formatBytes(uploadData.fileSizeBytes)}</span>
                            </div>
                        )}
                    </div>
                )}
            </div>

            {/* ── Aksiyon Butonları ── */}
            <div className="action-buttons print:hidden" style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
                <button
                    className="btn-download-pdf print:hidden"
                    onClick={handleDownloadPDF}
                    aria-label="Raporu İndir (PDF)"
                >
                    <DownloadIcon />
                    Raporu İndir (PDF)
                </button>
                <button
                    id="btn-new-scan"
                    className="btn-new-scan"
                    onClick={onReset}
                    aria-label="Yeni tarama başlat"
                >
                    <RefreshIcon />
                    Yeni Tarama
                </button>
            </div>
        </div>
    );
}
