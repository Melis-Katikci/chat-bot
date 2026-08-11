package com.chatbot.controller;

import com.chatbot.model.ChatLog;
import com.chatbot.model.Faq;
import com.chatbot.repository.ChatLogRepository;
import com.chatbot.repository.FaqRepository;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*") // Live Server, Flutter Web ve Mobil bağlantı izni
public class ChatController {

    private final ChatLogRepository chatLogRepository;
    private final FaqRepository faqRepository;
    private final RestTemplate restTemplate;

    public ChatController(ChatLogRepository chatLogRepository, FaqRepository faqRepository) {
        this.chatLogRepository = chatLogRepository;
        this.faqRepository = faqRepository;
        this.restTemplate = new RestTemplate();
    }

    // Hem /api/chat hem de /api/chat/ask isteklerini karşılar
    @PostMapping({"", "/ask"})
    public Map<String, String> askQuestion(@RequestBody Map<String, Object> request) {
        // 1. Esnek Parametre Yakalama: 'message' veya 'question' hangisi gelirse onu al
        String userQuery = null;
        if (request.get("message") != null) {
            userQuery = request.get("message").toString();
        } else if (request.get("question") != null) {
            userQuery = request.get("question").toString();
        }

        Integer userId = null;
        if (request.get("userId") != null) {
            try {
                userId = Integer.valueOf(request.get("userId").toString());
            } catch (Exception ignored) {}
        }

        String aiResponse = null;

        // 2. Önce Veritabanındaki FAQ Tablosunu Tara
        try {
            List<Faq> faqList = faqRepository.findAll();

            for (Faq faq : faqList) {
                if (faq.getQuestion() != null && userQuery != null &&
                    (userQuery.toLowerCase().contains(faq.getQuestion().toLowerCase()) ||
                     faq.getQuestion().toLowerCase().contains(userQuery.toLowerCase()))) {
                    
                    aiResponse = faq.getAnswer();
                    break; // Cevap bulundu
                }
            }
        } catch (Exception e) {
            System.err.println("FAQ tablosu taranırken hata oluştu: " + e.getMessage());
        }

        // 3. FAQ tablosunda bulunamadıysa Python FastAPI Servisine Git (RAG)
        if (aiResponse == null || aiResponse.isBlank()) {
            try {
                String pythonUrl = "http://127.0.0.1:8000/api/rag/sor";

                Map<String, String> pythonRequest = new HashMap<>();
                pythonRequest.put("mesaj", userQuery);

                @SuppressWarnings("unchecked")
                Map<String, String> pythonResponse = (Map<String, String>) restTemplate.postForObject(pythonUrl, pythonRequest, Map.class);

                if (pythonResponse != null) {
                    aiResponse = pythonResponse.get("cevap") != null 
                            ? pythonResponse.get("cevap") 
                            : pythonResponse.get("mesaj");
                }

                if (aiResponse == null || aiResponse.isBlank()) {
                    aiResponse = "Python servisinden boş yanıt döndü.";
                }

            } catch (Exception e) {
                aiResponse = "RAG servisine ulaşılamadı: " + e.getMessage();
            }
        }

        // 4. PostgreSQL 'chat_logs' Tablosuna Kaydet
        try {
            ChatLog log = new ChatLog();
            log.setUserId(userId);
            log.setUserQuery(userQuery);
            log.setAiResponse(aiResponse);

            chatLogRepository.save(log);
        } catch (Exception e) {
            System.err.println("Chat log kaydedilirken hata oluştu: " + e.getMessage());
        }

        // 5. İstemciye Cevabı Dön (Hem 'answer' hem 'response' key'lerini ekliyoruz)
        Map<String, String> response = new HashMap<>();
        response.put("answer", aiResponse);
        response.put("response", aiResponse);
        
        return response;
    }
}