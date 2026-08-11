package com.chatbot.controller;

import com.chatbot.model.SupportForm;
import com.chatbot.model.User;
import com.chatbot.repository.SupportFormRepository;
import com.chatbot.repository.UserRepository;
import com.chatbot.service.EmailService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/support")
@CrossOrigin(origins = "*") // Flutter Web ve Mobil istemciler için CORS izni
public class SupportController {

    private final SupportFormRepository supportFormRepository;
    private final UserRepository userRepository;
    private final EmailService emailService;

    public SupportController(SupportFormRepository supportFormRepository, UserRepository userRepository, EmailService emailService) {
        this.supportFormRepository = supportFormRepository;
        this.userRepository = userRepository;
        this.emailService = emailService;
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createSupportRequest(@RequestBody Map<String, String> requestData) {
        Map<String, Object> response = new HashMap<>();
        try {
            // Flutter ve Web arayüzünden gelen parametreleri güvenli şekilde alıyoruz
            String name = requestData.getOrDefault("name", "Misafir Kullanıcı");
            String email = requestData.getOrDefault("email", "misafir@example.com");
            String phone = requestData.getOrDefault("phone", "");
            String subject = requestData.getOrDefault("subject", requestData.getOrDefault("complaintTitle", "Konusuz"));
            String message = requestData.getOrDefault("message", requestData.getOrDefault("complaintSummary", "-"));

            // 1. Kullanıcıyı Bul veya Veritabanı Boşsa Otomatik Oluştur
            User user = userRepository.findById(1L).orElse(null);
            
            if (user == null) {
                user = userRepository.findAll().stream().findFirst().orElse(null);
            }

            // Veritabanında hiç kullanıcı yoksa kayıt işleminin çökmemesi için otomatik bir kullanıcı oluşturur
            if (user == null) {
                user = new User();
                user.setFirstName(name);
                user.setLastName("");
                user.setEmail(email);
                user.setPhoneNumber(phone);
                user = userRepository.save(user);
            }

            // 2. SupportForm Nesnesini Oluştur
            SupportForm form = new SupportForm();
            form.setUser(user);
            form.setComplaintTitle(subject);
            form.setComplaintSummary(message);
            form.setStatus("Beklemede");
            form.setIsMailed(true);

            // 3. Veritabanına Kaydet (PostgreSQL)
            SupportForm savedForm = supportFormRepository.save(form);

            // 4. E-posta Gönder (Gmail SMTP)
            emailService.sendSupportEmail(savedForm);

            response.put("success", true);
            response.put("message", "Talebiniz başarıyla alındı.");
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Hata oluştu: " + e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }
}