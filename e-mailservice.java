package com.chatbot.service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    // Constructor Injection: Spring'de bağımlılıkları yönetmenin en modern ve güvenli yoludur.
    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String senderEmail;

    // Alıcı adresini koda gömmek yerine application.properties'den dinamik olarak alıyoruz.
    @Value("${app.mail.support-recipient}")
    private String recipientEmail;

    /**
     * Gelen destek/şikayet talebini alıp destek ekibine e-posta olarak iletir.
     * 
     * @param requestData Frontend'den gelen form verilerini içeren Map.
     */
    public void sendSupportEmail(Map<String, String> requestData) {
        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

            String subject = "Yeni Destek/Şikayet Talebi: " + requestData.get("subject");
            String htmlContent = buildHtmlContent(requestData);

            helper.setFrom(senderEmail);
            helper.setTo(recipientEmail);
            helper.setSubject(subject);
            helper.setText(htmlContent, true);

            mailSender.send(mimeMessage);
            
            // İşlem başarılı olduğunda konsola bilgi logu düşeriz
            log.info("Destek e-postası başarıyla gönderildi. Gönderen: {}", requestData.get("email"));
            
        } catch (MessagingException e) {
            // Hata sessizce yutulmaz, sisteme loglanır ve programın akışı uyarılır
            log.error("E-posta gönderimi sırasında hata oluştu. Alıcı: {}", recipientEmail, e);
            throw new RuntimeException("E-posta sunucusuna ulaşılamadı veya gönderim başarısız.", e);
        }
    }

    /**
     * E-posta HTML içeriğini Java "Text Blocks" (üç tırnak) özelliği ile 
     * çok daha okunaklı ve düzenli bir şekilde oluşturur.
     */
    private String buildHtmlContent(Map<String, String> requestData) {
        return String.format("""
                <h2>Yeni Bir Destek / Şikayet Talebi Oluşturuldu</h2>
                <p><strong>Ad Soyad:</strong> %s</p>
                <p><strong>E-Posta:</strong> %s</p>
                <p><strong>Telefon:</strong> %s</p>
                <p><strong>Başlık:</strong> %s</p>
                <p><strong>Mesaj/Şikayet Detayı:</strong><br>%s</p>
                """, 
                requestData.get("name"), 
                requestData.get("email"), 
                requestData.get("phone"), 
                requestData.get("subject"), 
                requestData.get("message"));
    }
}