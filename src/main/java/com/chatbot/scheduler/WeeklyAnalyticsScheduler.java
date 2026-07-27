/*package com.chatbot.scheduler;

import com.chatbot.model.TopResponse;
import com.chatbot.repository.ChatLogRepository;
import com.chatbot.repository.TopResponseRepository;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.LocalDate;
import java.util.List;

@Component
public class WeeklyAnalyticsScheduler {

    private final ChatLogRepository chatLogRepository;
    private final TopResponseRepository topResponseRepository;

    public WeeklyAnalyticsScheduler(ChatLogRepository chatLogRepository, TopResponseRepository topResponseRepository) {
        this.chatLogRepository = chatLogRepository;
        this.topResponseRepository = topResponseRepository;
    }

    // 1. OTOMATİK: Her PAZAR günü gece saat 23:59:00'da çalışır
    @Scheduled(cron = "0 59 23 * * SUN")
    // 2. MANUEL / AÇILIŞTA: Uygulamayı bilgisayardan her başlattığında çalışır
    @EventListener(ApplicationReadyEvent.class)
    public void processWeeklyTopResponses() {
        System.out.println("Analitik başlatıldı: 'faq' tablosu yenileniyor...");

        // Tablodaki eski verileri temizle
        topResponseRepository.deleteAll();

        // En çok tekrar eden ilk 3 yanıtı veritabanından çek
        List<Object[]> results = chatLogRepository.findTopResponses(PageRequest.of(0, 3));

        for (Object[] result : results) {
            String aiResponse = (String) result[0];
            Long count = (Long) result[1];

            TopResponse topResponse = new TopResponse(aiResponse, count, LocalDate.now());
            topResponseRepository.save(topResponse);
        }

        System.out.println("En çok dönen yeni 3 yanıt başarıyla 'faq' tablosuna kaydedildi.");
    }
}*/

package com.chatbot.scheduler;

import com.chatbot.model.TopResponse;
import com.chatbot.repository.ChatLogRepository;
import com.chatbot.repository.TopResponseRepository;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;

@Component
public class WeeklyAnalyticsScheduler {

    private final ChatLogRepository chatLogRepository;
    private final TopResponseRepository topResponseRepository;

    public WeeklyAnalyticsScheduler(ChatLogRepository chatLogRepository, TopResponseRepository topResponseRepository) {
        this.chatLogRepository = chatLogRepository;
        this.topResponseRepository = topResponseRepository;
    }

    // 1. ZAMANLAYICI: Uygulama Pazar 23:59'da açıksa otomatik çalışır
    @Scheduled(cron = "0 59 23 * * SUN")
    public void processWeeklyTopResponsesScheduled() {
        System.out.println("Zamanlanmış görev tetiklendi (Pazar 23:59)...");
        refreshFaqTable();
    }

    // 2. MANUEL BAŞLATMA / AÇILIŞ KONTROLÜ: Uygulama her açıldığında çalışır
    @EventListener(ApplicationReadyEvent.class)
    public void processWeeklyTopResponsesOnStartup() {
        System.out.println("Uygulama manuel olarak başlatıldı. 'faq' tablosu güncelleniyor...");
        refreshFaqTable();
    }

    // Tabloyu Temizleme ve Yeni Top 3 Kaydı Ekleme Mantığı
    private synchronized void refreshFaqTable() {
        try {
            System.out.println("1. 'faq' tablosundaki eski veriler temizleniyor...");
            topResponseRepository.deleteAll(); // Eski tüm kayıtları siler

            System.out.println("2. En çok dönen popüler yeni 3 yanıt hesaplanıyor...");
            List<Object[]> results = chatLogRepository.findTopResponses(PageRequest.of(0, 3));

            if (results.isEmpty()) {
                System.out.println("Sistemde henüz analiz edilecek sohbet kaydı bulunamadı.");
                return;
            }

            for (Object[] result : results) {
                String aiResponse = (String) result[0];
                Long count = (Long) result[1];

                // Yeni popüler kayıtları faq tablosuna ekle
                TopResponse topResponse = new TopResponse(aiResponse, count, LocalDate.now());
                topResponseRepository.save(topResponse);
            }

            System.out.println("3. 'faq' tablosu başarıyla temizlendi ve en popüler yeni 3 yanıt eklendi.");
        } catch (Exception e) {
            System.err.println("Analiz güncellenirken bir hata oluştu: " + e.getMessage());
        }
    }
}