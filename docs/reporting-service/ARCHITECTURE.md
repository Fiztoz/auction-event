# Reporting Service — Architecture

**Service:** Reporting  
**Status:** Design Phase  
**Version:** 1.0  
**Date:** 2026-06-09

---

## 1. Overview

The Reporting Service is a **read-only aggregation service** that consumes events from other microservices and produces dashboards and reports for three user roles: Buyer, Seller, and Admin.

### Core Principles

1. **MariaDB is the source of truth** — always created, always works
2. **ClickHouse is optional** — for faster analytics, can be removed anytime
3. **Event-driven** — all data flows via events from other services
4. **CQRS pattern** — separate write (events) from read (projections)
5. **Near real-time** — projection worker runs every 5 seconds

---

## 2. System Architecture

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Selling  │  │ Buying   │  │ Bidding  │  │Settlement│
│ Service  │  │ Service  │  │ Service  │  │ Service  │
└────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
     │              │              │              │
     └──────────────┴──────┬───────┴──────────────┘
                           │
                    Event Bus
                    (Kafka / RabbitMQ / Redis Streams)
                           │
              ┌────────────▼────────────┐
              │    Reporting Service     │
              │                         │
              │  ┌─────────────────┐   │
              │  │ Event Consumer  │   │ ← Subscribes to all events
              │  └────────┬────────┘   │
              │           │            │
              │  ┌────────▼────────┐   │
              │  │ Event Store     │   │ ← Raw events in MariaDB
              │  └────────┬────────┘   │
              │           │            │
              │  ┌────────▼────────┐   │
              │  │ Projection      │   │ ← Projects events → tables
              │  │ Worker          │   │
              │  └────────┬────────┘   │
              │           │            │
              │     ┌─────┴─────┐      │
              │     │           │      │
              │  ┌──▼───┐  ┌───▼──┐   │
              │  │Maria │  │Click │   │
              │  │DB    │  │House │   │
              │  └──┬───┘  └───┬──┘   │
              │     │           │      │
              │  ┌──▼───────────▼──┐   │
              │  │ Reporting API   │   │ ← Serves dashboards
              │  └─────────────────┘   │
              └─────────────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         ┌────▼───┐  ┌────▼───┐  ┌────▼───┐
         │ Buyer  │  │ Seller │  │ Admin  │
         │Dashboard│ │Dashboard│ │Dashboard│
         └────────┘  └────────┘  └────────┘
```

---

## 3. User Roles & Dashboards

### 3.1 Admin Dashboard (Priority 1)

**Goal:** Platform health, operational oversight, approval workflows.

| Feature | Description | Data Source |
|---------|-------------|-------------|
| **Platform Overview** | Total users, auctions, revenue, trends | `report_platform_daily` |
| **Approval Queue** | Products pending admin approval | `report_approval_queue` |
| **Active Auctions** | Live auctions with bid data | `report_active_auctions` |
| **Settlement Pipeline** | Pending/invoiced/paid/shipped settlements | `report_settlements` |
| **Seller Leaderboard** | Top sellers by revenue and performance | `report_seller_stats` |
| **Bid Activity** | Hourly bid patterns and trends | `report_bid_activity` |

### 3.2 Seller Dashboard (Priority 2)

**Goal:** Revenue tracking, listing performance, settlement status.

| Feature | Description | Data Source |
|---------|-------------|-------------|
| **My Listings** | All products with status and bid count | `report_active_auctions` |
| **Revenue Summary** | Total earned, pending, completed | `report_seller_stats` |
| **Auction Performance** | Sold vs unsold, avg final price | `report_seller_stats` |
| **Settlement Status** | My settlements pipeline | `report_settlements` |

### 3.3 Buyer Dashboard (Priority 3)

**Goal:** Bidding history, won items, spending analytics.

| Feature | Description | Data Source |
|---------|-------------|-------------|
| **My Bids** | All bids placed, winning/losing status | `report_bid_activity` |
| **Won Auctions** | Items won, payment/shipment status | `report_settlements` |
| **Spending Analytics** | Total spent, avg bid, by category | `report_bid_activity` |

---

## 4. Database Strategy

### 4.1 Dual-Write Pattern

The projection worker writes to **both** databases simultaneously:

```
Event → MariaDB (always) + ClickHouse (optional)
```

### 4.2 What Goes Where

| Table | MariaDB | ClickHouse | Reason |
|-------|---------|------------|--------|
| `report_events` | ✅ Primary | ✅ Copy | MariaDB = backup, ClickHouse = fast queries |
| `report_platform_daily` | ✅ Fallback | ✅ Primary | ClickHouse = fast aggregations |
| `report_approval_queue` | ✅ Only | ❌ | Needs instant UPDATE |
| `report_active_auctions` | ✅ Primary | ✅ Copy | Status changes need UPDATE |
| `report_settlements` | ✅ Only | ❌ | Needs instant UPDATE |
| `report_seller_stats` | ✅ Fallback | ✅ Primary | ClickHouse = fast aggregations |
| `report_bid_activity` | ✅ Fallback | ✅ Primary | ClickHouse = fast time-series |

### 4.3 Fallback Strategy

1. **MariaDB is always created** on project init
2. **ClickHouse is optional** — can be removed anytime
3. **API tries ClickHouse first**, falls back to MariaDB on failure
4. **Migration script** exists to move ClickHouse data → MariaDB
5. **Feature flag** `CLICKHOUSE_ENABLED` to disable ClickHouse

---

## 5. Event Flow

### 5.1 Events Consumed

| Source Service | Event Type | Description |
|----------------|------------|-------------|
| **Selling** | `product_listed` | New product created |
| **Selling** | `product_approved` | Admin approved product |
| **Selling** | `product_rejected` | Admin rejected product |
| **Buying** | `user_registered` | New user account |
| **Buying** | `buyer_onboarded` | Buyer completed onboarding |
| **Bidding** | `auction_started` | Seller started auction |
| **Bidding** | `bid_placed` | New bid placed |
| **Bidding** | `auction_ended` | Auction stopped or expired |
| **Settlement** | `invoice_created` | Winner invoiced |
| **Settlement** | `payment_received` | Payment recorded |
| **Settlement** | `settlement_completed` | Settlement finalized |

### 5.2 Event Processing Flow

```
1. Event arrives via Event Bus
2. Event Consumer receives event
3. Event Store saves raw event to report_events (MariaDB)
4. Projection Worker picks up new events
5. Worker updates projection tables in both databases
6. API serves updated data to dashboards
```

---

## 6. Near Real-Time Strategy

| Component | Frequency | Purpose |
|-----------|-----------|---------|
| **Event Bus** | Real-time | Events delivered immediately |
| **Event Consumer** | Real-time | Saves to report_events instantly |
| **Projection Worker** | Every 5 seconds | Processes new events → projection tables |
| **Dashboard Polling** | Every 10-15 seconds | Frontend refreshes data |

**Freshness:** ~10-20 seconds from event to dashboard.

---

## 7. API Endpoints

### 7.1 Operational (MariaDB Only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/reports/approval-queue` | List pending products |
| `POST` | `/api/reports/approval-queue/:id/approve` | Approve product |
| `POST` | `/api/reports/approval-queue/:id/reject` | Reject product |
| `GET` | `/api/reports/settlements` | List settlements |
| `POST` | `/api/reports/settlements/:id/payment` | Record payment |
| `POST` | `/api/reports/settlements/:id/shipment` | Record shipment |
| `POST` | `/api/reports/settlements/:id/complete` | Complete settlement |

### 7.2 Analytics (ClickHouse Primary, MariaDB Fallback)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/reports/overview` | Platform health metrics |
| `GET` | `/api/reports/active-auctions` | Live auctions list |
| `GET` | `/api/reports/sellers` | Seller leaderboard |
| `GET` | `/api/reports/bid-activity` | Bid patterns over time |
| `GET` | `/api/reports/my-listings` | Seller's listings |
| `GET` | `/api/reports/my-bids` | Buyer's bid history |

---

## 8. Implementation Phases

### Phase 1: Foundation (2-3 days)
- [ ] MariaDB schema (all tables)
- [ ] Event consumer + report_events table
- [ ] Projection worker framework
- [ ] Basic API endpoints

### Phase 2: Admin Dashboard (3-4 days)
- [ ] Platform overview metrics
- [ ] Approval queue UI
- [ ] Settlement pipeline UI
- [ ] Active auctions list

### Phase 3: Analytics (2-3 days)
- [ ] ClickHouse schema
- [ ] Dual-write projection worker
- [ ] ClickHouse → MariaDB fallback logic
- [ ] Seller leaderboard + bid activity

### Phase 4: Seller & Buyer Dashboards (3-4 days)
- [ ] Seller listings + revenue
- [ ] Buyer bids + won items
- [ ] Spending analytics

### Phase 5: Polish (2-3 days)
- [ ] Near real-time polling
- [ ] Dashboard UI/UX
- [ ] Migration script (ClickHouse → MariaDB)
- [ ] Documentation

---

## 9. Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **MariaDB 11** | Relational DB | Source of truth, operational tables |
| **ClickHouse** | Columnar DB | Fast analytics (optional) |
| **Event Bus** | Kafka / RabbitMQ | Inter-service communication |
| **Ruby/Sinatra** | Backend | API server |
| **Vue 3** | Frontend | Dashboard UI |

---

## 10. Success Metrics

| Metric | Target |
|--------|--------|
| Dashboard load time | < 2 seconds |
| Data freshness | < 20 seconds |
| API response time (p95) | < 500ms |
| Uptime | 99.9% |
| ClickHouse removal time | < 5 minutes |

---

**End of Architecture Document**
