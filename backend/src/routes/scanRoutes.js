const express = require('express');
const router = express.Router();
const uploadMiddleware = require('../middlewares/uploadMiddleware');
const scanController = require('../controllers/scanController');

// POST /api/scan/upload — Receive image in RAM and submit to VirusTotal
router.post('/upload', uploadMiddleware.single('file'), scanController.uploadImage);

// GET /api/scan/report/:id — Fetch and parse the VirusTotal analysis report
router.get('/report/:id', scanController.getReport);

// GET /api/scan/history?limit=20&offset=0 — List past scans from the database
router.get('/history', scanController.getScanHistory);

// POST /api/scan/url — Submit a URL or IP to VirusTotal for analysis
router.post('/url', scanController.handleUrlScan);

// POST /api/scan/text — Analyse text and/or an image using Gemini AI
router.post('/text', uploadMiddleware.single('image'), scanController.handleTextScan);

// Export the router
module.exports = router;
