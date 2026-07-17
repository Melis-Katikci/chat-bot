# PostgreSQL Veritabanı Kurulumu

## Kullanılan Veritabanı
PostgreSQL

## Kurulum

1. PostgreSQL ve pgAdmin'i kurun.
2. pgAdmin üzerinden yeni bir veritabanı oluşturun.
3. Veritabanı adını örneğin `subscription_db` olarak belirleyin.
4. `database/init.sql` dosyasını çalıştırın.
5. Ardından `database/sample_data.sql` dosyasını çalıştırın.
6. Veritabanı kullanıma hazırdır.

## Tablolar

- users

## users Tablosu

| Kolon | Açıklama |
|--------|----------|
| id | Otomatik kullanıcı numarası |
| first_name | Kullanıcı adı |
| last_name | Kullanıcı soyadı |
| phone_number | Benzersiz telefon numarası |
| email | Benzersiz e-posta adresi |