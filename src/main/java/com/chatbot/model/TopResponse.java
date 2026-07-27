package com.chatbot.model;

import jakarta.persistence.*;

@Entity
@Table(name = "faq") // Veritabanındaki 'faq' tablosuna bağlandık
public class TopResponse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String question; // faq tablosundaki 'question' sütunu

    @Column(columnDefinition = "TEXT")
    private String answer; // 'responseText' yerine 'answer' kullanıyoruz

    @Column(name = "usage_count")
    private Long usageCount; // 'frequency' yerine 'usage_count' sütunu

    public TopResponse() {}

    // Scheduler içinden çağrılan 3 parametreli constructor
    public TopResponse(String answer, Long usageCount, Object date) {
        this.question = "Haftalık Sık Sorulan Yanıt"; // faq tablosu için varsayılan soru metni
        this.answer = answer;
        this.usageCount = usageCount;
    }

    // Getter ve Setter metotları
    public Long getId() { return id; }
    
    public String getQuestion() { return question; }
    public void setQuestion(String question) { this.question = question; }

    public String getAnswer() { return answer; }
    public void setAnswer(String answer) { this.answer = answer; }

    public Long getUsageCount() { return usageCount; }
    public void setUsageCount(Long usageCount) { this.usageCount = usageCount; }
}