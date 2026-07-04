// controllers/scanController.js
// Orchestrates file scanning via VirusTotal and persists results to Supabase.

const { scanFileWithVirusTotal, scanUrl, getAnalysisReport, getUrlMetadata } = require('../services/virusTotalService');
const { analyzeContent } = require('../services/geminiService');
const {
    createScanRecord,
    updateScanRecord,
    getScanByAnalysisId,
    listScans,
} = require('../services/scanDatabaseService');

// ─── Helpers ─────────────────────────────────────────────────────────────────

// MIME types that map to the 'document' scan type
const DOCUMENT_MIME_TYPES = new Set([
    'application/pdf',
    'application/msword',                                                        // .doc
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',   // .docx
    'application/vnd.ms-excel',                                                  // .xls
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',         // .xlsx
    'application/vnd.ms-powerpoint',                                             // .ppt
    'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
    'text/plain',          // .txt
    'text/csv',            // .csv
    'application/rtf',     // .rtf
    'text/rtf',
]);

const determineScanType = (req) => {
    if (req.body && req.body.url) return 'url';
    if (req.file) {
        const mime = req.file.mimetype;
        if (mime.startsWith('image/'))    return 'image';
        if (DOCUMENT_MIME_TYPES.has(mime)) return 'document';
    }
    return 'text';
};

/**
 * Parses raw VirusTotal attributes into a clean, frontend-friendly summary.
 * @param {object} attributes - The `attributes` block from a VT analysis response.
 * @returns {object} Parsed summary with verdict, stats, and status.
 */
const parseVTAttributes = (attributes) => {
    const stats = attributes?.stats ?? {};
    const malicious   = stats.malicious   ?? 0;
    const suspicious  = stats.suspicious  ?? 0;
    const harmless    = stats.harmless    ?? 0;
    const undetected  = stats.undetected  ?? 0;
    const total = malicious + suspicious + harmless + undetected;

    let verdict = 'clean';
    if (malicious > 0)       verdict = 'malicious';
    else if (suspicious > 0) verdict = 'suspicious';

    return {
        status:  attributes?.status ?? 'unknown',
        verdict,
        stats:   { malicious, suspicious, harmless, undetected, total },
        date:    attributes?.date ? new Date(attributes.date * 1000).toISOString() : null,
    };
};

/**
 * Maps a VirusTotal analysis status string to our internal status enum.
 * VT statuses: 'queued' | 'in-progress' | 'completed' | 'failed'
 */
const mapVTStatus = (vtStatus) => {
    const map = {
        queued:       'queued',
        'in-progress': 'in-progress',
        completed:    'completed',
        failed:       'failed',
    };
    return map[vtStatus] ?? 'in-progress';
};

/**
 * Gemini'nin ham rapor metnini parse ederek risk seviyesi, skor ve verdict döndürür.
 *
 * Öncelik sırası:
 *   1) Gizli JSON meta: <!--RISK_JSON:{"risk_level":"Yüksek","risk_score":78}--> (yeni geminiService)
 *   2) "Risk Seviyesi: X" regex etiket
 *   3) Phishing sinyali + genel anahtar kelime taraması
 */
const _parseRiskFromReport = (report) => {
    if (!report || typeof report !== 'string') {
        return { level: 'Bilinmiyor', score: 40, verdict: 'suspicious' };
    }

    // ── 1) Gizli JSON meta (yeni geminiService tarafından eklenir) ────────────
    const jsonMetaRe = /<!--RISK_JSON:(\{[^}]+\})-->/;
    const metaMatch  = report.match(jsonMetaRe);
    if (metaMatch) {
        try {
            const meta = JSON.parse(metaMatch[1]);
            const lvl  = meta.risk_level;
            const scr  = meta.risk_score;
            if (lvl && scr) {
                const verdictMap = { 'Kritik': 'malicious', 'Yüksek': 'malicious', 'Orta': 'suspicious', 'Düşük': 'clean', 'Temiz': 'clean' };
                console.log(`[ScanController] ✅ Risk from JSON meta: ${lvl} / ${scr}`);
                return { level: lvl, score: scr, verdict: verdictMap[lvl] || 'suspicious' };
            }
        } catch (_) { /* fall through */ }
    }

    const lower = report.toLowerCase();

    // ── 2) "Risk Seviyesi: X" regex ──────────────────────────────────────────
    const riskLineRe = /risk\s+seviyesi\s*[:\-]?\s*\*{0,2}(kritik|yüksek|orta|düşük|temiz|güvenli)\*{0,2}/i;
    const match = lower.match(riskLineRe);
    if (match) {
        const lvl = match[1].toLowerCase().trim();
        if (lvl === 'kritik') return { level: 'Kritik', score: 92, verdict: 'malicious' };
        if (lvl === 'yüksek') return { level: 'Yüksek', score: 78, verdict: 'malicious' };
        if (lvl === 'orta')   return { level: 'Orta',   score: 52, verdict: 'suspicious' };
        if (lvl === 'düşük') {
            const hasPhishing = _hasPhishingSignals(lower);
            if (hasPhishing) return { level: 'Yüksek', score: 75, verdict: 'malicious' };
            return { level: 'Düşük', score: 22, verdict: 'clean' };
        }
        if (lvl === 'temiz' || lvl === 'güvenli') return { level: 'Temiz', score: 5, verdict: 'clean' };
    }

    // ── 3) Genel anahtar kelime taraması ─────────────────────────────────────
    const hasPhishing = _hasPhishingSignals(lower);
    if (lower.includes('kritik'))                              return { level: 'Kritik', score: 92, verdict: 'malicious' };
    if (lower.includes('yüksek'))                              return { level: 'Yüksek', score: 78, verdict: 'malicious' };
    if (lower.includes('orta') || lower.includes('şüpheli')) {
        return { level: 'Orta', score: hasPhishing ? 70 : 52, verdict: hasPhishing ? 'malicious' : 'suspicious' };
    }
    if (hasPhishing && lower.includes('düşük'))                return { level: 'Yüksek', score: 75, verdict: 'malicious' };
    if (lower.includes('düşük'))                               return { level: 'Düşük',  score: 22, verdict: 'clean' };
    if (lower.includes('temiz') || lower.includes('güvenli')) return { level: 'Temiz',  score: 5,  verdict: 'clean' };

    if (hasPhishing) return { level: 'Yüksek', score: 72, verdict: 'malicious' };
    return { level: 'Orta', score: 40, verdict: 'suspicious' };
};


/**
 * Rapor metninde phishing/tehdit sinyalleri var mı kontrol eder.
 */
const _hasPhishingSignals = (lowerReport) => {
    const signals = [
        'phishing', 'kimlik avı', 'oltalama', 'sahte', 'aciliyet',
        'kişisel bilgi', 'şifre', 'parola', 'kart numarası', 'tc kimlik',
        'manipülasyon', 'zararlı', 'kötü amaçlı', 'şüpheli url',
        'sahte domain', 'kimlik taklidi', 'sosyal mühendislik',
        'credential', 'hesabın askıya', 'ödül kazandın', 'hemen tıkla',
        'banka hesabı', 'doğrulama gerekli', 'urgency', 'suspicious',
        'malicious', 'fraud', 'scam',
    ];
    return signals.some(s => lowerReport.includes(s));
};

// ─── Controllers ──────────────────────────────────────────────────────────────

/**
 * POST /api/scan/upload
 * Receives an uploaded file (in RAM only), forwards it to VirusTotal,
 * creates a 'queued' DB record, and returns the analysis ID for polling.
 */
exports.uploadImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'No file uploaded or invalid file type.',
            });
        }

        const { buffer, originalname, size } = req.file;
        const userId = req.body.user_id;

        console.log(`[ScanController] Received "${originalname}" (${size} bytes). Forwarding to VirusTotal...`);

        // ── Step 1: Submit to VirusTotal ──────────────────────────────────────
        const vtResponse = await scanFileWithVirusTotal(buffer, originalname);
        const analysisId    = vtResponse?.data?.id;
        const analysisLinks = vtResponse?.data?.links;

        // ── Step 2: Persist 'queued' record to database ───────────────────────
        let dbRecord = null;
        try {
            dbRecord = await createScanRecord({
                userId,
                fileName:   originalname,
                fileSize:   size,
                analysisId,
                type:  determineScanType(req)
            });
            console.log(`[ScanController] DB record created (id=${dbRecord?.id}, analysisId=${analysisId}).`);
        } catch (dbError) {
            // DB failure must NOT abort the scan — log and continue
            console.error(`[ScanController] WARNING: Failed to save initial DB record: ${dbError.message}`);
        }

        return res.status(200).json({
            success: true,
            message: 'File successfully submitted to VirusTotal for analysis.',
            data: {
                scanId:        dbRecord?.id   ?? null,
                fileName:      originalname,
                fileSizeBytes: size,
                analysisId,
                links:         analysisLinks,
            },
        });

    } catch (error) {
        console.error('[ScanController] uploadImage error:', error.message);

        const isClientError =
            error.message.includes('rate limit') ||
            error.message.includes('authentication failed') ||
            error.message.includes('rejected the request');

        return res.status(isClientError ? 400 : 500).json({
            success: false,
            message: error.message || 'Server error during file scanning.',
        });
    }
};

/**
 * GET /api/scan/report/:id
 * Fetches a VirusTotal analysis report by ID, returns a parsed summary,
 * and updates the DB record once the analysis is completed.
 */
exports.getReport = async (req, res) => {
    const { id } = req.params;

    try {
        // ── Step 1: Fetch report from VirusTotal ──────────────────────────────
        const vtResponse = await getAnalysisReport(id);
        const attributes = vtResponse?.data?.attributes;

        if (!attributes) {
            return res.status(502).json({
                success: false,
                message: 'Unexpected response structure from VirusTotal.',
            });
        }

        const report    = parseVTAttributes(attributes);
        const vtStatus  = attributes?.status ?? 'unknown';
        const dbStatus  = mapVTStatus(vtStatus);

        // ── Step 2: Update DB record when analysis is finished ────────────────
        let dbRecord = null;
        try {
            if (vtStatus === 'completed') {
                // For URL scans: fetch enriched metadata (categories, SSL, title…)
                // in parallel — failure is non-fatal, we just omit url_meta
                let urlMeta = null;
                try {
                    // We need the original URL; it is stored in the DB file_name column
                    const existingRecord = await getScanByAnalysisId(id);
                    const isUrlScan = existingRecord?.type === 'url';
                    if (isUrlScan && existingRecord?.file_name) {
                        urlMeta = await getUrlMetadata(existingRecord.file_name);
                        if (urlMeta) {
                            console.log(`[ScanController] URL metadata enriched for analysisId=${id}.`);
                        }
                    }
                } catch (metaErr) {
                    console.warn(`[ScanController] URL metadata fetch skipped: ${metaErr.message}`);
                }

                // Merge url_meta into the stats blob
                const enrichedStats = urlMeta
                    ? { ...report.stats, url_meta: urlMeta }
                    : report.stats;

                dbRecord = await updateScanRecord({
                    analysisId: id,
                    status:     'completed',
                    verdict:    report.verdict,
                    stats:      enrichedStats,
                });
                console.log(`[ScanController] DB record updated to 'completed' (analysisId=${id}).`);
            } else if (dbStatus !== 'queued') {
                // Keep the status in sync even for intermediate states
                dbRecord = await updateScanRecord({
                    analysisId: id,
                    status:     dbStatus,
                    verdict:    null,
                    stats:      null,
                });
            }
        } catch (dbError) {
            // DB failure must NOT abort the report response — log and continue
            console.error(`[ScanController] WARNING: Failed to update DB record: ${dbError.message}`);
        }

        return res.status(200).json({
            success: true,
            analysisId: id,
            scanId:     dbRecord?.id ?? null,
            report,
        });

    } catch (error) {
        console.error('[ScanController] getReport error:', error.message);

        const isNotFound = error.message.includes('not found');
        const isClientError =
            isNotFound ||
            error.message.includes('rate limit') ||
            error.message.includes('authentication failed');

        return res.status(isNotFound ? 404 : isClientError ? 400 : 500).json({
            success: false,
            message: error.message || 'Server error while fetching report.',
        });
    }
};

/**
 * GET /api/scan/history?limit=20&offset=0
 * Returns a paginated list of past scans from the database.
 */
exports.getScanHistory = async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit  ?? '20', 10), 100);
        const offset = Math.max(parseInt(req.query.offset ?? '0',  10), 0);

        const scans = await listScans(limit, offset);

        return res.status(200).json({
            success: true,
            count:   scans.length,
            scans,
        });
    } catch (error) {
        console.error('[ScanController] getScanHistory error:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to retrieve scan history.',
        });
    }
};
/**
 * POST /api/scan/url
 * Receives a URL string, submits it to VirusTotal,
 * creates a 'queued' DB record, and returns the analysis ID for polling.
 */
exports.handleUrlScan = async (req, res) => {
    try {
        const { url, user_id: userId } = req.body;

        if (!url || typeof url !== 'string' || !url.trim()) {
            return res.status(400).json({
                success: false,
                message: 'A non-empty \'url\' field is required in the request body.',
            });
        }

        const trimmedUrl = url.trim();
        console.log(`[ScanController] URL scan requested for "${trimmedUrl}". Forwarding to VirusTotal...`);

        // ── Step 1: Submit URL to VirusTotal ────────────────────────────────
        const vtResponse  = await scanUrl(trimmedUrl);
        const analysisId  = vtResponse?.data?.id;
        const analysisLinks = vtResponse?.data?.links;

        // ── Step 2: Persist 'queued' record to database ─────────────────────
        let dbRecord = null;
        try {
            dbRecord = await createScanRecord({
                userId,
                fileName:   trimmedUrl,   // store the URL as the "file_name" for display
                fileSize:   0,
                analysisId,
                type:  determineScanType(req)
            });
            console.log(`[ScanController] DB record created for URL (id=${dbRecord?.id}, analysisId=${analysisId}).`);
        } catch (dbError) {
            // DB failure must NOT abort the scan — log and continue
            console.error(`[ScanController] WARNING: Failed to save URL scan DB record: ${dbError.message}`);
        }

        return res.status(200).json({
            success: true,
            message: 'URL successfully submitted to VirusTotal for analysis.',
            data: {
                scanId:    dbRecord?.id ?? null,
                url:       trimmedUrl,
                analysisId,
                links:     analysisLinks,
            },
        });

    } catch (error) {
        console.error('[ScanController] handleUrlScan error:', error.message);

        const isClientError =
            error.message.includes('rate limit') ||
            error.message.includes('authentication failed') ||
            error.message.includes('rejected the request');

        return res.status(isClientError ? 400 : 500).json({
            success: false,
            message: error.message || 'Server error during URL scanning.',
        });
    }
};

/**
 * POST /api/scan/text
 * Accepts optional `text` (string) and optional `image` (file via Multer).
 * Uses Google Gemini AI to analyze the content for phishing or social engineering.
 */
exports.handleTextScan = async (req, res) => {
    try {
        const text   = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
        const image  = req.file ?? null;
        const userId = req.body?.user_id ?? null;

        // ── Guard: need at least one input ────────────────────────────────────
        if (!text && !image) {
            return res.status(400).json({
                success: false,
                message: 'Provide at least one of: \'text\' (string) or \'image\' (file).',
            });
        }

        console.log(`[ScanController] AI Analysis requested. Text length: ${text.length}, Image provided: ${!!image}`);

        const imageBuffer = image ? image.buffer : null;
        let mimeType      = image ? image.mimetype : null;

        // Mobile (Flutter) web platform bazen application/octet-stream gönderir.
        // Gemini bunu reddeder. Uzantıdan tahmin et veya image/png olarak zorla.
        if (mimeType === 'application/octet-stream' && image) {
            if (image.originalname.toLowerCase().endsWith('.jpg') || image.originalname.toLowerCase().endsWith('.jpeg')) {
                mimeType = 'image/jpeg';
            } else {
                mimeType = 'image/png';
            }
        }

        // ── Görsel gönderildiğinde zorunlu bağlam metni ekle ─────────────────
        // Gemini görselin ne olduğunu bilmeden analiz yapamaz.
        // "Bu bir e-posta/ekran görüntüsüdür" bağlamını zorunlu olarak enjekte et.
        let contextText = text;
        if (image && !contextText) {
            contextText = 'Bu görsel bir e-posta ekran görüntüsüdür. Phishing (oltalama) tespiti için analiz et. İçerikte sahte gönderen, şüpheli URL, kişisel bilgi talebi veya aciliyet hissi yaratma gibi phishing taktikleri var mı?';
        } else if (image && contextText) {
            contextText = `GÖRSEL BAĞLAMI: Bu görsel bir e-posta veya mesaj ekran görüntüsüdür. Phishing analizi yap.\n\nKullanıcı notu: ${contextText}`;
        }

        // ── Step 1: Analyze content with Gemini (ISOLATED — fail-safe) ────────
        let aiReport;
        try {
            aiReport = await analyzeContent(contextText, imageBuffer, mimeType);
            console.log('[ScanController] Gemini analysis completed successfully.');
            // Ham raporu debug için logla (ilk 500 karakter)
            console.log('[ScanController] AI Report preview:', aiReport.substring(0, 500));
        } catch (geminiError) {
            console.error(`[ScanController] ⚠️  Gemini API error (non-fatal): ${geminiError.message}`);
            aiReport = 'Yapay zeka sunucularındaki yoğunluk nedeniyle detaylı analiz şu an üretilemiyor.';
        }

        // ── Step 2: Persist the scan record to database ───────────────────────
        let dbRecord = null;
        try {
            // Determine a meaningful display name for the record
            const displayName = image?.originalname
                ?? (text.length > 80 ? text.substring(0, 80) + '…' : text)
                ?? 'AI Analysis';

            const scanType = image
                ? determineScanType(req)   // 'image' or 'document'
                : 'text';
            
            // DB tablosu analysis_id için NOT NULL kısıtlamasına sahip olabilir.
            // Gemini için sahte bir UUID üretiyoruz.
            const { v4: uuidv4 } = require('uuid');

            dbRecord = await createScanRecord({
                userId,
                fileName:   displayName,
                fileSize:   image?.size ?? 0,
                analysisId: uuidv4(),      // Gemini scans don't have VT analysisId, so provide a dummy one
                type:       scanType,
            });
            console.log(`[ScanController] DB record created for AI scan (id=${dbRecord?.id}, type=${scanType}).`);
        } catch (dbError) {
            console.error('[ScanController] Dosya Kayıt Hatası:', dbError);
        }

        // ── Step 3: Server-side risk parse — Flutter'ın tahmin etmesine gerek yok ─
        const parsedRisk = _parseRiskFromReport(aiReport);
        console.log(`[ScanController] Parsed risk: level=${parsedRisk.level}, score=${parsedRisk.score}, verdict=${parsedRisk.verdict}`);

        // ── Step 4: Return the AI Report (always 200 OK) ─────────────────────
        return res.status(200).json({
            success: true,
            mode: 'gemini_analysis',
            data: {
                scanId:        dbRecord?.id ?? null,
                report:        aiReport,
                risk_level:    parsedRisk.level,
                risk_score:    parsedRisk.score,
                verdict:       parsedRisk.verdict,
                fileName:      image?.originalname ?? null,
                fileSizeBytes: image?.size ?? null,
            },
        });

    } catch (error) {
        // This outer catch handles truly unexpected failures (e.g. request
        // parsing errors), NOT Gemini API failures — those are caught above.
        console.error('[ScanController] handleTextScan unexpected error:', error.message);

        return res.status(500).json({
            success: false,
            message: error.message || 'Server error during AI analysis.',
        });
    }
};
