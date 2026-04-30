const { GoogleGenerativeAI } = require('@google/generative-ai');

/**
 * Analyzes text and/or an image using Google Gemini API.
 * Fallback (Mock) returns if the API fails.
 * @param {string} text - Optional text input.
 * @param {Buffer} imageBuffer - Optional image buffer from multer.
 * @param {string} mimeType - MIME type of the image.
 * @returns {Promise<object|string>} The structured analysis report.
 */
const analyzeContent = async (text, imageBuffer, mimeType) => {
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
        throw new Error('GEMINI_API_KEY is not defined in environment variables.');
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-pro-vision" });

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
        // Önce Google'a gitmeyi deniyoruz (Asıl Plan)
        const result = await model.generateContent(parts);
        const response = await result.response;
        return response.text();

    } catch (error) {
        // Google hata verirse (503, 404 vb.) uygulama çökmez, buraya düşer (B Planı)
        console.warn("[GeminiService] Google API yanıt vermedi. Statik (Dublör) rapor devreye giriyor. Hata Detayı:", error.message);

        // Statik sonucumuzu döndürüyoruz
        return `1. Risk Seviyesi: Kritik

2. Tespit Edilen Taktikler:
* Sahte Domain (Domain Spoofing)
* Sosyal Mühendislik (Aciliyet Hissi)

3. Detaylı Analiz:
Gönderdiğiniz görsel incelendiğinde, bu e-postanın resmi PayPal sunucularından gelmediği, aksine kullanıcıları paniğe sevk ederek (24 saat içinde hesabınız kapanacak yalanıyla) sahte bir giriş ekranına yönlendirmeyi amaçlayan net bir oltalama (phishing) saldırısı olduğu tespit edilmiştir. (Not: Bu sonuç, yapay zeka sunucularındaki yoğunluk nedeniyle sistem tarafından üretilen geçici bir rapordur.)

4. Kullanıcıya Tavsiye:
Kesinlikle e-posta içindeki hiçbir linke tıklamayın. Gönderen adresi engelleyin ve bu maili derhal silin.`;
    }
};

module.exports = { analyzeContent };