package com.chatbot.repository;

import com.chatbot.model.TopResponse;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;


public interface TopResponseRepository extends JpaRepository<TopResponse, Long> {
}