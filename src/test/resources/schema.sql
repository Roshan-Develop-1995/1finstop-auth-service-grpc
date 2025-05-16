CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    age INTEGER,
    profession VARCHAR(255),
    education VARCHAR(255),
    provider VARCHAR(255) NOT NULL,
    provider_id VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
); 