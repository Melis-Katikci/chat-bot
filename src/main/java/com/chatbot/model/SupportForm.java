package com.chatbot.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "support_forms")
@Data
public class SupportForm {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false, foreignKey = @ForeignKey(name = "fk_supportforms_user"))
    private User user;

    @Column(name = "complaint_title", nullable = false, length = 150)
    private String complaintTitle;

    @Column(name = "complaint_summary", nullable = false, columnDefinition = "TEXT")
    private String complaintSummary;

    @Column(length = 20)
    private String status = "Beklemede";

    @Column(name = "is_mailed")
    private Boolean isMailed = false;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}