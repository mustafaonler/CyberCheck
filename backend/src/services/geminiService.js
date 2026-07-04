const { GoogleGenerativeAI, SchemaType } = require('@google/generative-ai');

/**
 * Analyzes text and/or an image using Google Gemini API.
 * Uses structured JSON output (responseSchema) to guarantee consistent
 * risk_level and risk_score values — eliminates all parsing uncertainty.
 *
 * @param {string} text - Optional text input.
 * @param {Buffer} imageBuffer - Optional image buffer from multer.
 * @param {string} mimeType - MIME type of the image.
 * @returns {Promise<string>} Formatted report text with embedded JSON metadata.
 */
const analyzeContent = async (text, imageBuffer, mimeType) => {
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
        throw new Error('GEMINI_API_KEY is not defined in environment variables.');
    }

    const genAI = new GoogleGenerativeAI(apiKey);

    // ── JSON Schema: Gemini bu yapıya UYMAK ZORUNDA ──────────────────────────
    const responseSchema = {
        type: SchemaType.OBJECT,
        properties: {
            risk_level: {
                type: SchemaType.STRING,
                enum: ['Temiz', 'Düşük', 'Orta', 'Yüksek', 'Kritik'],
                description: 'Tespit edilen tehdit seviyesi',
            },
            risk_score: {
                type: SchemaType.INTEGER,
                description: 'Risk skoru: Temiz=5, Düşük=22, Orta=52, Yüksek=78, Kritik=92',
            },
            tactics: {
                type: SchemaType.ARRAY,
                items: { type: SchemaType.STRING },
                description: 'Tespit edilen phishing/saldırı taktikleri listesi',
            },
            detailed_analysis: {
                type: SchemaType.STRING,
                description: 'Detaylı siber güvenlik analizi (Türkçe, profesyonel)',
            },
            user_advice: {
                type: SchemaType.STRING,
                description: 'Kullanıcıya öneriler ve aksiyon planı',
            },
        },
        required: ['risk_level', 'risk_score', 'tactics', 'detailed_analysis', 'user_advice'],
    };

    const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: {
            responseMimeType: 'application/json',
            responseSchema,
            temperature: 0.1, // Düşük = tutarlı sonuçlar
        },
    });

    const prompt = `Sen dünyaca tanınmış bir Siber Güvenlik Tehdit Analisti ve Adli Bilişim Uzmanısın.
Sana gönderilen içeriği (e-posta, ekran görüntüsü veya metin) phishing, sosyal mühendislik, kimlik avı ve zararlı yazılım açısından analiz et.

## ZORUNLU KURALLAR:
- E-posta ekran görüntüsü verildiğinde birincil görevin phishing tespiti yapmaktır.
- Aşağıdaki işaretlerden BİRİ bile varsa risk_level EN AZ "Yüksek" OLMALI:
  * Acele et/hemen tıkla/hesabın askıya alındı/ödül kazandın gibi ifadeler
  * Gerçek kurumların taklidi (banka, Google, Microsoft, PayPal vb.)
  * Şifre/kart/kimlik bilgisi talebi
  * Şüpheli veya yanlış yazılmış domain/URL
  * Sahte marka logosu
- Birden fazla phishing taktiği bir arada varsa risk_level "Kritik" OLMALI

## RİSK SKORU KURALLARI (ZORUNLU — DEĞİŞTİRME):
- Kritik → risk_score: 92
- Yüksek  → risk_score: 78
- Orta    → risk_score: 52
- Düşük   → risk_score: 22
- Temiz   → risk_score: 5

## ANALİZ KONTROL LİSTESİ:
1. Gönderen domain/adres meşru mu?
2. Aciliyet/korku/ödül hissi yaratılıyor mu?
3. Kişisel bilgi talep ediliyor mu?
4. Şüpheli URL var mı?
5. Marka logoları taklit mi?
6. Dil bilgisi veya biçimlendirme sorunları var mı?
7. Beklenmedik ek/indirme talebi var mı?

detailed_analysis alanında kontrol listesinin her maddesini Türkçe olarak değerlendir.
user_advice alanında kullanıcının yapması ve yapmaması gerekenleri listele.
tactics alanına tespit ettiğin her taktiği ayrı string olarak ekle.`;

    const parts = [prompt];

    if (text) {
        parts.push(`\n\nAnaliz edilecek içerik:\n${text}`);
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
        const result   = await model.generateContent(parts);
        const response = await result.response;
        const rawText  = response.text();

        // JSON parse
        let parsed;
        try {
            parsed = JSON.parse(rawText);
        } catch (parseErr) {
            console.warn('[GeminiService] JSON parse failed, returning raw text:', parseErr.message);
            return rawText;
        }

        // risk_level → risk_score uyumunu garanti et
        const levelScoreMap = { 'Kritik': 92, 'Yüksek': 78, 'Orta': 52, 'Düşük': 22, 'Temiz': 5 };
        if (parsed.risk_level && levelScoreMap[parsed.risk_level] !== undefined) {
            parsed.risk_score = levelScoreMap[parsed.risk_level];
        }

        console.log(`[GeminiService] ✅ Structured result: level=${parsed.risk_level}, score=${parsed.risk_score}`);

        // Hem frontend hem mobil için okunabilir metin formatı
        const formattedReport = [
            `1. Risk Seviyesi: ${parsed.risk_level}`,
            ``,
            `2. Tespit Edilen Taktikler:`,
            ...(parsed.tactics || []).map(t => `- ${t}`),
            ``,
            `3. Detaylı Analiz:`,
            parsed.detailed_analysis || '',
            ``,
            `4. Kullanıcıya Tavsiye:`,
            parsed.user_advice || '',
        ].join('\n');

        // Gizli JSON meta: controller bu veriyi okur, UI göstermez
        const jsonMeta = JSON.stringify({ risk_level: parsed.risk_level, risk_score: parsed.risk_score });
        return `${formattedReport}\n\n<!--RISK_JSON:${jsonMeta}-->`;

    } catch (error) {
        console.error('[GeminiService] API Hatası:', error.message);
        throw new Error(`Yapay zeka analizi gerçekleştirilemedi: ${error.message}`);
    }
};

module.exports = { analyzeContent };