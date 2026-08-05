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

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

logging.getLogger().setLevel(logging.ERROR)
nltk.download('punkt_tab', quiet=True)
analyzer = zeyrek.MorphAnalyzer()

def metin_koku_bul(metin):
    temiz_metin = re.sub(r'[^\w\s]', '', metin).lower()
    analiz_sonucu = analyzer.lemmatize(temiz_metin)
    kokler = []
    
    for kelime_analizi in analiz_sonucu:
        if kelime_analizi[1]: 
            kokler.append(kelime_analizi[1][0])
        else: 
            kokler.append(kelime_analizi[0])
            
    return " ".join(kokler)

def soru_mantikli_mi(soru):
    temiz_soru = re.sub(r'[^\w\s]', '', soru).lower()
    kelimeler = temiz_soru.split()
    
    if not kelimeler: 
        return False
        
    sesliler = "aeıioöuü"
    gecerli_kelime_sayisi = 0
    
    for kelime in kelimeler:
        if any(harf in sesliler for harf in kelime) or len(kelime) <= 2:
            gecerli_kelime_sayisi += 1
            
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
            benzerler = difflib.get_close_matches(kelime, pdf_kelime_havuzu, n=1, cutoff=0.8)
            if benzerler:
                duzeltilmis_kelimeler.append(benzerler[0])
            else:
                bilinmeyen_kelime_sayisi += 1 
                duzeltilmis_kelimeler.append(kelime)
                
    cok_yanlis_mi = False
    if len(kelimeler) > 0 and (bilinmeyen_kelime_sayisi / len(kelimeler)) >= 0.5:
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
    
    doc_id = f"madde_{i+1}"
    collection.upsert(
        documents=[madde_metni],
        ids=[doc_id]
    )

print("VEKTÖR HAVUZU BAŞARIYLA HAZIRLANDI VE KAYDEDİLDİ!\n")

# ==========================================
# MÜŞTERİ HİZMETLERİ YÖNLENDİRME FONKSİYONU
# ==========================================
def musteri_hizmetlerine_yonlendir():
    su_an = datetime.datetime.now()
    haftanin_gunu = su_an.weekday() 
    saat = su_an.hour
    
    if haftanin_gunu <= 4 and 9 <= saat < 18:
        return "Müşteri hizmetlerimize 0850 XXX XX XX numaralı telefondan ulaşabilirsiniz."
    else:
        return "Şu an mesai saatleri (Hafta içi 09:00 - 18:00) dışındayız. E-posta yollayarak en kısa sürede size geri dönüş yapılmasını sağlayabilirsiniz."

basarisiz_deneme_sayisi = 0
def check_faq_table(query_vector, db_connection, similarity_threshold=0.85):
    """
    Kullanıcının soru vektörünü FAQ tablosundaki popüler 3 soru ile kıyaslar.
    Eşleşme threshold üzerindeyse doğrudan cevabı döndürür.
    """
    cursor = db_connection.cursor()
    
    query = """
        SELECT question, answer, (1 - (question_vector <=> %s::vector)) AS similarity
        FROM faq
        ORDER BY similarity DESC
        LIMIT 3;
    """
    
    cursor.execute(query, (query_vector,))
    top_faqs = cursor.fetchall()

    if top_faqs:
        best_match = top_faqs[0] 
        question, answer, similarity = best_match
        
        if similarity >= similarity_threshold:
            return answer

    return None

# ==========================================
# 4. AŞAMA: MERKEZİ RAG MOTORU
# ==========================================
def cevabi_getir(kullanici_sorusu: str) -> str:
    global basarisiz_deneme_sayisi
    
    temiz_kullanici_sorusu = re.sub(r'[^\w\s]', '', kullanici_sorusu).lower()

    if not temiz_kullanici_sorusu:                              
        return "Lütfen bir daha sorun, daha açıklayıcı ifadeler kullanın."

    duzeltilmis_soru, cok_yanlis_mi = yazim_duzelt(temiz_kullanici_sorusu)
    
    if cok_yanlis_mi or not soru_mantikli_mi(duzeltilmis_soru):
        basarisiz_deneme_sayisi += 1
        if basarisiz_deneme_sayisi >= 3:
            yonlendirme = musteri_hizmetlerine_yonlendir()
            basarisiz_deneme_sayisi = 0
            return f"Üzgünüm, sorunuzu anlamakta zorlanıyorum. {yonlendirme}"
        return "Lütfen bir daha sorun, daha açıklayıcı ifadeler kullanın."
        
    temiz_soru = metin_koku_bul(duzeltilmis_soru)
    e5_formatli_soru = f"query: {temiz_soru}"
    # =========================================================================
    # 🌟 MELEK/MELİS'İN İSTEDİĞİ FAQ KONTROLÜ (PDF ARAMASININ ÖNÜNE)
    # =========================================================================
    # db_connection: Veritabanı bağlantı nesneniz
    faq_answer = check_faq_table(e5_formatli_soru, db_connection)
    if faq_answer:
        basarisiz_deneme_sayisi = 0
        return faq_answer
    # =========================================================================
    
    sonuclar = collection.query(
        query_texts=[e5_formatli_soru],
        n_results=1 
    )

    if sonuclar['documents'] and len(sonuclar['documents'][0]) > 0:
        bulunan_cevap = sonuclar['documents'][0][0]
        mesafe = sonuclar['distances'][0][0] 
        
        if mesafe > 0.16:
            basarisiz_deneme_sayisi += 1
            if basarisiz_deneme_sayisi >= 3:
                yonlendirme = musteri_hizmetlerine_yonlendir()
                basarisiz_deneme_sayisi = 0
                return f"Kılavuzda bu konuyla ilgili eşleşen bir bilgi bulamadım. {yonlendirme}"
            return "Lütfen bir daha sorun, sorunuzu daha açıklayıcı yazın."
        else:
            basarisiz_deneme_sayisi = 0 
            insansi_cevap = re.sub(r'(?i)^\s*madde\s*\d*\s*(f[ıi]kra\s*\d*)?\s*[.:;,-]?\s*', '', bulunan_cevap)
            insansi_cevap = re.split(r'(?i)\s*(?=\bMADDE\s+\d+\b|\bFIKRA\s+\d+\b)', insansi_cevap)[0]
            return insansi_cevap.strip()
    else:
        return "Veritabanında arama yapılamadı."

# ==========================================
# 5. AŞAMA: FASTAPI WEB SERVİS KATMANI VE OTURUM YÖNETİMİ
# ==========================================
app = FastAPI(title="Chatbot RAG API")

kullanici_oturum_durumu = {}

def evet_hayir_analiz_et(mesaj):
    gecerli_cevaplar = ["evet", "hayır", "hayir", "yes", "no"]
    
    if mesaj not in gecerli_cevaplar:
        benzerler = difflib.get_close_matches(mesaj, gecerli_cevaplar, n=1, cutoff=0.5)
        if benzerler:
            mesaj = benzerler[0]
            
    if mesaj == "hayir":
        mesaj = "hayır"
        
    return mesaj

class SoruIstek(BaseModel):
    kullanici_id: str = "kullanici_1" 
    mesaj: str 

@app.post("/api/rag/sor")
def rag_soru_sor(istek: SoruIstek):
    k_id = istek.kullanici_id
    mesaj = istek.mesaj.strip().lower()

    if k_id not in kullanici_oturum_durumu:
        kullanici_oturum_durumu[k_id] = {"durum": "soru_bekliyor", "hata_sayisi": 0}

    oturum = kullanici_oturum_durumu[k_id]

    if oturum["durum"] == "yanit_yeterli_mi_bekliyor":
        analiz_edilen_mesaj = evet_hayir_analiz_et(mesaj)
        
        if analiz_edilen_mesaj in ["evet", "yes"]:
            oturum["durum"] = "baska_soru_var_mi_bekliyor"
            oturum["hata_sayisi"] = 0
            return {"cevap": "Yardımcı olmamı istediğiniz başka bir konu var mı? (Evet/Hayır)"}
        
        elif analiz_edilen_mesaj in ["hayır", "no"]:
            oturum["durum"] = "soru_bekliyor"
            oturum["hata_sayisi"] = 0
            yonlendirme = musteri_hizmetlerine_yonlendir()
            return {"cevap": f"Anladım, size daha iyi destek olabilmemiz için {yonlendirme}"}
        
        else:
            oturum["hata_sayisi"] += 1
            if oturum["hata_sayisi"] >= 3:
                oturum["durum"] = "soru_bekliyor" 
                oturum["hata_sayisi"] = 0
                return {"cevap": "Geçersiz girişler yaptınız. Daha sonra tekrar soru sorabilirsiniz."}
            return {"cevap": "Lütfen sadece 'Evet' veya 'Hayır' yazınız."}

    elif oturum["durum"] == "baska_soru_var_mi_bekliyor":
        analiz_edilen_mesaj = evet_hayir_analiz_et(mesaj)
        
        if analiz_edilen_mesaj in ["evet", "yes"]:
            oturum["durum"] = "soru_bekliyor"
            oturum["hata_sayisi"] = 0
            return {"cevap": "Lütfen sormak istediğiniz yeni soruyu yazınız."}
        
        elif analiz_edilen_mesaj in ["hayır", "no"]:
            oturum["durum"] = "soru_bekliyor"
            oturum["hata_sayisi"] = 0
            return {"cevap": "Görüşmek üzere! İyi günler dileriz."}
        
        else:
            oturum["hata_sayisi"] += 1
            if oturum["hata_sayisi"] >= 3:
                oturum["durum"] = "soru_bekliyor" 
                oturum["hata_sayisi"] = 0
                return {"cevap": "Geçersiz girişler yaptınız. Daha sonra tekrar soru sorabilirsiniz."}
            return {"cevap": "Lütfen sadece 'Evet' veya 'Hayır' yazınız."}

    else:
        cevap = cevabi_getir(mesaj)
        
        hata_kelimeleri = ["Lütfen bir daha", "Üzgünüm", "Kılavuzda", "Veritabanında"]
        basarili_bir_cevap_mi = not any(hata in cevap for hata in hata_kelimeleri)

        if basarili_bir_cevap_mi:
            oturum["durum"] = "yanit_yeterli_mi_bekliyor"
            return {"cevap": f"{cevap}\n\nBu yanıt yeterli oldu mu? (Evet/Hayır)"}
        else:
            return {"cevap": cevap}

# ==========================================
# 6. AŞAMA: SERVİSİ BAŞLATMA
# ==========================================
if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
