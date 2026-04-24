// controllers/scanController.js
// Orchestrates file scanning via VirusTotal and persists results to Supabase.

const { scanFileWithVirusTotal, getAnalysisReport } = require('../services/virusTotalService');
const {
    createScanRecord,
    updateScanRecord,
    getScanByAnalysisId,
    listScans,
} = require('../services/scanDatabaseService');

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

        console.log(`[ScanController] Received "${originalname}" (${size} bytes). Forwarding to VirusTotal...`);

        // ── Step 1: Submit to VirusTotal ──────────────────────────────────────
        const vtResponse = await scanFileWithVirusTotal(buffer, originalname);
        const analysisId    = vtResponse?.data?.id;
        const analysisLinks = vtResponse?.data?.links;

        // ── Step 2: Persist 'queued' record to database ───────────────────────
        let dbRecord = null;
        try {
            dbRecord = await createScanRecord({
                fileName:   originalname,
                fileSize:   size,
                analysisId,
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
            // Only write full results when VirusTotal says it's done
            if (vtStatus === 'completed') {
                dbRecord = await updateScanRecord({
                    analysisId: id,
                    status:     'completed',
                    verdict:    report.verdict,
                    stats:      report.stats,
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
