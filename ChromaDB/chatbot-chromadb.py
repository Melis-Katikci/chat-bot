import os
import re
import chromadb
from chromadb.utils import embedding_functions
from pypdf import PdfReader

# ==========================================
# 1. AŞAMA: CHROMADB VE MODEL HAZIRLIĞI
# ==========================================
print("1. ChromaDB başlatılıyor ve Vektör Modeli yükleniyor...")

# Bilgisayarın Masaüstü yolunu otomatik olarak bulur (Kullanıcı adı ne olursa olsun çalışır)
masaustu_yolu = os.path.join(os.path.expanduser("~"), "Desktop")
db_kayit_yolu = os.path.join(masaustu_yolu, "chroma_db_abone")

print(f"-> Veritabanı doğrudan Masaüstüne kaydediliyor: {db_kayit_yolu}")

# Seçtiğin Masaüstü yoluna veritabanı klasörünü oluşturur/bağlanır
client = chromadb.PersistentClient(path=db_kayit_yolu)

# Metinleri sayılara (vektörlere) çevirecek yapay zeka modelimiz
embedding_model = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")

# Koleksiyonumuzu (Tablomuzu) oluşturuyoruz
collection = client.get_or_create_collection(
    name="abonesepeti_yonerge",
    embedding_function=embedding_model
)

# ==========================================
# 2. AŞAMA: PDF OKUMA VE MADDELERE BÖLME
# ==========================================
pdf_yolu = r"C:\Users\ereno\Desktop\chat-bot\ChromaDB\aboneSepetiYonerge.pdf"

print(f"2. '{pdf_yolu}' dosyası okunuyor...")
reader = PdfReader(pdf_yolu)
tam_metin = ""

# PDF'teki tüm sayfaları okuyup tek bir metin haline getiriyoruz
for sayfa in reader.pages:
    metin = sayfa.extract_text()
    if metin:
        tam_metin += metin + " "

# Kılavuzdaki "MADDE" kelimesine göre metni akıllıca parçalara ayırıyoruz.
maddeler = re.split(r'(?=\bMADDE\b)', tam_metin, flags=re.IGNORECASE)

# Boş parçaları temizleyip metinleri düzenliyoruz
temiz_maddeler = [m.strip() for m in maddeler if len(m.strip()) > 10]

print(f"-> PDF'ten toplam {len(temiz_maddeler)} adet madde çıkarıldı.\n")
print("="*60)
print("3. VEKTÖRLEŞTİRME VE TERMINAL KONTROLÜ BAŞLIYOR")
print("="*60)

# ==========================================
# 3. AŞAMA: VEKTÖRLEŞTİRME VE TERMİNALE YAZDIRMA
# ==========================================

# Her bir maddeyi tek tek işliyoruz
for i, madde_metni in enumerate(temiz_maddeler):
    
    # 1. Metni Manuel Olarak Vektöre Çeviriyoruz
    vektor = embedding_model([madde_metni])[0]
    
    # 2. Terminale Senin İstediğin Formatta Yazdırıyoruz
    gosterilecek_icerik = madde_metni.replace('\n', ' ')
    if len(gosterilecek_icerik) > 150:
        gosterilecek_icerik = gosterilecek_icerik[:150] + "..."
        
    v1, v2, v3 = vektor[0], vektor[1], vektor[2]
    
    print(f"İçerik: {gosterilecek_icerik}")
    print(f"Vektör (İlk 3 Boyut): [ {v1:.6f} {v2:.6f} {v3:.6f} ]")
    print("-" * 60)
    
    # 3. Veriyi ChromaDB'ye Kaydediyoruz
    doc_id = f"madde_{i+1}"
    collection.add(
        documents=[madde_metni],
        ids=[doc_id]
    )

print("\nVEKTÖR HAVUZU BAŞARIYLA OLUŞTURULDU VE KAYDEDİLDİ!")
print(f"Veriler Masaüstündeki şu klasöre kaydedildi: {db_kayit_yolu}")
print("Artık chatbot'un bu veriler üzerinde arama yapabilir.")