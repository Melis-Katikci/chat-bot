package com.chatbot.controller;

import com.chatbot.model.ChatLog;
import com.chatbot.repository.ChatLogRepository;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*")
public class ChatController {

    private final ChatLogRepository chatLogRepository;
    private final RestTemplate restTemplate;

    public ChatController(ChatLogRepository chatLogRepository) {
        this.chatLogRepository = chatLogRepository;
        this.restTemplate = new RestTemplate();
    }

    @PostMapping("/ask")
    public Map<String, String> askQuestion(@RequestBody Map<String, Object> request) {
        String userQuery = (String) request.get("question");
        
        // userId dönüşümünü güvenli hale getirdik (ClassCastException önlemi)
        Integer userId = null;
        if (request.get("userId") != null) {
            userId = Integer.valueOf(request.get("userId").toString());
        }

        String aiResponse;

        // 1. Python FastAPI Servisine İstek At (Port 8000)
        try {
            String pythonUrl = "http://127.0.0.1:8000/api/rag/sor";
            
            Map<String, String> pythonRequest = new HashMap<>();
            pythonRequest.put("soru", userQuery);

            @SuppressWarnings("unchecked")
            Map<String, String> pythonResponse = (Map<String, String>) restTemplate.postForObject(pythonUrl, pythonRequest, Map.class);
            
            aiResponse = (pythonResponse != null && pythonResponse.get("cevap") != null) 
                    ? pythonResponse.get("cevap") 
                    : "Python servisinden boş yanıt döndü.";

        } catch (Exception e) {
            // Python servisi kapalıysa veya erişilemiyorsa uygulamanın çökmesini engelliyoruz
            aiResponse = "RAG servisine ulaşılamadı: " + e.getMessage();
        }

        // 2. PostgreSQL 'chat_logs' Tablosuna Kaydet
        ChatLog log = new ChatLog();
        log.setUserId(userId);
        log.setUserQuery(userQuery);
        log.setAiResponse(aiResponse);
        
        chatLogRepository.save(log);

        // 3. İstemciye Cevabı Dön
        Map<String, String> response = new HashMap<>();
        response.put("answer", aiResponse);
        return response;
    }
}