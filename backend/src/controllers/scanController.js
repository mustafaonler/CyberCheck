// controllers/scanController.js
const { scanFileWithVirusTotal, getAnalysisReport } = require('../services/virusTotalService');

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
        status:      attributes?.status ?? 'unknown',
        verdict,
        stats:       { malicious, suspicious, harmless, undetected, total },
        date:        attributes?.date ? new Date(attributes.date * 1000).toISOString() : null,
    };
};

/**
 * Receives an uploaded image (in RAM only), forwards the buffer to VirusTotal,
 * and returns the analysis ID for the client to poll results.
 */
exports.uploadImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'No file uploaded or invalid file type.',
            });
        }

        // File stays entirely in RAM — zero-infection architecture
        const { buffer, originalname, size } = req.file;

        console.log(`[ScanController] Received file "${originalname}" (${size} bytes). Forwarding to VirusTotal...`);

        const vtResponse = await scanFileWithVirusTotal(buffer, originalname);

        // VirusTotal v3 returns: { data: { id, type, links } }
        const analysisId = vtResponse?.data?.id;
        const analysisLinks = vtResponse?.data?.links;

        return res.status(200).json({
            success: true,
            message: 'File successfully submitted to VirusTotal for analysis.',
            data: {
                fileName: originalname,
                fileSizeBytes: size,
                analysisId,
                links: analysisLinks,
            },
        });
    } catch (error) {
        console.error('[ScanController] Error:', error.message);

        // Distinguish between client-side and server-side errors
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
 * Fetches a VirusTotal analysis report by ID and returns a parsed summary.
 * GET /api/scan/report/:id
 */
exports.getReport = async (req, res) => {
    const { id } = req.params;

    try {
        const vtResponse = await getAnalysisReport(id);

        // VirusTotal v3 analysis response: { data: { id, type, attributes: { stats, status, date, ... } } }
        const attributes = vtResponse?.data?.attributes;

        if (!attributes) {
            return res.status(502).json({
                success: false,
                message: 'Unexpected response structure from VirusTotal.',
            });
        }

        const report = parseVTAttributes(attributes);

        return res.status(200).json({
            success: true,
            analysisId: id,
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
