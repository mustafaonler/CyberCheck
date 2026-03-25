const express = require('express');
const router = express.Router();
const uploadMiddleware = require('../middlewares/uploadMiddleware');
const scanController = require('../controllers/scanController');

// POST route /api/scan/upload
// Expecting a single file upload with the field name 'file'
router.post('/upload', uploadMiddleware.single('file'), scanController.uploadImage);

// Export the router
module.exports = router;
