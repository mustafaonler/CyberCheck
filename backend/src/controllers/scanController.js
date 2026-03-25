exports.uploadImage = (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ 
                success: false, 
                message: 'No file uploaded or invalid file type.' 
            });
        }

        // Access the file from req.file.buffer
        // Note: Everything currently stays in RAM (Memory Storage) for a "zero-infection" architecture.
        const fileBuffer = req.file.buffer;
        const fileSize = req.file.size;

        res.status(200).json({
            success: true,
            message: `File received in RAM successfully. Size: ${fileSize} bytes.`
        });
    } catch (error) {
        console.error('Error during file processing:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Server error during file processing.' 
        });
    }
};
