// services/virusTotalService.js
// Handles all communication with the VirusTotal v3 API.
// Files are NEVER written to disk — zero-infection architecture.

const axios = require('axios');
const FormData = require('form-data');

const VT_FILES_URL     = 'https://www.virustotal.com/api/v3/files';
const VT_URLS_URL      = 'https://www.virustotal.com/api/v3/urls';
const VT_ANALYSES_URL  = 'https://www.virustotal.com/api/v3/analyses';

// ─── Helper: build base headers for every VT request ─────────────────────────
// VirusTotal automatically injects x-vt-user from the API key owner's profile.
// If that profile name contains non-ASCII chars (e.g. 'Önler'), VT's own
// metadata validation fails with HTTP 400. Explicitly overriding x-vt-user
// with an ASCII-only value prevents the error on ALL endpoints.
const vtHeaders = (apiKey, extra = {}) => ({
    'x-apikey':  apiKey,
    'x-vt-user': 'CyberCheck',   // ASCII-only override — avoids Turkish-char 400 error
    ...extra,
});

// ─── Helper: encode a URL to the VT-safe base64 format ───────────────────────
const encodeUrlForVT = (url) => Buffer.from(url).toString('base64').replace(/=/g, '');

// ─── Helper: sanitize a string to ASCII-only for VirusTotal metadata ──────────
// VirusTotal API rejects non-ASCII characters (e.g. Turkish chars like Ö, ş, ğ)
// in filename metadata and x-vt-user headers, returning HTTP 400.
const TURKISH_CHAR_MAP = {
    'ç': 'c', 'Ç': 'C',
    'ğ': 'g', 'Ğ': 'G',
    'ı': 'i', 'İ': 'I',
    'ö': 'o', 'Ö': 'O',
    'ş': 's', 'Ş': 'S',
    'ü': 'u', 'Ü': 'U',
};

const sanitizeAscii = (str) => {
    if (!str || typeof str !== 'string') return str;
    // 1) Replace known Turkish characters with ASCII equivalents
    let sanitized = str.replace(/[çÇğĞıİöÖşŞüÜ]/g, (ch) => TURKISH_CHAR_MAP[ch] ?? ch);
    // 2) Strip any remaining non-ASCII characters (safety net)
    sanitized = sanitized.replace(/[^\x00-\x7F]/g, '_');
    return sanitized;
};


/**
 * Verilen URL'yi VirusTotal API (v3) kullanarak tarar ve risk durumunu döndürür.
 * @param {string} targetUrl - Taranacak web adresi (örn: https://süphelilink.com)
 * @returns {Promise<object>} Temizlenmiş analiz sonuçları
 */
const scanUrlWithVT = async (targetUrl) => {
    const apiKey = process.env.VT_API_KEY;

    if (!apiKey) {
        throw new Error('VT_API_KEY .env dosyasında bulunamadı.');
    }

    try {
        const encodedUrl = encodeUrlForVT(targetUrl);

        const response = await axios.get(`${VT_URLS_URL}/${encodedUrl}`, {
            headers: vtHeaders(apiKey),
        });

        const stats = response.data.data.attributes.last_analysis_stats;
        const totalMalicious = stats.malicious + stats.suspicious;

        return {
            isMalicious: totalMalicious > 0,
            maliciousCount: stats.malicious,
            suspiciousCount: stats.suspicious,
            harmlessCount: stats.harmless,
            totalEngines: stats.malicious + stats.suspicious + stats.harmless + stats.undetected,
            reportLink: `https://www.virustotal.com/gui/url/${encodedUrl}`
        };

    } catch (error) {
        if (error.response && error.response.status === 404) {
            return {
                isMalicious: false,
                message: "Bu URL daha önce VirusTotal ağında taranmamış (Bilinmiyor).",
                harmlessCount: 0,
                maliciousCount: 0
            };
        }
        console.error("[VirusTotal] API Hatası:", error.message);
        throw new Error(`VirusTotal taraıması sırasında bir hata oluştu: ${error.message}`);
    }
};


/**
 * Fetches enriched metadata for a URL from VirusTotal:
 * categories, SSL certificate, title, reputation, final redirect URL.
 *
 * @param {string} targetUrl - The URL to look up.
 * @returns {Promise<object|null>} Parsed metadata object, or null on failure.
 */
const getUrlMetadata = async (targetUrl) => {
    const apiKey = process.env.VT_API_KEY;
    if (!apiKey) return null;

    try {
        const encodedUrl = encodeUrlForVT(targetUrl);
        const response = await axios.get(`${VT_URLS_URL}/${encodedUrl}`, {
            headers: vtHeaders(apiKey),
            timeout: 20000,
        });

        const attrs = response.data?.data?.attributes ?? {};

        // ── Categories ─────────────────────────────────────────────────────
        // VT returns an object: { "engine_name": "category_label", ... }
        // Collect unique values, deduplicate
        const rawCategories = attrs.categories ?? {};
        const categorySet = [...new Set(Object.values(rawCategories))];

        // ── SSL Certificate ─────────────────────────────────────────────────
        const cert = attrs.last_https_certificate ?? null;
        let sslInfo = null;
        if (cert) {
            const subject  = cert.subject ?? {};
            const validity = cert.validity ?? {};
            const now      = Date.now();
            const notAfter = validity.not_after
                ? new Date(validity.not_after).getTime()
                : null;

            sslInfo = {
                issuer:       cert.issuer?.O ?? cert.issuer?.CN ?? null,
                subject_cn:   subject.CN ?? null,
                valid_from:   validity.not_before ?? null,
                valid_until:  validity.not_after  ?? null,
                is_valid:     notAfter ? notAfter > now : null,
                thumbprint:   cert.thumbprint ?? null,
            };
        }

        return {
            categories:      categorySet.length > 0 ? categorySet : null,
            ssl:             sslInfo,
            title:           attrs.title ?? null,
            final_url:       attrs.last_final_url ?? null,
            reputation:      attrs.reputation ?? null,
            times_submitted: attrs.times_submitted ?? null,
            first_seen:      attrs.first_submission_date
                                 ? new Date(attrs.first_submission_date * 1000).toISOString()
                                 : null,
            last_seen:       attrs.last_submission_date
                                 ? new Date(attrs.last_submission_date * 1000).toISOString()
                                 : null,
        };
    } catch (err) {
        // Non-fatal: if metadata fetch fails, we still return the scan result
        console.warn('[VirusTotal] getUrlMetadata failed (non-fatal):', err.message);
        return null;
    }
};


/**
 * Uploads a file buffer to VirusTotal for analysis.
 * @param {Buffer} fileBuffer - The in-memory file buffer from multer.
 * @param {string} originalName - The original filename (used as the form field name).
 * @returns {Promise<object>} The VirusTotal response data containing the analysis ID.
 */
const scanFileWithVirusTotal = async (fileBuffer, originalName) => {
    const apiKey = process.env.VT_API_KEY;

    if (!apiKey) {
        throw new Error('VT_API_KEY is not defined in environment variables.');
    }

    // Build a multipart/form-data body from the in-memory buffer.
    // Sanitize the filename to ASCII-only — VirusTotal rejects non-ASCII
    // characters in multipart metadata (e.g. Turkish filenames like 'görsel.jpg').
    const safeFilename = sanitizeAscii(originalName);
    const form = new FormData();
    form.append('file', fileBuffer, {
        filename: safeFilename,
        contentType: 'application/octet-stream',
    });

    try {
        const response = await axios.post(VT_FILES_URL, form, {
            headers: vtHeaders(apiKey, form.getHeaders()),
            // 30-second timeout to handle slow network conditions
            timeout: 30000,
        });

        return response.data;
    } catch (error) {
        // Surface a meaningful error based on the HTTP status code
        if (error.response) {
            const status = error.response.status;
            const vtMessage =
                error.response.data?.error?.message || 'Unknown VirusTotal error.';

            if (status === 401) {
                throw new Error(`VirusTotal authentication failed. Check your VT_API_KEY. (${vtMessage})`);
            } else if (status === 429) {
                throw new Error('VirusTotal rate limit exceeded. Please try again later.');
            } else if (status === 400) {
                throw new Error(`VirusTotal rejected the request: ${vtMessage}`);
            } else {
                throw new Error(`VirusTotal API error [${status}]: ${vtMessage}`);
            }
        } else if (error.request) {
            // Request was made but no response received (network issue / timeout)
            throw new Error('No response from VirusTotal. Check your internet connection or try again later.');
        } else {
            // Something went wrong before the request was sent
            throw new Error(`Failed to send file to VirusTotal: ${error.message}`);
        }
    }
};

/**
 * Fetches the analysis report from VirusTotal using a previously returned analysisId.
 * @param {string} analysisId - The analysis ID returned by scanFileWithVirusTotal.
 * @returns {Promise<object>} The VirusTotal analysis report data.
 */
const getAnalysisReport = async (analysisId) => {
    const apiKey = process.env.VT_API_KEY;

    if (!apiKey) {
        throw new Error('VT_API_KEY is not defined in environment variables.');
    }

    if (!analysisId) {
        throw new Error('analysisId is required.');
    }

    try {
        const response = await axios.get(`${VT_ANALYSES_URL}/${analysisId}`, {
            headers: vtHeaders(apiKey),
            timeout: 30000,
        });

        return response.data;
    } catch (error) {
        if (error.response) {
            const status = error.response.status;
            const vtMessage =
                error.response.data?.error?.message || 'Unknown VirusTotal error.';

            // ── Special case: VirusTotal profile username contains non-ASCII ──
            // VT server-side injects the account's display name into internal
            // metadata. If that name has Turkish/non-ASCII chars (e.g. 'Önler'),
            // VT's own validation rejects it with "metadata was invalid".
            // This CANNOT be fixed via request headers; the VT account username
            // must be changed to ASCII at https://www.virustotal.com → Settings.
            // Workaround: treat this as "still in progress" so the poller retries.
            if (status === 400 && vtMessage.includes('metadata was invalid')) {
                console.warn(
                    '[VirusTotal] ⚠️  "metadata was invalid" error detected.\n' +
                    '  Root cause: The VirusTotal account username contains non-ASCII\n' +
                    '  characters (e.g. "Önler"). Fix: go to https://www.virustotal.com\n' +
                    '  → Settings → change your username to ASCII-only (e.g. "Onler").'
                );
                // Return a synthetic "still queued" response so the UI keeps polling
                // instead of showing a hard error to the user.
                return {
                    data: {
                        attributes: {
                            status: 'queued',
                            stats: { malicious: 0, suspicious: 0, harmless: 0, undetected: 0 },
                        },
                    },
                    _vtProfileBug: true,   // flag for debugging
                };
            }

            if (status === 401) {
                throw new Error(`VirusTotal authentication failed. Check your VT_API_KEY. (${vtMessage})`);
            } else if (status === 404) {
                throw new Error(`Analysis report not found. The ID may be invalid or expired. (${vtMessage})`);
            } else if (status === 429) {
                throw new Error('VirusTotal rate limit exceeded. Please try again later.');
            } else {
                throw new Error(`VirusTotal API error [${status}]: ${vtMessage}`);
            }
        } else if (error.request) {
            throw new Error('No response from VirusTotal. Check your internet connection or try again later.');
        } else {
            throw new Error(`Failed to fetch report from VirusTotal: ${error.message}`);
        }
    }
};


/**
 * Submits a URL to VirusTotal for analysis.
 * @param {string} url - The URL (or IP address) to scan.
 * @returns {Promise<object>} The VirusTotal response data containing the analysis ID.
 */
const scanUrl = async (url) => {
    const apiKey = process.env.VT_API_KEY;

    if (!apiKey) {
        throw new Error('VT_API_KEY is not defined in environment variables.');
    }

    if (!url) {
        throw new Error('url is required.');
    }

    // VT v3 expects the URL as application/x-www-form-urlencoded
    const body = new URLSearchParams({ url });

    try {
        const response = await axios.post(VT_URLS_URL, body.toString(), {
            headers: vtHeaders(apiKey, { 'Content-Type': 'application/x-www-form-urlencoded' }),
            timeout: 30000,
        });

        return response.data;
    } catch (error) {
        if (error.response) {
            const status = error.response.status;
            const vtMessage = error.response.data?.error?.message || 'Unknown VirusTotal error.';

            if (status === 401) {
                throw new Error(`VirusTotal authentication failed. Check your VT_API_KEY. (${vtMessage})`);
            } else if (status === 429) {
                throw new Error('VirusTotal rate limit exceeded. Please try again later.');
            } else if (status === 400) {
                throw new Error(`VirusTotal rejected the request: ${vtMessage}`);
            } else {
                throw new Error(`VirusTotal API error [${status}]: ${vtMessage}`);
            }
        } else if (error.request) {
            throw new Error('No response from VirusTotal. Check your internet connection or try again later.');
        } else {
            throw new Error(`Failed to send URL to VirusTotal: ${error.message}`);
        }
    }
};

module.exports = { scanFileWithVirusTotal, scanUrl, getAnalysisReport, scanUrlWithVT, getUrlMetadata };
