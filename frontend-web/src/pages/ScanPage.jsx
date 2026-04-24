// pages/ScanPage.jsx
// Full scan flow: upload → polling → verdict report.

import React, { useState, useCallback, useEffect, useRef } from 'react';
import DropZone    from '../components/DropZone.jsx';
import ErrorBanner from '../components/ErrorBanner.jsx';
import '../components/ScanPage.css';

const API_BASE      = 'http://localhost:5000';
const POLL_INTERVAL = 3000; // ms between each report fetch
const MAX_POLLS     = 40;   // stop after ~2 minutes

// ── State machine ─────────────────────────────────────────────
const STATE = {
    IDLE:     'idle',      // waiting for file/url/text
    UPLOADING:'uploading', // POST in flight
    POLLING:  'polling',   // waiting for VT to finish
    DONE:     'done',      // final verdict ready
    ERROR:    'error',     // unrecoverable error
};

// ── SVG Icons ─────────────────────────────────────────────────

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
    const [activeTab,  setActiveTab]  = useState('file'); // 'file' | 'url' | 'text'
    const [file,       setFile]       = useState(null);
    const [urlInput,   setUrlInput]   = useState('');
    const [textInput,  setTextInput]  = useState('');
    const [ssFile,     setSsFile]     = useState(null);

    const [uiState,    setUiState]    = useState(STATE.IDLE);
    const [error,      setError]      = useState(null);    // { title, message }
    const [uploadData, setUploadData] = useState(null);    // { analysisId, scanId, fileName, fileSizeBytes }
    const [report,     setReport]     = useState(null);    // final VT report object
    const [pollCount,  setPollCount]  = useState(0);

    const pollTimerRef = useRef(null);
    const abortRef     = useRef(null); // AbortController for in-flight fetch

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
            const res  = await fetch(
                `${API_BASE}/api/scan/report/${analysisId}`,
                { signal: abortRef.current.signal }
            );
            const json = await res.json();

            if (!res.ok || !json.success) {
                throw new Error(json?.message || `HTTP ${res.status}`);
            }

            const vtStatus = json.report?.status;

            if (vtStatus === 'completed') {
                setReport(json.report);
                setUiState(STATE.DONE);
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
            setError({
                title: 'Rapor alınamadı',
                message: err.message || 'Sunucu yanıt vermedi.',
            });
            setUiState(STATE.ERROR);
        }
    }, []);

    // ── Upload / Scan ──────────────────────────────────────
    const handleScan = async () => {
        if (activeTab === 'file' && !file) return;
        if (activeTab === 'url' && !urlInput.trim()) return;
        if (activeTab === 'text' && !textInput.trim() && !ssFile) return;

        setUiState(STATE.UPLOADING);
        setError(null);
        setReport(null);
        setPollCount(0);

        try {
            abortRef.current = new AbortController();
            let res;

            if (activeTab === 'file') {
                const formData = new FormData();
                formData.append('file', file);
                res = await fetch(`${API_BASE}/api/scan/upload`, {
                    method: 'POST',
                    body:   formData,
                    signal: abortRef.current.signal,
                });
            } else if (activeTab === 'url') {
                res = await fetch(`${API_BASE}/api/scan/url`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ url: urlInput.trim() }),
                    signal: abortRef.current.signal,
                });
            } else if (activeTab === 'text') {
                // Future text/ss analysis endpoint
                const formData = new FormData();
                if (textInput.trim()) formData.append('text', textInput.trim());
                if (ssFile) formData.append('screenshot', ssFile);
                
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
            setUploadData(data);

            // Kick off polling immediately
            setUiState(STATE.POLLING);
            fetchReport(data.analysisId, 1);

        } catch (err) {
            if (err.name === 'AbortError') return;
            console.error('[ScanPage] Upload error:', err.message);
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
                                    📄 <span style={{display: 'none'}} className="mobile-hide">Dosya</span>
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
                                    🔗 <span style={{display: 'none'}} className="mobile-hide">URL</span>
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
                    {verdict === 'malicious'  && '⚠️ Tehlikeli İçerik Tespit Edildi'}
                    {verdict === 'suspicious' && '⚠️ Şüpheli İçerik Tespit Edildi'}
                    {verdict === 'clean'      && '✅ İçerik Temiz'}
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
