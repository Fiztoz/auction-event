# Reporting Service — Implementation Plan

**Service:** Reporting  
**Status:** Design Phase  
**Version:** 1.0  
**Date:** 2026-06-09

---

## 1. Overview

This document outlines the implementation plan for the Reporting Service, broken into phases with clear deliverables and acceptance criteria.

---

## 2. Project Structure

```
lib/reporting/
├── config/
│   ├── env.rb                    # Environment variables
│   ├── database.rb               # Database connections
│   └── event_bus.rb              # Event bus configuration
│
├── domain/
│   ├── event.rb                  # Event aggregate
│   └── projection.rb             # Projection aggregate
│
├── application/
│   ├── event_consumer.rb         # Consumes events from bus
│   ├── event_store.rb            # Stores raw events
│   └── projection_worker.rb      # Projects events → tables
│
├── ports/
│   ├── event_bus_port.rb         # Event bus interface
│   ├── mariadb_port.rb           # MariaDB interface
│   └── clickhouse_port.rb        # ClickHouse interface
│
├── infrastructure/
│   ├── kafka_event_bus.rb        # Kafka implementation
│   ├── rabbitmq_event_bus.rb     # RabbitMQ implementation
│   ├── mariadb_client.rb         # MariaDB client
│   └── clickhouse_client.rb      # ClickHouse client
│
├── api/
│   ├── app.rb                    # Sinatra app
│   ├── routes/
│   │   ├── overview.rb           # Platform overview endpoints
│   │   ├── approval_queue.rb     # Approval queue endpoints
│   │   ├── settlements.rb        # Settlement endpoints
│   │   ├── active_auctions.rb    # Active auctions endpoints
│   │   ├── seller_stats.rb       # Seller stats endpoints
│   │   └── bid_activity.rb       # Bid activity endpoints
│   └── presenters/
│       ├── overview_presenter.rb
│       ├── approval_presenter.rb
│       └── ...
│
├── db/
│   ├── mariadb/
│   │   └── init/
│   │       └── 01_schema.sql     # MariaDB init script
│   └── clickhouse/
│       └── init/
│           └── 01_schema.sql     # ClickHouse init script
│
├── bin/
│   ├── migrate_clickhouse_to_mariadb.rb  # Migration script
│   └── seed_demo_data.rb                 # Demo data seeder
│
├── test/
│   ├── test_event_store.rb
│   ├── test_projection_worker.rb
│   ├── test_approval_queue.rb
│   └── ...
│
├── docker-compose.yml
├── Gemfile
└── README.md
```

---

## 3. Implementation Phases

### Phase 1: Foundation (2-3 days)

**Goal:** Event ingestion + basic projection framework.

#### Tasks

| # | Task | Files | Acceptance Criteria |
|---|------|-------|---------------------|
| 1.1 | Create MariaDB schema | `db/mariadb/init/01_schema.sql` | All 7 tables created |
| 1.2 | Create ClickHouse schema | `db/clickhouse/init/01_schema.sql` | 5 analytics tables created |
| 1.3 | Implement Event aggregate | `domain/event.rb` | Event can be created with type, source, payload |
| 1.4 | Implement EventStore | `application/event_store.rb` | Can save and retrieve events |
| 1.5 | Implement ProjectionWorker framework | `application/projection_worker.rb` | Can project events to tables |
| 1.6 | Implement dual-write logic | `application/projection_worker.rb` | Writes to both MariaDB and ClickHouse |
| 1.7 | Create basic API endpoints | `api/app.rb`, `api/routes/*.rb` | Can query all projection tables |
| 1.8 | Write tests | `test/test_*.rb` | All tests pass |

#### Deliverables
- [ ] MariaDB schema created
- [ ] ClickHouse schema created
- [ ] Event consumer working
- [ ] Projection worker working
- [ ] Basic API endpoints responding

---

### Phase 2: Admin Dashboard (3-4 days)

**Goal:** Admin can view platform overview and manage approvals.

#### Tasks

| # | Task | Files | Acceptance Criteria |
|---|------|-------|---------------------|
| 2.1 | Platform overview endpoint | `api/routes/overview.rb` | Returns daily metrics for last 30 days |
| 2.2 | Approval queue endpoint | `api/routes/approval_queue.rb` | Returns pending products |
| 2.3 | Approve product endpoint | `api/routes/approval_queue.rb` | Approves product, updates status |
| 2.4 | Reject product endpoint | `api/routes/approval_queue.rb` | Rejects product with reason |
| 2.5 | Active auctions endpoint | `api/routes/active_auctions.rb` | Returns live auctions |
| 2.6 | Settlements endpoint | `api/routes/settlements.rb` | Returns settlement pipeline |
| 2.7 | Admin dashboard UI | `public/js/admin-dashboard.js` | Can view all admin features |
| 2.8 | Write tests | `test/test_admin_*.rb` | All tests pass |

#### Deliverables
- [ ] Platform overview working
- [ ] Approval queue working
- [ ] Settlement pipeline working
- [ ] Admin dashboard UI complete

---

### Phase 3: Analytics (2-3 days)

**Goal:** ClickHouse analytics + fallback to MariaDB.

#### Tasks

| # | Task | Files | Acceptance Criteria |
|---|------|-------|---------------------|
| 3.1 | ClickHouse client | `infrastructure/clickhouse_client.rb` | Can connect and query ClickHouse |
| 3.2 | ClickHouse fallback logic | `api/routes/*.rb` | Falls back to MariaDB on failure |
| 3.3 | Seller leaderboard endpoint | `api/routes/seller_stats.rb` | Returns top sellers |
| 3.4 | Bid activity endpoint | `api/routes/bid_activity.rb` | Returns hourly bid patterns |
| 3.5 | Migration script | `bin/migrate_clickhouse_to_mariadb.rb` | Can migrate all data |
| 3.6 | Write tests | `test/test_analytics.rb` | All tests pass |

#### Deliverables
- [ ] ClickHouse integration working
- [ ] Fallback logic working
- [ ] Migration script working
- [ ] Analytics endpoints working

---

### Phase 4: Seller & Buyer Dashboards (3-4 days)

**Goal:** Seller and buyer can view their own data.

#### Tasks

| # | Task | Files | Acceptance Criteria |
|---|------|-------|---------------------|
| 4.1 | My listings endpoint | `api/routes/my_listings.rb` | Returns seller's products |
| 4.2 | My revenue endpoint | `api/routes/my_revenue.rb` | Returns seller's revenue |
| 4.3 | My bids endpoint | `api/routes/my_bids.rb` | Returns buyer's bids |
| 4.4 | My won auctions endpoint | `api/routes/my_won.rb` | Returns buyer's won items |
| 4.5 | Seller dashboard UI | `public/js/seller-dashboard.js` | Can view seller features |
| 4.6 | Buyer dashboard UI | `public/js/buyer-dashboard.js` | Can view buyer features |
| 4.7 | Write tests | `test/test_seller_*.rb`, `test/test_buyer_*.rb` | All tests pass |

#### Deliverables
- [ ] Seller dashboard working
- [ ] Buyer dashboard working
- [ ] All role-based access working

---

### Phase 5: Polish (2-3 days)

**Goal:** Near real-time updates + UI/UX improvements.

#### Tasks

| # | Task | Files | Acceptance Criteria |
|---|------|-------|---------------------|
| 5.1 | Near real-time polling | `public/js/app.js` | Dashboard refreshes every 15 seconds |
| 5.2 | Loading states | `public/js/components/*.js` | Show loading indicators |
| 5.3 | Error handling | `public/js/api.js` | Graceful error messages |
| 5.4 | Responsive design | `public/css/style.css` | Works on mobile |
| 5.5 | Documentation | `README.md`, `docs/` | Complete documentation |
| 5.6 | Performance testing | `test/performance/` | API < 500ms p95 |

#### Deliverables
- [ ] Near real-time updates working
- [ ] UI/UX polished
- [ ] Documentation complete
- [ ] Performance targets met

---

## 4. Docker Compose Setup

```yaml
version: '3.8'

services:
  # ── Databases ──────────────────────────────────────────────
  
  mariadb:
    image: mariadb:11
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
      MYSQL_DATABASE: reporting
    volumes:
      - ./db/mariadb/init:/docker-entrypoint-initdb.d
      - mariadb_data:/var/lib/mysql
    ports:
      - "3306:3306"
    secrets:
      - db_root_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  clickhouse:
    image: clickhouse/clickhouse-server:latest
    volumes:
      - ./db/clickhouse/init:/docker-entrypoint-initdb.d
      - clickhouse_data:/var/lib/clickhouse
    ports:
      - "8123:8123"
      - "9000:9000"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8123/ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── Event Bus ──────────────────────────────────────────────
  
  kafka:
    image: confluentinc/cp-kafka:latest
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper

  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    ports:
      - "2181:2181"

  # ── Reporting Service ──────────────────────────────────────
  
  reporting:
    build: .
    environment:
      MARIADB_HOST: mariadb
      MARIADB_PORT: 3306
      MARIADB_DATABASE: reporting
      MARIADB_USER_FILE: /run/secrets/db_user
      MARIADB_SECRET_FILE: /run/secrets/db_password
      CLICKHOUSE_HOST: clickhouse
      CLICKHOUSE_PORT: 8123
      CLICKHOUSE_ENABLED: "true"
      KAFKA_BROKERS: kafka:9092
    ports:
      - "4568:4568"
    secrets:
      - db_user
      - db_password
    depends_on:
      mariadb:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
      kafka:
        condition: service_started

secrets:
  db_root_password:
    file: ./secrets/db_root_password.txt
  db_user:
    file: ./secrets/db_user.txt
  db_password:
    file: ./secrets/db_password.txt

volumes:
  mariadb_data:
  clickhouse_data:
```

---

## 5. Environment Variables

```ruby
# config/env.rb
module Reporting
  module Env
    # MariaDB (values read from Docker secrets in production)
    MARIADB_HOST     = ENV.fetch("MARIADB_HOST", "localhost")
    MARIADB_PORT     = ENV.fetch("MARIADB_PORT", "3306")
    MARIADB_DATABASE = ENV.fetch("MARIADB_DATABASE", "reporting")
    MARIADB_USER     = ENV.fetch("MARIADB_USER", "root")
    MARIADB_CRED     = ENV.fetch("MARIADB_SECRET", "")

    # ClickHouse
    CLICKHOUSE_HOST     = ENV.fetch("CLICKHOUSE_HOST", "localhost")
    CLICKHOUSE_PORT     = ENV.fetch("CLICKHOUSE_PORT", "8123")
    CLICKHOUSE_ENABLED  = ENV.fetch("CLICKHOUSE_ENABLED", "true") == "true"

    # Event Bus
    KAFKA_BROKERS    = ENV.fetch("KAFKA_BROKERS", "localhost:9092")
    KAFKA_GROUP_ID   = ENV.fetch("KAFKA_GROUP_ID", "reporting-service")

    # Projection Worker
    PROJECTION_INTERVAL = ENV.fetch("PROJECTION_INTERVAL", "5").to_i  # seconds

    # API
    API_PORT = ENV.fetch("API_PORT", "4568").to_i
  end
end
```

---

## 6. Acceptance Criteria

### 6.1 Phase 1 (Foundation)
- [ ] All MariaDB tables created on project init
- [ ] All ClickHouse tables created on project init
- [ ] Events can be stored in report_events
- [ ] Projection worker can process events
- [ ] API returns data from projection tables

### 6.2 Phase 2 (Admin Dashboard)
- [ ] Admin can view platform overview
- [ ] Admin can view approval queue
- [ ] Admin can approve/reject products
- [ ] Admin can view settlement pipeline
- [ ] Admin can view active auctions

### 6.3 Phase 3 (Analytics)
- [ ] ClickHouse integration working
- [ ] Fallback to MariaDB on failure
- [ ] Seller leaderboard working
- [ ] Bid activity working
- [ ] Migration script working

### 6.4 Phase 4 (Seller & Buyer)
- [ ] Seller can view their listings
- [ ] Seller can view their revenue
- [ ] Buyer can view their bids
- [ ] Buyer can view their won auctions

### 6.5 Phase 5 (Polish)
- [ ] Dashboard refreshes every 15 seconds
- [ ] Loading states implemented
- [ ] Error handling working
- [ ] Responsive design working
- [ ] Documentation complete

---

## 7. Success Metrics

| Metric | Target |
|--------|--------|
| Dashboard load time | < 2 seconds |
| Data freshness | < 20 seconds |
| API response time (p95) | < 500ms |
| Test coverage | > 80% |
| Uptime | 99.9% |

---

**End of Implementation Plan**
