package com.chatbot.repository;

import com.chatbot.model.ChatLog;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChatLogRepository extends JpaRepository<ChatLog, Long> {
    
    // Mevcut metodun (kullanıcının geçmişini getiren kısım)
    List<ChatLog> findByUserId(Long userId);

    // En çok tekrar eden yanıtları ve kaçar kez tekrar ettiklerini getiren yeni sorgu
    @Query("SELECT c.aiResponse AS response, COUNT(c.aiResponse) AS count " +
           "FROM ChatLog c " +
           "GROUP BY c.aiResponse " +
           "ORDER BY COUNT(c.aiResponse) DESC")
    List<Object[]> findTopResponses(Pageable pageable);
}