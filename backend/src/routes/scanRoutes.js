const express = require('express');
const router = express.Router();
const uploadMiddleware = require('../middlewares/uploadMiddleware');
const scanController = require('../controllers/scanController');

// POST /api/scan/upload — Receive image in RAM and submit to VirusTotal
router.post('/upload', uploadMiddleware.single('file'), scanController.uploadImage);

// GET /api/scan/report/:id — Fetch and parse the VirusTotal analysis report
router.get('/report/:id', scanController.getReport);

// Export the router
module.exports = router;
