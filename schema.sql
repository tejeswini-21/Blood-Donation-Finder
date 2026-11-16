-- =============================================================================
-- Blood Donation Finder and Emergency Request System
-- Production MySQL 8.4 Relational Database Schema
-- =============================================================================

CREATE DATABASE IF NOT EXISTS bloodfinder_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE bloodfinder_db;

-- -----------------------------------------------------------------------------
-- Table: users
-- Stores credentials, role-based identity, contact, location & verification state
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,
    city VARCHAR(60) NOT NULL,
    area VARCHAR(100),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_city (city),
    INDEX idx_users_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: donors
-- Stores donor biometric details, eligibility tracker & donation statistics
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS donors (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    blood_group VARCHAR(20) NOT NULL,
    age INT NOT NULL,
    gender VARCHAR(20),
    last_donation_date DATE,
    available BOOLEAN NOT NULL DEFAULT TRUE,
    total_donations INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_donor_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_donors_bg (blood_group),
    INDEX idx_donors_available (available),
    INDEX idx_donors_last_donation (last_donation_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: blood_requests
-- Core blood request lifecycle: OPEN, ACCEPTED, FULFILLED, CANCELLED, EXPIRED
-- Features optimistic concurrency control (version column)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blood_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    requester_id BIGINT NOT NULL,
    patient_name VARCHAR(100) NOT NULL,
    blood_group VARCHAR(20) NOT NULL,
    units_needed INT NOT NULL,
    hospital_name VARCHAR(120) NOT NULL,
    city VARCHAR(60) NOT NULL,
    area VARCHAR(100),
    urgency VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    required_by DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    accepted_by_donor_id BIGINT,
    contact_number VARCHAR(20) NOT NULL,
    notes VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_request_requester FOREIGN KEY (requester_id) REFERENCES users(id),
    CONSTRAINT fk_request_accepted_donor FOREIGN KEY (accepted_by_donor_id) REFERENCES donors(id),
    INDEX idx_requests_status (status),
    INDEX idx_requests_city (city),
    INDEX idx_requests_bg (blood_group),
    INDEX idx_requests_urgency (urgency),
    INDEX idx_requests_reqby (required_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: donation_records
-- Audit trail and medical history of fulfilled transfusions & walk-ins
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS donation_records (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    donor_id BIGINT NOT NULL,
    request_id BIGINT,
    donation_date DATE NOT NULL,
    units INT NOT NULL DEFAULT 1,
    hospital VARCHAR(120) NOT NULL,
    remarks VARCHAR(255),
    CONSTRAINT fk_record_donor FOREIGN KEY (donor_id) REFERENCES donors(id),
    CONSTRAINT fk_record_request FOREIGN KEY (request_id) REFERENCES blood_requests(id) ON DELETE SET NULL,
    INDEX idx_records_donor (donor_id),
    INDEX idx_records_date (donation_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: blood_banks
-- Registered blood banks, clinical labs & hospital storage centres
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blood_banks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    city VARCHAR(60) NOT NULL,
    area VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    address VARCHAR(200),
    hospital_user_id BIGINT,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bank_user FOREIGN KEY (hospital_user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_banks_city (city),
    INDEX idx_banks_verified (verified)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: blood_stocks
-- Real-time stock units per blood bank and blood group
-- Unique constraint prevents duplicate rows for the same bank + blood group
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blood_stocks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id BIGINT NOT NULL,
    blood_group VARCHAR(20) NOT NULL,
    units_available INT NOT NULL DEFAULT 0,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uk_blood_bank_group UNIQUE (blood_bank_id, blood_group),
    CONSTRAINT fk_stock_bank FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(id) ON DELETE CASCADE,
    INDEX idx_stocks_bg (blood_group),
    INDEX idx_stocks_units (units_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: notifications
-- In-app alert system for requests, acceptances, fulfillments & status changes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    message VARCHAR(500) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    link_url VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notifs_user (user_id),
    INDEX idx_notifs_read (is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table: request_responses
-- Multi-donor response logs (acceptance/rejection)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS request_responses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    request_id BIGINT NOT NULL,
    donor_id BIGINT NOT NULL,
    response_status VARCHAR(20) NOT NULL,
    response_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_resp_request FOREIGN KEY (request_id) REFERENCES blood_requests(id) ON DELETE CASCADE,
    CONSTRAINT fk_resp_donor FOREIGN KEY (donor_id) REFERENCES donors(id) ON DELETE CASCADE,
    INDEX idx_resp_request (request_id),
    INDEX idx_resp_donor (donor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
