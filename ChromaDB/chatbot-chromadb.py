import os
import re
import chromadb
import zeyrek  
import difflib
import logging
from chromadb.utils import embedding_functions
from pypdf import PdfReader
import nltk
import datetime

# FastAPI ve Uvicorn Bağımlılıkları
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

logging.getLogger().setLevel(logging.ERROR)
nltk.download('punkt_tab', quiet=True)
analyzer = zeyrek.MorphAnalyzer()

def metin_koku_bul(metin):
    # Metindeki noktalama işaretlerini temizleyip küçük harfe çevirir
    temiz_metin = re.sub(r'[^\w\s]', '', metin).lower()
    
    # Zeyrek ile kelimelerin kökünü buluruz
    analiz_sonucu = analyzer.lemmatize(temiz_metin)
    kokler = []
    
    for kelime_analizi in analiz_sonucu:
        if kelime_analizi[1]: # Eğer bir kök bulduysa ilk kökü al
            kokler.append(kelime_analizi[1][0])
        else: # Kök bulamadıysa kelimenin orijinalini bırak
            kokler.append(kelime_analizi[0])
            
    return " ".join(kokler)

def soru_mantikli_mi(soru):
    temiz_soru = re.sub(r'[^\w\s]', '', soru).lower()
    kelimeler = temiz_soru.split()
    
    if not kelimeler: # Eğer sadece boşluk atıldıysa
        return False
        
    sesliler = "aeıioöuü"
    gecerli_kelime_sayisi = 0
    
    for kelime in kelimeler:
        # Kelimenin içinde en az 1 sesli harf varsa veya çok kısaysa geçerli say
        if any(harf in sesliler for harf in kelime) or len(kelime) <= 2:
            gecerli_kelime_sayisi += 1
            
    # Eğer cümlenin yarısından fazlası sesli harf içermeyen saçma kelimelerdense
    if (gecerli_kelime_sayisi / len(kelimeler)) < 0.5:
        return False
        
    return True

def yazim_duzelt(metin):
    duzeltilmis_kelimeler = []
    bilinmeyen_kelime_sayisi = 0 
    kelimeler = metin.split()
    
    for kelime in kelimeler:
        if kelime in pdf_kelime_havuzu:
            duzeltilmis_kelimeler.append(kelime)
        else:
            benzerler = difflib.get_close_matches(kelime, pdf_kelime_havuzu, n=1, cutoff=0.6)
            if benzerler:
                duzeltilmis_kelimeler.append(benzerler[0])
            else:
                bilinmeyen_kelime_sayisi += 1 
                duzeltilmis_kelimeler.append(kelime)
                
    cok_yanlis_mi = False
    if len(kelimeler) > 0 and (bilinmeyen_kelime_sayisi / len(kelimeler)) > 0.5:
        cok_yanlis_mi = True
            
    return " ".join(duzeltilmis_kelimeler), cok_yanlis_mi

# ==========================================
# 1. AŞAMA: CHROMADB VE MODEL HAZIRLIĞI
# ==========================================
print("1. ChromaDB başlatılıyor ve Vektör Modeli yükleniyor...")

mevcut_klasor = os.path.dirname(os.path.abspath(__file__))
db_kayit_yolu = os.path.join(mevcut_klasor, "chroma_db_abone")

client = chromadb.PersistentClient(path=db_kayit_yolu)

embedding_model = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="intfloat/multilingual-e5-base")

collection = client.get_or_create_collection(
    name="abonesepeti_yonerge_e5_cosine",
    embedding_function=embedding_model,
    metadata={"hnsw:space": "cosine"}
)

# ==========================================
# 2. AŞAMA: PDF OKUMA VE MADDELERE BÖLME
# ==========================================
pdf_yolu = os.path.join(mevcut_klasor, "aboneSepetiYonerge.pdf")

print(f"2. '{pdf_yolu}' dosyası okunuyor...")
reader = PdfReader(pdf_yolu)
tam_metin = ""

for sayfa in reader.pages:
    metin = sayfa.extract_text()
    if metin:
        tam_metin += metin + " "

temiz_tam_metin = re.sub(r'[^\w\s]', '', tam_metin).lower()
pdf_kelime_havuzu = set(temiz_tam_metin.split())

maddeler = re.split(r'(?=\bMADDE\b)', tam_metin, flags=re.IGNORECASE)
temiz_maddeler = [m.strip() for m in maddeler if len(m.strip()) > 10]

print(f"-> PDF'ten toplam {len(temiz_maddeler)} adet madde çıkarıldı.\n")

# ==========================================
# 3. AŞAMA: VEKTÖRLEŞTİRME VE DB GÜNCELLEME
# ==========================================
for i, madde_metni in enumerate(temiz_maddeler):
    kok_metin = metin_koku_bul(madde_metni)
    vektor = embedding_model([kok_metin])[0]
    
    doc_id = f"madde_{i+1}"
    collection.upsert(
        documents=[madde_metni],
        ids=[doc_id]
    )

print("VEKTÖR HAVUZU BAŞARIYLA HAZIRLANDI VE KAYDEDİLDİ!\n")

# ==========================================

# 4. AŞAMA: MERKEZİ RAG MOTORU
# ==========================================
def cevabi_getir(kullanici_sorusu: str) -> str:
    """Hem API hem de genel aramalar için ortak RAG cevap fonksiyonu"""
    temiz_kullanici_sorusu = re.sub(r'[^\w\s]', '', kullanici_sorusu).lower()
    
    if not temiz_kullanici_sorusu:
        return "Eksik veya hatalı yazdınız lütfen bir daha deneyiniz."

    duzeltilmis_soru, cok_yanlis_mi = yazim_duzelt(temiz_kullanici_sorusu)
    
    if cok_yanlis_mi or not soru_mantikli_mi(duzeltilmis_soru):
        return "Eksik veya hatalı yazdınız lütfen bir daha deneyiniz."
        
    temiz_soru = metin_koku_bul(duzeltilmis_soru)
    e5_formatli_soru = f"query: {temiz_soru}"
    
    sonuclar = collection.query(
        query_texts=[e5_formatli_soru],
        n_results=1 
    )
    
    if sonuclar['documents'] and len(sonuclar['documents'][0]) > 0:
        bulunan_cevap = sonuclar['documents'][0][0]
        mesafe = sonuclar['distances'][0][0] 
        
        if mesafe > 0.30:
            return "Üzgünüm, kılavuzda bu soruyla ilgili spesifik bir bilgi bulamadım."
        else:
            insansi_cevap = re.sub(r'(?i)^\s*madde\s*\d*\s*[.:-]?\s*', '', bulunan_cevap)
            return insansi_cevap.strip()
    else:
        return "Veritabanında arama yapılamadı."

# ==========================================
# 5. AŞAMA: FASTAPI WEB SERVİS KATMANI
# ==========================================
app = FastAPI(title="Chatbot RAG API")

class SoruIstek(BaseModel):
    soru: str

@app.post("/api/rag/sor")
def rag_soru_sor(istek: SoruIstek):
    cevap = cevabi_getir(istek.soru)
    return {"cevap": cevap}

# ==========================================
# 6. AŞAMA: SERVİSİ BAŞLATMA
# ==========================================
if __name__ == "__main__":
    # Spring Boot ile haberleşmek üzere Port 8000 üzerinde dinlemeye geçer
    uvicorn.run(app, host="127.0.0.1", port=8000)

