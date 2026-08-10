package com.chatbot.service;

import com.chatbot.model.SupportForm;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String senderEmail;

    @Value("${app.mail.support-recipient:${spring.mail.username}}")
    private String recipientEmail;

    /**
     * SupportForm entity'si üzerinden HTML formatında e-posta gönderir.
     */
    public void sendSupportEmail(SupportForm form) {
        if (form == null) {
            log.warn("Gelen destek formu boş (null) olduğu için e-posta gönderilemedi.");
            return;
        }

        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true, "UTF-8");

            // User ve Alan Kontrolleri
            String userEmail = (form.getUser() != null && form.getUser().getEmail() != null) 
                    ? form.getUser().getEmail() 
                    : "Belirtilmedi";

            String title = (form.getComplaintTitle() != null && !form.getComplaintTitle().isBlank()) 
                    ? form.getComplaintTitle() 
                    : "Konusuz Talepler";

            String summary = (form.getComplaintSummary() != null && !form.getComplaintSummary().isBlank()) 
                    ? form.getComplaintSummary() 
                    : "-";

            String subject = "Yeni Destek/Şikayet Talebi: " + title;

            // HTML Formatındaki İçerik
            String htmlContent = String.format("""
                    <h2>Yeni Bir Destek / Şikayet Talebi Oluşturuldu</h2>
                    <p><strong>Kullanıcı E-Posta:</strong> %s</p>
                    <p><strong>Şikayet Başlığı:</strong> %s</p>
                    <p><strong>Şikayet Özeti / Detay:</strong><br>%s</p>
                    <p><strong>Durum:</strong> %s</p>
                    """, userEmail, title, summary, form.getStatus() != null ? form.getStatus() : "Beklemede");

            helper.setFrom(senderEmail);
            helper.setTo(recipientEmail);
            helper.setSubject(subject);
            helper.setText(htmlContent, true);

            mailSender.send(mimeMessage);

            log.info("Destek e-postası başarıyla gönderildi. Başlık: {}", title);

        } catch (MessagingException e) {
            log.error("E-posta gönderimi sırasında hata oluştu. Alıcı: {}", recipientEmail, e);
            throw new RuntimeException("E-posta sunucusuna ulaşılamadı veya gönderim başarısız.", e);
        }
    }
}