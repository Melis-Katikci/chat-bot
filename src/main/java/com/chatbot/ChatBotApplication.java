package com.chatbot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * ChatBot Uygulaması Ana Giriş Noktası.
 * 
 * `@EnableScheduling` anotasyonu sayesinde haftalık analitik zamanlayıcısı 
 * (WeeklyAnalyticsScheduler) otomatik olarak devreye girer.
 */
@SpringBootApplication
@EnableScheduling
public class ChatBotApplication {

    public static void main(String[] args) {
        SpringApplication.run(ChatBotApplication.class, args);
        System.out.println(">>> ChatBot Uygulaması ve Zamanlayıcı Görevleri (Scheduling) Başarıyla Başlatıldı! <<<");
    }

}