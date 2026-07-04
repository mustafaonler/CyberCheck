import io, re
with io.open('lib/screens/result_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = re.sub(r"Y\w+KSEK R\w+SK", "YÜKSEK RİSK", text)
text = re.sub(r"ORTA R\w+SK", "ORTA RİSK", text)
text = re.sub(r"D\w+K R\w+SK", "DÜŞÜK RİSK", text)
text = re.sub(r"G\w+VENL\w+", "GÜVENLİ", text)
text = re.sub(r"Bu i\w+erikle etkile\w+ime ge\w+meyin!", "Bu içerikle etkileşime geçmeyin!", text)
text = re.sub(r"Dikkatli olunmas\w+ \w+nerilir\.", "Dikkatli olunması önerilir.", text)
text = re.sub(r"D\w+k tehdit seviyesi tespit edildi\.", "Düşük tehdit seviyesi tespit edildi.", text)

with io.open('lib/screens/result_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print('Done')
