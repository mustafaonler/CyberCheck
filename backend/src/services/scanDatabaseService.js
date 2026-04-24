// services/scanDatabaseService.js
// All database interactions for the `scans` table.
// Uses the shared pg Pool — no extra dependencies required.

const { pool } = require('../config/db');

/**
 * Creates a new scan record in the database when a file is first submitted.
 *
 * @param {object} params
 * @param {string} params.fileName     - Original filename from the upload.
 * @param {number} params.fileSize     - File size in bytes.
 * @param {string} params.analysisId   - VirusTotal analysis ID returned after upload.
 * @returns {Promise<object>} The newly created row.
 */
const createScanRecord = async ({ fileName, fileSize, analysisId }) => {
    const sql = `
        INSERT INTO scans (file_name, file_size, analysis_id, status)
        VALUES ($1, $2, $3, 'queued')
        RETURNING *;
    `;
    const values = [fileName, fileSize, analysisId];

    const { rows } = await pool.query(sql, values);
    return rows[0];
};

/**
 * Updates an existing scan record with the final VirusTotal results.
 * Typically called once the analysis status is 'completed'.
 *
 * @param {object} params
 * @param {string} params.analysisId   - VirusTotal analysis ID (unique key).
 * @param {string} params.status       - New status ('in-progress', 'completed', 'failed').
 * @param {string} [params.verdict]    - Verdict: 'clean', 'suspicious', or 'malicious'.
 * @param {object} [params.stats]      - Detection counts { malicious, suspicious, harmless, undetected, total }.
 * @returns {Promise<object|null>} The updated row, or null if no row matched.
 */
const updateScanRecord = async ({ analysisId, status, verdict = null, stats = null }) => {
    const sql = `
        UPDATE scans
        SET
            status  = $1,
            verdict = $2,
            stats   = $3::jsonb
        WHERE analysis_id = $4
        RETURNING *;
    `;
    const values = [
        status,
        verdict,
        stats ? JSON.stringify(stats) : null,
        analysisId,
    ];

    const { rows } = await pool.query(sql, values);
    return rows[0] ?? null;
};

/**
 * Fetches a single scan record by its VirusTotal analysis ID.
 *
 * @param {string} analysisId
 * @returns {Promise<object|null>}
 */
const getScanByAnalysisId = async (analysisId) => {
    const sql = `SELECT * FROM scans WHERE analysis_id = $1 LIMIT 1;`;
    const { rows } = await pool.query(sql, [analysisId]);
    return rows[0] ?? null;
};

/**
 * Returns a paginated list of all scan records, newest first.
 *
 * @param {number} [limit=20]
 * @param {number} [offset=0]
 * @returns {Promise<object[]>}
 */
const listScans = async (limit = 20, offset = 0) => {
    const sql = `
        SELECT id, file_name, file_size, analysis_id, status, verdict, stats, created_at, updated_at
        FROM scans
        ORDER BY created_at DESC
        LIMIT $1 OFFSET $2;
    `;
    const { rows } = await pool.query(sql, [limit, offset]);
    return rows;
};

module.exports = {
    createScanRecord,
    updateScanRecord,
    getScanByAnalysisId,
    listScans,
};
