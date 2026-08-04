<?php
header('Content-Type: application/json');

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require 'vendor/autoload.php';

// Frontend'den gelen veriyi alma
$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    echo json_encode(['success' => false, 'message' => 'Geçersiz veri!']);
    exit;
}

// -------------------------------------------------------------
// 1. VERİTABANI BAĞLANTISI, SQL DOĞRULAMA VE VT KAYIT KONTROLÜ
// -------------------------------------------------------------
$host = 'localhost';
$dbname = 'veritabani_adiniz'; // Veritabanı adınızı girin
$username = 'root';            // Veritabanı kullanıcı adınızı girin
$password = '';                // Veritabanı şifrenizi girin

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Mükerrer Kayıt Kontrolü: Aynı e-posta ile son 5 dakika içinde talep var mı?
    $checkStmt = $pdo->prepare("SELECT COUNT(*) FROM support_requests WHERE email = :email AND created_at > NOW() - INTERVAL 5 MINUTE");
    $checkStmt->execute([':email' => $data['email']]);
    
    if ($checkStmt->fetchColumn() > 0) {
        echo json_encode(['success' => false, 'message' => 'Lütfen yeni bir talep göndermek için 5 dakika bekleyin.']);
        exit;
    }

    // SQL Doğrulama ve Güvenli Ekleme (Prepared Statement / SQL Injection Korumalı)
    $sql = "INSERT INTO support_requests (name, email, phone, subject, message) 
            VALUES (:name, :email, :phone, :subject, :message)";
            
    $stmt = $pdo->prepare($sql);
    
    // Verileri güvenli şekilde parametre olarak bağlayıp çalıştırma
    $insertSuccess = $stmt->execute([
        ':name'    => $data['name'],
        ':email'   => $data['email'],
        ':phone'   => $data['phone'],
        ':subject' => $data['subject'],
        ':message' => $data['message']
    ]);

    // VT Kayıt Başarı Kontrolü
    if (!$insertSuccess) {
        echo json_encode(['success' => false, 'message' => 'Veritabanına kayıt yapılamadı!']);
        exit;
    }

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Veritabanı hatası: ' . $e->getMessage()]);
    exit;
}

// -------------------------------------------------------------
// 2. E-POSTA BİLDİRİMİ GÖNDERİMİ
// -------------------------------------------------------------
$mail = new PHPMailer(true);

try {
    // SMTP Sunucu Ayarları
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = 'sizin_epostaniz@gmail.com'; // Gönderici mail adresi
    $mail->Password   = 'smtp_uygulama_sifreniz';   // Uygulama şifreniz
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;
    $mail->CharSet    = 'UTF-8';

    // Alıcı ve Gönderici Bilgileri
    $mail->setFrom('sizin_epostaniz@gmail.com', 'Chatbot Destek Formu');
    $mail->addAddress('destek_ekibi@sirketiniz.com'); // Destek ekibinizin maili

    // İçerik
    $mail->isHTML(true);
    $mail->Subject = 'Yeni Destek/Şikayet Talebi: ' . $data['subject'];
    $mail->Body    = "
        <h2>Yeni Bir Destek / Şikayet Talebi Oluşturuldu</h2>
        <p><strong>Ad Soyad:</strong> {$data['name']}</p>
        <p><strong>E-Posta:</strong> {$data['email']}</p>
        <p><strong>Telefon:</strong> {$data['phone']}</p>
        <p><strong>Başlık:</strong> {$data['subject']}</p>
        <p><strong>Mesaj/Şikayet Detayı:</strong><br>{$data['message']}</p>
    ";

    $mail->send();
    echo json_encode(['success' => true, 'message' => 'Talebiniz başarıyla kaydedildi ve e-posta gönderildi.']);

} catch (Exception $e) {
    // Veri VT'ye kaydolduğu için mail gitmese de kullanıcıya olumlu dönüş yapılır
    echo json_encode(['success' => true, 'message' => 'Talebiniz kaydedildi ancak e-posta bildiriminde aksama oldu.']);
}
?>
