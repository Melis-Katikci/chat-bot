package com.chatbot.model;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "faq")
@Data
public class Faq {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String question;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String answer;

    @Column(name = "usage_count", nullable = false)
    private Integer usageCount = 1;
}