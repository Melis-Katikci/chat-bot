package com.chatbot.repository;

import com.chatbot.model.SupportForm;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;


public interface SupportFormRepository extends JpaRepository<SupportForm, Long> {
    List<SupportForm> findByStatus(String status);
}