// services/virusTotalService.js
// Handles all communication with the VirusTotal v3 API.
// Files are NEVER written to disk — zero-infection architecture.

const axios = require('axios');
const FormData = require('form-data');

const VT_FILES_URL     = 'https://www.virustotal.com/api/v3/files';
const VT_URLS_URL      = 'https://www.virustotal.com/api/v3/urls';
const VT_ANALYSES_URL  = 'https://www.virustotal.com/api/v3/analyses';

// ─── Helper: encode a URL to the VT-safe base64 format ───────────────────────
const encodeUrlForVT = (url) => Buffer.from(url).toString('base64').replace(/=/g, '');


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
            headers: { 'x-apikey': apiKey }
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
            headers: { 'x-apikey': apiKey },
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

    // Build a multipart/form-data body from the in-memory buffer
    const form = new FormData();
    form.append('file', fileBuffer, {
        filename: originalName,
        contentType: 'application/octet-stream',
    });

    try {
        const response = await axios.post(VT_FILES_URL, form, {
            headers: {
                'x-apikey': apiKey,
                ...form.getHeaders(),
            },
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
            headers: { 'x-apikey': apiKey },
            timeout: 30000,
        });

        return response.data;
    } catch (error) {
        if (error.response) {
            const status = error.response.status;
            const vtMessage =
                error.response.data?.error?.message || 'Unknown VirusTotal error.';

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
            headers: {
                'x-apikey': apiKey,
                'Content-Type': 'application/x-www-form-urlencoded',
            },
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
