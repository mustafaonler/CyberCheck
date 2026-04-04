// services/virusTotalService.js
// Handles all communication with the VirusTotal v3 API.
// Files are NEVER written to disk — zero-infection architecture.

const axios = require('axios');
const FormData = require('form-data');

const VT_FILES_URL = 'https://www.virustotal.com/api/v3/files';
const VT_ANALYSES_URL = 'https://www.virustotal.com/api/v3/analyses';

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

module.exports = { scanFileWithVirusTotal, getAnalysisReport };
