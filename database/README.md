# PostgreSQL Veritabanı Kurulumu

## Kullanılan Veritabanı
PostgreSQL

## Kurulum

1. PostgreSQL'i bilgisayarınıza kurun.
2. pgAdmin veya DBeaver üzerinden yeni bir veritabanı oluşturun.
3. Veritabanı adını örneğin `chatbot_db` olarak belirleyin.
4. `database/init.sql` dosyasını çalıştırarak tabloları oluşturun.
5. `database/sample_data.sql` dosyasını çalıştırarak örnek kullanıcı verilerini ekleyin.
6. Veritabanı kullanıma hazırdır.

---

# Veritabanı Tabloları

## 1. users

Sisteme kayıtlı kullanıcı bilgilerini tutar.

| Kolon | Açıklama |
|--------|----------|
| id | Otomatik oluşturulan kullanıcı numarası |
| first_name | Kullanıcının adı |
| last_name | Kullanıcının soyadı |
| phone_number | Benzersiz telefon numarası |
| email | Benzersiz e-posta adresi |

---

## 2. chat_logs

Kullanıcı ile chatbot arasında gerçekleşen konuşmaları saklar.

| Kolon | Açıklama |
|--------|----------|
| id | Konuşma kayıt numarası |
| user_id | Soruyu soran kullanıcı |
| user_query | Kullanıcının sorduğu soru |
| ai_response | Yapay zekânın verdiği cevap |
| is_escalated | Destek ekibine yönlendirildi mi? |
| created_at | Konuşmanın oluşturulma tarihi |

---

## 3. support_forms

Chatbotun çözemediği veya kullanıcının oluşturduğu destek taleplerini saklar.

| Kolon | Açıklama |
|--------|----------|
| id | Destek talep numarası |
| user_id | Talebi oluşturan kullanıcı |
| complaint_title | Talep başlığı |
| complaint_summary | Talep açıklaması |
| status | Talep durumu (Beklemede / İnceleniyor / Çözüldü) |
| is_mailed | Destek ekibine e-posta gönderildi mi? |
| created_at | Talebin oluşturulma tarihi |

---

## 4. faq

Chatbot tarafından öğrenilen soru-cevap kayıtlarını saklar.

> Bu tablo başlangıçta boştur. Uygulama çalıştıkça yeni soru-cevap kayıtları otomatik olarak eklenir ve benzer soruların kullanım sayısı güncellenir.

| Kolon | Açıklama |
|--------|----------|
| id | Kayıt numarası |
| question | Kullanıcının sorduğu soru |
| answer | Yapay zekânın verdiği cevap |
| usage_count | Sorunun kaç kez kullanıldığı |
| created_at | İlk oluşturulma tarihi |
| updated_at | Son güncellenme tarihi |

---

# Çalışma Mantığı

- `users` tablosu örnek kullanıcılarla birlikte oluşturulur.
- `chat_logs` tablosu kullanıcılar chatbot ile konuşmaya başladıkça otomatik olarak dolar.
- `faq` tablosu başlangıçta boştur. Kullanıcılardan gelen yeni soru-cevaplar uygulama tarafından otomatik olarak eklenir ve kullanım sayıları güncellenir.
- `support_forms` tablosu yalnızca chatbot soruyu çözemediğinde veya kullanıcı destek talebi oluşturduğunda otomatik olarak kayıt oluşturur.