const { GoogleGenerativeAI } = require('@google/generative-ai');

/**
 * Analyzes text and/or an image using Google Gemini API.
 * @param {string} text - Optional text input.
 * @param {Buffer} imageBuffer - Optional image buffer from multer.
 * @param {string} mimeType - MIME type of the image.
 * @returns {Promise<string>} The structured analysis report.
 */
const analyzeContent = async (text, imageBuffer, mimeType) => {
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
        throw new Error('GEMINI_API_KEY is not defined in environment variables.');
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const prompt = `Sen kıdemli bir Siber Güvenlik Analistisin. Sana gönderilen metinleri veya ekran görüntülerini (SS) oltalama (phishing), sosyal mühendislik, sahtekarlık ve zararlı yazılım risklerine karşı analiz et. 
Lütfen analiz raporunu KESİNLİKLE TÜRKÇE olarak, anlaşılır ve profesyonel bir dille yaz. 
Raporunu şu başlıklara ayırarak ver:
1. Risk Seviyesi (Düşük/Orta/Yüksek/Kritik)
2. Tespit Edilen Taktikler (örn: Aciliyet hissi, Sahte domain)
3. Detaylı Analiz
4. Kullanıcıya Tavsiye`;

    const parts = [prompt];

    if (text) {
        parts.push(`\n\nUser Text:\n${text}`);
    }

    if (imageBuffer && mimeType) {
        parts.push({
            inlineData: {
                data: imageBuffer.toString('base64'),
                mimeType,
            },
        });
    }

    try {
        // Doğrudan Google'a gidiyoruz
        const result = await model.generateContent(parts);
        const response = await result.response;
        return response.text();

    } catch (error) {
        // Dublör silindi! Eğer API patlarsa hatayı doğrudan Controller'a iletiyoruz.
        console.error("[GeminiService] Yapay Zeka API Hatası:", error.message);
        throw new Error(`Yapay zeka analizi gerçekleştirilemedi: ${error.message}`);
    }
};

module.exports = { analyzeContent };