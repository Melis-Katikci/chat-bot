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
@CrossOrigin(origins = "*") // Live Server ve Frontend bağlantı izni
public class ChatController {

    private final ChatLogRepository chatLogRepository;
    private final FaqRepository faqRepository;
    private final RestTemplate restTemplate;

    public ChatController(ChatLogRepository chatLogRepository, FaqRepository faqRepository) {
        this.chatLogRepository = chatLogRepository;
        this.faqRepository = faqRepository;
        this.restTemplate = new RestTemplate();
    }

    @PostMapping("/ask")
    public Map<String, String> askQuestion(@RequestBody Map<String, Object> request) {
        String userQuery = (String) request.get("question");

        Integer userId = null;
        if (request.get("userId") != null) {
            userId = Integer.valueOf(request.get("userId").toString());
        }

        String aiResponse = null;

        // 1. Önce Veritabanındaki FAQ Tablosunu Tara
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

        // 2. FAQ tablosunda bulunamadıysa Python FastAPI Servisine Git (RAG)
        if (aiResponse == null || aiResponse.isBlank()) {
            try {
                String pythonUrl = "http://127.0.0.1:8000/api/rag/sor";

                Map<String, String> pythonRequest = new HashMap<>();
                // Python FastAPI servisi 'mesaj' anahtarını bekliyor
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

        // 3. PostgreSQL 'chat_logs' Tablosuna Kaydet
        ChatLog log = new ChatLog();
        log.setUserId(userId);
        log.setUserQuery(userQuery);
        log.setAiResponse(aiResponse);

        chatLogRepository.save(log);

        // 4. İstemciye Cevabı Dön
        Map<String, String> response = new HashMap<>();
        response.put("answer", aiResponse);
        return response;
    }
}