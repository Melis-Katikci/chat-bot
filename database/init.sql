-- ===========================================
-- CHAT BOT DATABASE
-- ===========================================

-- ===========================================
-- USERS TABLOSU
-- ===========================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE
);

-- ===========================================
-- CHAT_LOGS TABLOSU
-- ===========================================

CREATE TABLE chat_logs (
    id SERIAL PRIMARY KEY,
    user_id INT,
    user_query TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    is_escalated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_chatlogs_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
);

-- ===========================================
-- SUPPORT_FORMS TABLOSU
-- ===========================================

CREATE TABLE support_forms (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    complaint_title VARCHAR(150) NOT NULL,
    complaint_summary TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'Beklemede',
    is_mailed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_supportforms_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

-- ===========================================
-- FAQ TABLOSU
-- ===========================================

CREATE TABLE faq (
    id SERIAL PRIMARY KEY,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    usage_count INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================
-- INDEXLER
-- ===========================================

CREATE INDEX idx_chatlogs_user
ON chat_logs(user_id);

CREATE INDEX idx_chatlogs_created_at
ON chat_logs(created_at);

CREATE INDEX idx_supportforms_user
ON support_forms(user_id);

CREATE INDEX idx_supportforms_status
ON support_forms(status);

CREATE INDEX idx_faq_usage
ON faq(usage_count);