# Reporting Service — Database Design

**Service:** Reporting  
**Status:** Design Phase  
**Version:** 1.0  
**Date:** 2026-06-09

---

## 1. Overview

The reporting service uses a **dual-database strategy**:

- **MariaDB** — Source of truth, operational tables, always created
- **ClickHouse** — Optional, analytics tables, fast aggregations

---

## 2. MariaDB Schema

### 2.1 Raw Events Table (Append-Only Log)

Every event from every service lands here first. This is your permanent backup.

```sql
CREATE TABLE IF NOT EXISTS report_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    source_service VARCHAR(30) NOT NULL,
    payload JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT NOW(),
    INDEX idx_events_type_date (event_type, created_at),
    INDEX idx_events_service_date (source_service, created_at)
) ENGINE=InnoDB;
```

**Purpose:**
- Permanent record of all events
- Backup for ClickHouse
- Debugging and auditing
- Migration source if ClickHouse is removed

---

### 2.2 Platform Daily Metrics

Aggregated daily stats for the admin dashboard overview.

```sql
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
```

**Updated by events:**
- `user_registered` → total_users += 1, new_users += 1
- `product_listed` → total_auctions_created += 1
- `auction_started` → active_auctions += 1
- `auction_ended` → active_auctions -= 1
- `bid_placed` → total_bids += 1
- `settlement_completed` → total_revenue_cents += amount, settlements_completed += 1

---

### 2.3 Approval Queue

Operational table for admin approval workflow. **MariaDB only** — needs instant UPDATE.

```sql
CREATE TABLE IF NOT EXISTS report_approval_queue (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    title VARCHAR(120) NOT NULL,
    category VARCHAR(30) NOT NULL,
    price_cents INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending_approval',
    rejection_reason VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY uk_product (product_id),
    INDEX idx_approval_status (status, created_at)
) ENGINE=InnoDB;
```

**Status flow:**
```
pending_approval → draft (approved)
pending_approval → rejected (with reason)
```

**Updated by events:**
- `product_listed` → INSERT
- `product_approved` → UPDATE status = 'draft'
- `product_rejected` → UPDATE status = 'rejected', rejection_reason

---

### 2.4 Active Auctions

Tracks live auctions with bid data. **MariaDB for operational state, ClickHouse for analytics.**

```sql
CREATE TABLE IF NOT EXISTS report_active_auctions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    title VARCHAR(120) NOT NULL,
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
```

**Status flow:**
```
draft → live (started)
live → ended (stopped or expired)
```

**Updated by events:**
- `auction_started` → INSERT
- `bid_placed` → UPDATE current_bid_cents, bid_count
- `auction_ended` → UPDATE status = 'ended'

---

### 2.5 Settlement Pipeline

Operational table for settlement workflow. **MariaDB only** — needs instant UPDATE.

```sql
CREATE TABLE IF NOT EXISTS report_settlements (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    settlement_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    buyer_id VARCHAR(36) NOT NULL,
    amount_cents BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'invoiced',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY uk_settlement (settlement_id),
    INDEX idx_settlements_status (status, created_at)
) ENGINE=InnoDB;
```

**Status flow:**
```
invoiced → paid → shipped → completed
```

**Updated by events:**
- `invoice_created` → INSERT
- `payment_received` → UPDATE status = 'paid'
- `settlement_completed` → UPDATE status = 'completed'

---

### 2.6 Seller Stats

Daily aggregates per seller. **Written to both databases.**

```sql
CREATE TABLE IF NOT EXISTS report_seller_stats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    seller_id VARCHAR(36) NOT NULL,
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
```

**Updated by events:**
- `product_listed` → products_listed += 1
- `product_approved` → products_approved += 1
- `product_rejected` → products_rejected += 1
- `auction_started` → auctions_started += 1
- `auction_ended` → auctions_ended += 1
- `bid_placed` → bids_received += 1
- `settlement_completed` → revenue_cents += amount

---

### 2.7 Bid Activity

Hourly bid patterns. **Written to both databases.**

```sql
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
```

**Updated by events:**
- `bid_placed` → total_bids += 1, unique_bidders += 1, etc.

---

## 3. ClickHouse Schema

### 3.1 Raw Events (Append-Only)

```sql
CREATE TABLE IF NOT EXISTS report_events (
    event_type     String,
    source_service String,
    payload        String,
    created_at     DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY (event_type, created_at);
```

---

### 3.2 Platform Daily Metrics

```sql
CREATE TABLE IF NOT EXISTS report_platform_daily (
    report_date              Date,
    total_users              UInt32,
    new_users                UInt32,
    total_sellers            UInt32,
    total_buyers             UInt32,
    active_auctions          UInt32,
    total_auctions_created   UInt32,
    total_bids               UInt32,
    total_revenue_cents      UInt64,
    settlements_completed    UInt32
)
ENGINE = SummingMergeTree()
ORDER BY report_date;
```

---

### 3.3 Active Auctions

```sql
CREATE TABLE IF NOT EXISTS report_active_auctions (
    product_id            String,
    seller_id             String,
    title                 String,
    category              String,
    starting_price_cents  UInt32,
    current_bid_cents     UInt32,
    bid_count             UInt32,
    status                String,
    started_at            DateTime,
    ends_at               DateTime,
    updated_at            DateTime
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY product_id;
```

---

### 3.4 Seller Stats

```sql
CREATE TABLE IF NOT EXISTS report_seller_stats (
    seller_id          String,
    period_date        Date,
    products_listed    UInt32,
    products_approved  UInt32,
    products_rejected  UInt32,
    auctions_started   UInt32,
    auctions_ended     UInt32,
    revenue_cents      UInt64,
    bids_received      UInt32
)
ENGINE = SummingMergeTree()
ORDER BY (seller_id, period_date);
```

---

### 3.5 Bid Activity

```sql
CREATE TABLE IF NOT EXISTS report_bid_activity (
    period_date     Date,
    hour            UInt8,
    total_bids      UInt32,
    unique_bidders  UInt32,
    unique_products UInt32,
    avg_bid_cents   UInt32,
    max_bid_cents   UInt32
)
ENGINE = SummingMergeTree()
ORDER BY (period_date, hour);
```

---

## 4. Table Summary

| Table | MariaDB | ClickHouse | Purpose |
|-------|---------|------------|---------|
| `report_events` | ✅ Primary | ✅ Copy | Raw event log |
| `report_platform_daily` | ✅ Fallback | ✅ Primary | Daily aggregated metrics |
| `report_approval_queue` | ✅ Only | ❌ | Admin approval workflow |
| `report_active_auctions` | ✅ Primary | ✅ Copy | Live auction tracking |
| `report_settlements` | ✅ Only | ❌ | Settlement workflow |
| `report_seller_stats` | ✅ Fallback | ✅ Primary | Seller performance |
| `report_bid_activity` | ✅ Fallback | ✅ Primary | Bid pattern analytics |

---

## 5. Migration Strategy

### 5.1 ClickHouse → MariaDB Migration

When removing ClickHouse, run the migration script:

```bash
ruby bin/migrate_clickhouse_to_mariadb.rb
```

This script:
1. Reads all data from ClickHouse tables
2. Upserts into MariaDB tables
3. Verifies row counts match
4. Reports success/failure

### 5.2 Migration Script Location

```
bin/migrate_clickhouse_to_mariadb.rb
```

### 5.3 Post-Migration Steps

1. Set `CLICKHOUSE_ENABLED=false` in environment
2. Stop ClickHouse container
3. Remove ClickHouse from docker-compose.yml (optional)
4. MariaDB now serves all queries

---

**End of Database Design Document**
