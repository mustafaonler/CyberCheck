const path = require('path');
const multer = require('multer');

// Configure Memory Storage to keep files in RAM ("zero-infection" architecture)
const storage = multer.memoryStorage();

const IMAGE_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp']);
const DOCUMENT_EXTENSIONS = new Set([
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv', '.rtf',
]);
const BINARY_EXTENSIONS = new Set(['.exe', '.apk', '.dll', '.msi', '.bat', '.cmd', '.scr', '.zip', '.rar', '.7z']);

const IMAGE_MIMES = new Set([
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/webp',
    'image/gif',
    'image/bmp',
    'image/x-png',
    'image/pjpeg',
]);

const DOCUMENT_MIMES = new Set([
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'application/rtf',
    'text/rtf',
]);

// Flutter / web clients often send application/octet-stream even for valid images
const GENERIC_MIMES = new Set(['application/octet-stream', 'binary/octet-stream', '']);

const getExtension = (filename) => path.extname(filename || '').toLowerCase();

const hasAllowedExtension = (ext, mode) => {
    if (mode === 'image') return IMAGE_EXTENSIONS.has(ext);
    return IMAGE_EXTENSIONS.has(ext) || DOCUMENT_EXTENSIONS.has(ext) || BINARY_EXTENSIONS.has(ext);
};

const createFileFilter = (mode) => (req, file, cb) => {
    const mime = (file.mimetype || '').toLowerCase();
    const ext = getExtension(file.originalname);

    const mimeAllowed =
        (mode === 'image' ? IMAGE_MIMES : new Set([...IMAGE_MIMES, ...DOCUMENT_MIMES])).has(mime);

    if (mimeAllowed) {
        return cb(null, true);
    }

    // Fallback: trust extension when client sends a generic MIME type (common on mobile/web)
    if (GENERIC_MIMES.has(mime) && hasAllowedExtension(ext, mode)) {
        return cb(null, true);
    }

    // Last resort: some clients omit MIME but include a valid extension
    if (hasAllowedExtension(ext, mode)) {
        return cb(null, true);
    }

    const message = mode === 'image'
        ? 'Geçersiz dosya türü. Yalnızca PNG, JPG, JPEG, WEBP ve GIF desteklenir.'
        : 'Geçersiz dosya türü. Desteklenen formatlar: PNG, JPG, PDF, DOC, EXE, APK ve benzeri.';

    cb(new Error(message), false);
};

const createUpload = (mode) => multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
    fileFilter: createFileFilter(mode),
});

// /api/scan/upload — images + documents + binaries (VirusTotal)
const uploadFile = createUpload('file');

// /api/scan/text — images only (Gemini vision)
const uploadImage = createUpload('image');

/**
 * Wraps multer middleware so validation errors return 400 instead of 500.
 */
const handleUpload = (uploadMiddleware) => (req, res, next) => {
    uploadMiddleware(req, res, (err) => {
        if (!err) return next();

        if (err instanceof multer.MulterError) {
            const messages = {
                LIMIT_FILE_SIZE: 'Dosya boyutu 10 MB sınırını aşıyor.',
                LIMIT_UNEXPECTED_FILE: 'Beklenmeyen dosya alanı gönderildi.',
            };
            return res.status(400).json({
                success: false,
                message: messages[err.code] || `Dosya yükleme hatası: ${err.message}`,
            });
        }

        return res.status(400).json({
            success: false,
            message: err.message || 'Dosya yükleme hatası.',
        });
    });
};

module.exports = uploadFile;
module.exports.uploadFile = uploadFile;
module.exports.uploadImage = uploadImage;
module.exports.handleUpload = handleUpload;
