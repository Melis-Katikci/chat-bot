<?php
header('Content-Type: application/json');

// PHPMailer kütüphanesini projeye dahil ediyoruz
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require 'vendor/autoload.php'; // Composer kullanıyorsan bu satır kalabilir

// Frontend (script.js) tarafından gönderilen JSON verisini alma
$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    echo json_encode(['success' => false, 'message' => 'Geçersiz veri!']);
    exit;
}

$mail = new PHPMailer(true);

try {
    // SMTP Sunucu Ayarları
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com'; // Kullanacağınız SMTP sunucusu (örn: smtp.gmail.com)
    $mail->SMTPAuth   = true;
    $mail->Username   = 'sizin_epostaniz@gmail.com'; // Gönderen e-posta adresiniz
    $mail->Password   = 'smtp_uygulama_sifreniz';   // E-posta SMTP/Uygulama şifreniz
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;
    $mail->CharSet    = 'UTF-8';

    // Gönderen ve Alıcı Bilgileri
    $mail->setFrom('sizin_epostaniz@gmail.com', 'Chatbot Destek Formu');
    $mail->addAddress('destek_ekibi@sirketiniz.com'); // Şikayet formunun düşeceği mail adresi

    // E-posta İçeriği (HTML)
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
    echo json_encode(['success' => true, 'message' => 'E-posta başarıyla gönderildi.']);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => "Mail gönderilemedi. Hata: {$mail->ErrorInfo}"]);
}
?>