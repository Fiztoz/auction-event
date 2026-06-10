-- Reporting Service - MariaDB Schema

-- Raw Events Table (from RabbitMQ subscription)
CREATE TABLE IF NOT EXISTS report_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_id VARCHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    source_service VARCHAR(30) NOT NULL,
    payload JSON NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT NOW(),
    processed_at DATETIME DEFAULT NULL,
    UNIQUE KEY uk_event_id (event_id),
    INDEX idx_events_type_date (event_type, created_at),
    INDEX idx_events_processed (processed, created_at)
) ENGINE=InnoDB;

-- Platform Daily Metrics
CREATE TABLE IF NOT EXISTS report_platform_daily (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_date DATE NOT NULL UNIQUE,
    total_users INT NOT NULL DEFAULT 0,
    new_users INT NOT NULL DEFAULT 0,
    total_sellers INT NOT NULL DEFAULT 0,
    total_buyers INT NOT NULL DEFAULT 0,
    active_auctions INT NOT NULL DEFAULT 0,
    total_auctions_created INT NOT NULL DEFAULT 0,
    total_bids INT NOT NULL DEFAULT 0,
    total_revenue_cents BIGINT NOT NULL DEFAULT 0,
    settlements_completed INT NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT NOW(),
    INDEX idx_platform_date (report_date)
) ENGINE=InnoDB;

-- Approval Queue
CREATE TABLE IF NOT EXISTS report_approval_queue (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    seller_name VARCHAR(100) DEFAULT NULL,
    title VARCHAR(120) NOT NULL,
    description TEXT DEFAULT NULL,
    category VARCHAR(30) NOT NULL,
    price_cents INT NOT NULL,
    duration_days INT DEFAULT 7,
    status VARCHAR(20) NOT NULL DEFAULT 'pending_approval',
    rejection_reason VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY uk_product (product_id),
    INDEX idx_approval_status (status, created_at)
) ENGINE=InnoDB;

-- Active Auctions
CREATE TABLE IF NOT EXISTS report_active_auctions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    seller_name VARCHAR(100) DEFAULT NULL,
    title VARCHAR(120) NOT NULL,
    description TEXT DEFAULT NULL,
    category VARCHAR(30) NOT NULL,
    starting_price_cents INT NOT NULL,
    current_bid_cents INT NOT NULL DEFAULT 0,
    bid_count INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL,
    started_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY uk_product (product_id),
    INDEX idx_auctions_status (status, ends_at)
) ENGINE=InnoDB;

-- Settlement Pipeline
CREATE TABLE IF NOT EXISTS report_settlements (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    settlement_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    product_title VARCHAR(120) DEFAULT NULL,
    seller_id VARCHAR(36) NOT NULL,
    seller_name VARCHAR(100) DEFAULT NULL,
    buyer_id VARCHAR(36) NOT NULL,
    buyer_name VARCHAR(100) DEFAULT NULL,
    amount_cents BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'invoiced',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY uk_settlement (settlement_id),
    INDEX idx_settlements_status (status, created_at)
) ENGINE=InnoDB;

-- Seller Stats
CREATE TABLE IF NOT EXISTS report_seller_stats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    seller_id VARCHAR(36) NOT NULL,
    seller_name VARCHAR(100) DEFAULT NULL,
    period_date DATE NOT NULL,
    products_listed INT NOT NULL DEFAULT 0,
    products_approved INT NOT NULL DEFAULT 0,
    products_rejected INT NOT NULL DEFAULT 0,
    auctions_started INT NOT NULL DEFAULT 0,
    auctions_ended INT NOT NULL DEFAULT 0,
    revenue_cents BIGINT NOT NULL DEFAULT 0,
    bids_received INT NOT NULL DEFAULT 0,
    UNIQUE KEY uk_seller_period (seller_id, period_date),
    INDEX idx_seller_date (seller_id, period_date)
) ENGINE=InnoDB;

-- Bid Activity
CREATE TABLE IF NOT EXISTS report_bid_activity (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period_date DATE NOT NULL,
    hour TINYINT NOT NULL,
    total_bids INT NOT NULL DEFAULT 0,
    unique_bidders INT NOT NULL DEFAULT 0,
    unique_products INT NOT NULL DEFAULT 0,
    avg_bid_cents INT NOT NULL DEFAULT 0,
    max_bid_cents INT NOT NULL DEFAULT 0,
    UNIQUE KEY uk_period_hour (period_date, hour),
    INDEX idx_bid_date (period_date)
) ENGINE=InnoDB;
