package com.chatbot.dto;

import lombok.Data;

@Data
public class ChatRequest {
    private Integer userId;
    private String message;
}