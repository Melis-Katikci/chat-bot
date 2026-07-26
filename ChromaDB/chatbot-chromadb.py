import os
import re
import chromadb
import zeyrek  
import difflib
import logging
from chromadb.utils import embedding_functions
from pypdf import PdfReader
import nltk

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
# -------------------------------------------------

def soru_mantikli_mi(soru):
    temiz_soru = re.sub(r'[^\w\s]', '', soru).lower()
    kelimeler = temiz_soru.split()
    
    if not kelimeler: # Eğer sadece boşluk atıldıysa
        return False
        
    sesliler = "aeıioöuü"
    gecerli_kelime_sayisi = 0
    
    for kelime in kelimeler:
        # Kelimenin içinde en az 1 sesli harf varsa veya çok kısaysa (örn: "ve", "ağ") geçerli say
        if any(harf in sesliler for harf in kelime) or len(kelime) <= 2:
            gecerli_kelime_sayisi += 1
            
    # Eğer cümlenin yarısından fazlası sesli harf içermeyen saçma kelimelerdense (randomsa)
    if (gecerli_kelime_sayisi / len(kelimeler)) < 0.5:
        return False
        
    return True

def yazim_duzelt(metin):
    duzeltilmis_kelimeler = []
    bilinmeyen_kelime_sayisi = 0 # Ne kadar kelimenin anlaşılamadığını sayacağız
    kelimeler = metin.split()
    
    for kelime in kelimeler:
        if kelime in pdf_kelime_havuzu:
            duzeltilmis_kelimeler.append(kelime)
        else:
            benzerler = difflib.get_close_matches(kelime, pdf_kelime_havuzu, n=1, cutoff=0.6)
            if benzerler:
                duzeltilmis_kelimeler.append(benzerler[0])
            else:
                bilinmeyen_kelime_sayisi += 1 # Kelime düzeltilemedi!
                duzeltilmis_kelimeler.append(kelime)
                
    # Kullanıcının girdiği kelimelerin yarısından fazlası anlamsız/bulunamaz durumdaysa
    cok_yanlis_mi = False
    if len(kelimeler) > 0 and (bilinmeyen_kelime_sayisi / len(kelimeler)) > 0.5:
        cok_yanlis_mi = True
            
    # Artık hem düzeltilmiş metni hem de "çok yanlış mı" durumunu geri döndürüyoruz
    return " ".join(duzeltilmis_kelimeler), cok_yanlis_mi

# ==========================================
# 1. AŞAMA: CHROMADB VE MODEL HAZIRLIĞI
# ==========================================
print("1. ChromaDB başlatılıyor ve Vektör Modeli yükleniyor...")

# Python dosyasının (scriptin) o an bulunduğu tam klasör yolunu bulur
mevcut_klasor = os.path.dirname(os.path.abspath(__file__))
db_kayit_yolu = os.path.join(mevcut_klasor, "chroma_db_abone")

# Seçtiğin Masaüstü yoluna veritabanı klasörünü oluşturur/bağlanır
client = chromadb.PersistentClient(path=db_kayit_yolu)

# Metinleri sayılara (vektörlere) çevirecek yapay zeka modelimiz
embedding_model = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="intfloat/multilingual-e5-base")

# Koleksiyonumuzu (Tablomuzu) oluşturuyoruz
collection = client.get_or_create_collection(
    name="abonesepeti_yonerge_e5_cosine", # İsmi değiştirdik ki temiz bir tablo açılsın
    embedding_function=embedding_model,
    metadata={"hnsw:space": "cosine"} # YENİ EKLENDİ: E5 modeli için şart olan ayar
)
# ==========================================
# 2. AŞAMA: PDF OKUMA VE MADDELERE BÖLME
# ==========================================
# Python dosyasının (scriptin) o an bulunduğu tam klasör yolunu otomatik bulur
mevcut_klasor = os.path.dirname(os.path.abspath(__file__))

# Klasör yolu ile PDF dosyasının adını güvenli bir şekilde birleştirir
pdf_yolu = os.path.join(mevcut_klasor, "aboneSepetiYonerge.pdf")

print(f"2. '{pdf_yolu}' dosyası okunuyor...")
reader = PdfReader(pdf_yolu)
tam_metin = ""

# PDF'teki tüm sayfaları okuyup tek bir metin haline getiriyoruz
for sayfa in reader.pages:
    metin = sayfa.extract_text()
    if metin:
        tam_metin += metin + " "

temiz_tam_metin = re.sub(r'[^\w\s]', '', tam_metin).lower()
pdf_kelime_havuzu = set(temiz_tam_metin.split())


# Kılavuzdaki "MADDE" kelimesine göre metni akıllıca parçalara ayırıyoruz...
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
    
    # YENİ EKLENDİ: Aramayı güçlendirmek için metnin köklerini çıkarıyoruz
    kok_metin = metin_koku_bul(madde_metni)
    
    # 1. Vektörü ORİJİNAL metinden değil, ZEYREK ile temizlenmiş KÖK metinden oluşturuyoruz
    vektor = embedding_model([kok_metin])[0]
    
    # 2. Terminale Yazdırma (Aynı kalıyor)
    gosterilecek_icerik = madde_metni.replace('\n', ' ')
    if len(gosterilecek_icerik) > 150:
        gosterilecek_icerik = gosterilecek_icerik[:150] + "..."
        
    v1, v2, v3 = vektor[0], vektor[1], vektor[2]
    print(f"İçerik: {gosterilecek_icerik}")
    print(f"Vektör (İlk 3 Boyut): [ {v1:.6f} {v2:.6f} {v3:.6f} ]")
    print("-" * 60)
    
    # 3. Veriyi ChromaDB'ye Kaydediyoruz
    doc_id = f"madde_{i+1}"
    collection.upsert( # upsert olarak değiştirmeyi unutma
        documents=[madde_metni], # Kullanıcıya göstereceğimiz için orijinal metni kaydediyoruz
        ids=[doc_id]
    )

print("\nVEKTÖR HAVUZU BAŞARIYLA OLUŞTURULDU VE KAYDEDİLDİ!")
print(f"Veriler Masaüstündeki şu klasöre kaydedildi: {db_kayit_yolu}")
print("Artık chatbot'un bu veriler üzerinde arama yapabilir.")

# ==========================================
# 4. AŞAMA: Soru-Cevap Döngüsü (Terminal Arayüzü)
# ==========================================
print("\n" + "="*60)
print("Sistem Hazır! Belge ile ilgili sorularınızı sorabilirsiniz.")
print("Çıkmak için 'q', 'çıkış' veya 'exit' yazın.")
print("="*60 + "\n")

while True:
    kullanici_sorusu = input("\nSorunuz: ").strip()
    
    # Çıkış kontrolü
    if kullanici_sorusu.lower() in ['q', 'çıkış', 'exit']:
        print("Sistemden çıkılıyor. İyi çalışmalar!")
        break
        
    # --- 1. AŞAMA: YAZIM HATALARINI SESSİZCE DÜZELT ---
    temiz_kullanici_sorusu = re.sub(r'[^\w\s]', '', kullanici_sorusu).lower()
    
    # Kullanıcı sadece boşluk veya noktalama atıp enter'a bastıysa
    if not temiz_kullanici_sorusu:
        print("🤖 Bot: Eksik veya hatalı yazdınız lütfen bir daha deneyiniz.")
        continue

    # Güncellediğimiz fonksiyondan iki farklı değer alıyoruz
    duzeltilmis_soru, cok_yanlis_mi = yazim_duzelt(temiz_kullanici_sorusu)
    
    # --- 2. AŞAMA: RANDOM VEYA EKSİK/HATALI YAZIM KONTROLÜ ---
    # Soru çok yanlış yazılmışsa VEYA tamamen rastgele harflerden (random) oluşuyorsa aynı mesajı ver
    if cok_yanlis_mi or not soru_mantikli_mi(duzeltilmis_soru):
        print("🤖 Bot: Eksik veya hatalı yazdınız lütfen bir daha deneyiniz.")
        continue
        
    # --- 3. AŞAMA: ZEYREK İLE KÖK BULMA VE ARAMA ---
    # Kökleri artık düzeltilmiş, tertemiz sorudan çıkarıyoruz
    temiz_soru = metin_koku_bul(duzeltilmis_soru)
    
    e5_formatli_soru = f"query: {temiz_soru}"
    
    # ChromaDB'ye gönderiyoruz
    sonuclar = collection.query(
        query_texts=[e5_formatli_soru],
        n_results=1 
    )
    
    # Sonuçları ekrana yazdırma
    if sonuclar['documents'] and len(sonuclar['documents'][0]) > 0:
        bulunan_cevap = sonuclar['documents'][0][0]
        mesafe = sonuclar['distances'][0][0] 
        
        maksimum_mesafe_siniri = 0.30 
        
        if mesafe > maksimum_mesafe_siniri:
            print("\n🤖 Bot: Üzgünüm, kılavuzda bu soruyla ilgili spesifik bir bilgi bulamadım.")
        else:
            # Metnin başındaki "MADDE 1", "MADDE 5 -" gibi kısımları akıllıca temizler
            insansi_cevap = re.sub(r'(?i)^\s*madde\s*\d*\s*[.:-]?\s*', '', bulunan_cevap)
            
            print(f"\n🤖 Bot: {insansi_cevap.strip()}")
    
    else:
        print("\n🤖 Bot: Veritabanında arama yapılamadı.")