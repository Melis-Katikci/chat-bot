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
@CrossOrigin(origins = "*")
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
            // 1. Kullanıcıyı Bul veya Varsayılan Bir Kullanıcı İle Eşleştir (user_id zorunlu olduğu için)
            User user = userRepository.findById(1L).orElse(null); // id=1 olan kullanıcı
            if (user == null) {
                user = userRepository.findAll().stream().findFirst().orElse(null);
            }

            if (user == null) {
                response.put("success", false);
                response.put("message", "Sistemde kayıtlı kullanıcı bulunamadı.");
                return ResponseEntity.badRequest().body(response);
            }

            // 2. SupportForm Nesnesini Oluştur
            SupportForm form = new SupportForm();
            form.setUser(user);
            form.setComplaintTitle(requestData.getOrDefault("subject", requestData.getOrDefault("complaintTitle", "Konusuz")));
            form.setComplaintSummary(requestData.getOrDefault("message", requestData.getOrDefault("complaintSummary", "-")));
            form.setStatus("Beklemede");
            form.setIsMailed(true);

            // 3. Veritabanına Kaydet
            SupportForm savedForm = supportFormRepository.save(form);

            // 4. E-posta Gönder
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