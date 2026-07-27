package com.chatbot.service;

import com.chatbot.dto.ChatRequest;
import com.chatbot.dto.ChatResponse;
import com.chatbot.model.ChatLog;
import com.chatbot.repository.ChatLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatLogRepository chatLogRepository;
    private final RestTemplate restTemplate;

    // Python FastAPI servis adresi (RAG servisiniz)
    private final String FASTAPI_URL = "http://localhost:8000/api/rag/query";

    public ChatResponse processMessage(ChatRequest request) {
        String botAnswer;

        try {
            // 1. Python FastAPI Servisine İstek Hazırla
            Map<String, String> pythonRequest = new HashMap<>();
            pythonRequest.put("query", request.getMessage());

            HttpEntity<Map<String, String>> entity = new HttpEntity<>(pythonRequest);

            // FastAPI'den dönen yanıtı tür güvenliğiyle alıyoruz
            ResponseEntity<Map<String, Object>> responseEntity = restTemplate.exchange(
                FASTAPI_URL,
                HttpMethod.POST,
                entity,
                new ParameterizedTypeReference<Map<String, Object>>() {}
            );

            Map<String, Object> pythonResponse = responseEntity.getBody();

            botAnswer = (pythonResponse != null && pythonResponse.containsKey("answer")) 
                    ? pythonResponse.get("answer").toString() 
                    : "Python servisinden geçerli bir yanıt alınamadı.";

        } catch (Exception e) {
            // Python servisi kapalıysa veya hata verirse fallback yanıtı
            botAnswer = "Şu anda RAG servisine ulaşılamıyor. Hata: " + e.getMessage();
        }

        // 2. Konuşmayı PostgreSQL veritabanına kaydet
        ChatLog chatLog = new ChatLog();
        chatLog.setUserId(request.getUserId());
        chatLog.setUserQuery(request.getMessage());
        chatLog.setAiResponse(botAnswer);

        chatLogRepository.save(chatLog);

        // 3. Kullanıcıya cevabı dön
        return new ChatResponse(botAnswer);
    }
}