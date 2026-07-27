package com.chatbot.model;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "chat_logs")
public class ChatLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "user_id")
    private Integer userId; // Şimdilik isteğe bağlı (null kalabilir veya kullanıcı id geçilebilir)

    @Column(name = "user_query", nullable = false, columnDefinition = "TEXT")
    private String userQuery;

    @Column(name = "ai_response", nullable = false, columnDefinition = "TEXT")
    private String aiResponse;

    @Column(name = "is_escalated")
    private Boolean isEscalated = false;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    public ChatLog() {}

    public ChatLog(Integer userId, String userQuery, String aiResponse) {
        this.userId = userId;
        this.userQuery = userQuery;
        this.aiResponse = aiResponse;
        this.isEscalated = false;
        this.createdAt = LocalDateTime.now();
    }

    // Getter ve Setter Metotları
    public Integer getId() { return id; }
    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }
    public String getUserQuery() { return userQuery; }
    public void setUserQuery(String userQuery) { this.userQuery = userQuery; }
    public String getAiResponse() { return aiResponse; }
    public void setAiResponse(String aiResponse) { this.aiResponse = aiResponse; }
    public Boolean getIsEscalated() { return isEscalated; }
    public void setIsEscalated(Boolean isEscalated) { this.isEscalated = isEscalated; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}