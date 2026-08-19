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
import psycopg2

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

logging.getLogger().setLevel(logging.ERROR)
nltk.download('punkt_tab', quiet=True)
analyzer = zeyrek.MorphAnalyzer()

# ==========================================
# VERİTABANI BAĞLANTISI
# ==========================================
db_connection = None

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
# 2. & 3. AŞAMA: SADECE GEREKLİYSE PDF'İ OKU VE VEKTÖRLEŞTİR
# ==========================================
pdf_yolu = os.path.join(mevcut_klasor, "aboneSepetiYonerge.pdf")
pdf_kelime_havuzu = set()

# Eğer veritabanı boşsa (ilk çalıştırma) PDF'i oku ve kaydet
if collection.count() == 0:
    print(f"2. Veritabanı boş, '{pdf_yolu}' dosyası okunuyor ve vektörleştiriliyor...")
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

    print(f"-> PDF'ten toplam {len(temiz_maddeler)} adet madde çıkarıldı.")

    for i, madde_metni in enumerate(temiz_maddeler):
        doc_id = f"madde_{i+1}"
        collection.upsert(
            documents=[f"passage: {madde_metni}"],
            ids=[doc_id]
        )
    print("VEKTÖR HAVUZU BAŞARIYLA HAZIRLANDI VE KAYDEDİLDİ!\n")
else:
    print(f"-> ChromaDB hazır: Veritabanında zaten {collection.count()} adet kayıtlı madde var. PDF adımı atlandı.\n")

# ==========================================
# YARDIMCI VE DENETİM FONKSİYONLARI
# ==========================================
def soru_mantikli_mi(soru: str) -> bool:
    temiz_soru = re.sub(r'[^\w\s]', '', soru).lower()
    kelimeler = temiz_soru.split()
    
    if not kelimeler: 
        return False
        
    sesliler = "aeıioöuü"
    gecerli_kelime_sayisi = 0
    
    for kelime in kelimeler:
        if any(harf in sesliler for harf in kelime) or len(kelime) <= 2:
            gecerli_kelime_sayisi += 1
            
    if (gecerli_kelime_sayisi / len(kelimeler)) < 0.4:
        return False
        
    return True

def musteri_hizmetlerine_yonlendir():
    su_an = datetime.datetime.now()
    haftanin_gunu = su_an.weekday() 
    saat = su_an.hour
    
    if haftanin_gunu <= 4 and 9 <= saat < 18:
        return "Müşteri hizmetlerimize 0850 XXX XX XX numaralı telefondan ulaşabilirsiniz."
    else:
        return "Şu an mesai saatleri dışındayız. Destek formu doldurarak bize ulaşabilirsiniz."

def check_faq_table(query_vector, db_conn, similarity_threshold=0.85):
    if db_conn is None:
        return None
        
    try:
        cursor = db_conn.cursor()
        vector_str = "[" + ",".join(map(str, query_vector)) + "]"
        query = """
            SELECT question, answer, (1 - (question_vector <=> %s::vector)) AS similarity
            FROM faq
            ORDER BY similarity DESC
            LIMIT 1;
        """
        cursor.execute(query, (vector_str,))
        top_faqs = cursor.fetchall()

        if top_faqs:
            question, answer, similarity = top_faqs[0]
            if similarity >= similarity_threshold:
                return answer
    except Exception:
        return None

    return None

# ==========================================
# 4. AŞAMA: MERKEZİ RAG MOTORU
# ==========================================
def cevabi_getir(kullanici_sorusu: str) -> str:
    temiz_kullanici_sorusu = kullanici_sorusu.strip()

    if not temiz_kullanici_sorusu:                                
        return "Lütfen sormak istediğiniz konuyu biraz daha detaylandırarak yazınız."

    if not soru_mantikli_mi(temiz_kullanici_sorusu):
        return "Sorunuzu tam olarak anlayamadım. Lütfen sorunuzu daha açık ve anlaşılır şekilde yazınız."
        
    e5_formatli_soru = f"query: {temiz_kullanici_sorusu}"

    # FAQ Kontrolü
    try:
        soru_vektoru = embedding_model([e5_formatli_soru])[0]
        faq_answer = check_faq_table(soru_vektoru, globals().get('db_connection'))
        if faq_answer:
            return faq_answer
    except Exception:
        pass
    
    # ChromaDB Arama
    sonuclar = collection.query(
        query_texts=[e5_formatli_soru],
        n_results=1 
    )

    if sonuclar['documents'] and len(sonuclar['documents'][0]) > 0:
        bulunan_cevap = sonuclar['documents'][0][0]
        mesafe = sonuclar['distances'][0][0] 
        
        if mesafe > 0.35:
            yonlendirme = musteri_hizmetlerine_yonlendir()
            return f"Bu konuyla ilgili kılavuzda net bir bilgi bulamadım. {yonlendirme}"
        else:
            insansi_cevap = re.sub(r'(?i)^\s*passage:\s*', '', bulunan_cevap)
            insansi_cevap = re.sub(r'(?i)^\s*madde\s*\d*\s*(f[ıi]kra\s*\d*)?\s*[.:;,-]?\s*', '', insansi_cevap)
            return insansi_cevap.strip()
    else:
        return "Sorunuza ait bilgiye ulaşılamadı. Lütfen farklı kelimelerle tekrar deneyiniz."

# ==========================================
# 5. AŞAMA: FASTAPI WEB SERVİSİ
# ==========================================
app = FastAPI(title="Chatbot RAG API")

class SoruIstek(BaseModel):
    kullanici_id: str = "kullanici_1" 
    mesaj: str 

@app.post("/api/rag/sor")
def rag_soru_sor(istek: SoruIstek):
    mesaj = istek.mesaj.strip()
    cevap = cevabi_getir(mesaj)
    return {"cevap": cevap}

# ==========================================
# 6. AŞAMA: SERVİSİ BAŞLATMA
# ==========================================
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)