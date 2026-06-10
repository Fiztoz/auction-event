# Reporting Service — Event Design

**Service:** Reporting  
**Status:** Design Phase  
**Version:** 1.0  
**Date:** 2026-06-09

---

## 1. Overview

The reporting service is **event-driven**. All data flows into the service via events from other microservices. The service consumes events, stores them, and projects them into fast-read tables.

---

## 2. Event Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Event Flow                                │
│                                                              │
│  ┌──────────┐                                               │
│  │ Selling  │──┐                                            │
│  │ Service  │  │                                            │
│  └──────────┘  │                                            │
│                │    ┌──────────────┐                        │
│  ┌──────────┐  ├──► │  Event Bus   │                        │
│  │ Buying   │──┤    │              │                        │
│  │ Service  │  │    └──────┬───────┘                        │
│  └──────────┘  │           │                                │
│                │    ┌──────▼───────┐                        │
│  ┌──────────┐  │    │  Event       │                        │
│  │ Bidding  │──┤    │  Consumer    │                        │
│  │ Service  │  │    └──────┬───────┘                        │
│  └──────────┘  │           │                                │
│                │    ┌──────▼───────┐                        │
│  ┌──────────┐  │    │  Event Store │  (MariaDB)             │
│  │Settlement│──┘    │  report_events│                       │
│  │ Service  │       └──────┬───────┘                        │
│  └──────────┘              │                                │
│                      ┌─────▼──────┐                         │
│                      │ Projection │                         │
│                      │ Worker     │                         │
│                      └─────┬──────┘                         │
│                            │                                │
│                      ┌─────▼──────┐                         │
│                      │ Projection │                         │
│                      │ Tables     │                         │
│                      └────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Event Types

### 3.1 Selling Service Events

#### `product_listed`

Fired when a seller creates a new product listing.

```json
{
  "event_type": "product_listed",
  "source_service": "selling",
  "payload": {
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "title": "Vintage Desk Lamp",
    "category": "home",
    "starting_price_cents": 4500,
    "status": "pending_approval",
    "created_at": "2026-06-09T10:30:00Z"
  }
}
```

**Projection updates:**
- `report_approval_queue` → INSERT
- `report_platform_daily` → total_auctions_created += 1
- `report_seller_stats` → products_listed += 1

---

#### `product_approved`

Fired when an admin approves a product.

```json
{
  "event_type": "product_approved",
  "source_service": "selling",
  "payload": {
    "product_id": "uuid-1234",
    "admin_id": "admin-9999",
    "approved_at": "2026-06-09T11:00:00Z"
  }
}
```

**Projection updates:**
- `report_approval_queue` → UPDATE status = 'draft'
- `report_seller_stats` → products_approved += 1

---

#### `product_rejected`

Fired when an admin rejects a product.

```json
{
  "event_type": "product_rejected",
  "source_service": "selling",
  "payload": {
    "product_id": "uuid-1234",
    "admin_id": "admin-9999",
    "rejection_reason": "Description too vague",
    "rejected_at": "2026-06-09T11:00:00Z"
  }
}
```

**Projection updates:**
- `report_approval_queue` → UPDATE status = 'rejected', rejection_reason
- `report_seller_stats` → products_rejected += 1

---

### 3.2 Buying Service Events

#### `user_registered`

Fired when a new user account is created.

```json
{
  "event_type": "user_registered",
  "source_service": "buying",
  "payload": {
    "user_id": "user-1111",
    "role": "buyer",
    "email": "user@example.com",
    "registered_at": "2026-06-09T09:00:00Z"
  }
}
```

**Projection updates:**
- `report_platform_daily` → total_users += 1, new_users += 1
- `report_platform_daily` → total_buyers += 1 (if role=buyer) or total_sellers += 1 (if role=seller)

---

#### `buyer_onboarded`

Fired when a buyer completes onboarding.

```json
{
  "event_type": "buyer_onboarded",
  "source_service": "buying",
  "payload": {
    "user_id": "user-1111",
    "onboarded_at": "2026-06-09T09:30:00Z"
  }
}
```

**Projection updates:**
- None (informational event for auditing)

---

### 3.3 Bidding Service Events

#### `auction_started`

Fired when a seller starts an auction.

```json
{
  "event_type": "auction_started",
  "source_service": "bidding",
  "payload": {
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "title": "Vintage Desk Lamp",
    "category": "home",
    "starting_price_cents": 4500,
    "status": "live",
    "started_at": "2026-06-09T12:00:00Z",
    "ends_at": "2026-06-16T12:00:00Z"
  }
}
```

**Projection updates:**
- `report_active_auctions` → INSERT
- `report_platform_daily` → active_auctions += 1, total_auctions_created += 1
- `report_seller_stats` → auctions_started += 1

---

#### `bid_placed`

Fired when a new bid is placed.

```json
{
  "event_type": "bid_placed",
  "source_service": "bidding",
  "payload": {
    "product_id": "uuid-1234",
    "bidder_id": "buyer-2222",
    "amount_cents": 5000,
    "bid_count": 3,
    "placed_at": "2026-06-09T13:00:00Z"
  }
}
```

**Projection updates:**
- `report_active_auctions` → UPDATE current_bid_cents, bid_count
- `report_platform_daily` → total_bids += 1
- `report_bid_activity` → total_bids += 1, unique_bidders += 1
- `report_seller_stats` → bids_received += 1

---

#### `auction_ended`

Fired when an auction is stopped or expires.

```json
{
  "event_type": "auction_ended",
  "source_service": "bidding",
  "payload": {
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "winner_id": "buyer-2222",
    "final_price_cents": 5000,
    "bid_count": 5,
    "ended_at": "2026-06-16T12:00:00Z"
  }
}
```

**Projection updates:**
- `report_active_auctions` → UPDATE status = 'ended'
- `report_platform_daily` → active_auctions -= 1
- `report_seller_stats` → auctions_ended += 1

---

### 3.4 Settlement Service Events

#### `invoice_created`

Fired when a winner is invoiced.

```json
{
  "event_type": "invoice_created",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "buyer_id": "buyer-2222",
    "amount_cents": 5000,
    "status": "invoiced",
    "created_at": "2026-06-16T12:30:00Z"
  }
}
```

**Projection updates:**
- `report_settlements` → INSERT

---

#### `payment_received`

Fired when payment is recorded.

```json
{
  "event_type": "payment_received",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "amount_cents": 5000,
    "paid_at": "2026-06-17T10:00:00Z"
  }
}
```

**Projection updates:**
- `report_settlements` → UPDATE status = 'paid'

---

#### `settlement_completed`

Fired when settlement is finalized.

```json
{
  "event_type": "settlement_completed",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "buyer_id": "buyer-2222",
    "amount_cents": 5000,
    "completed_at": "2026-06-20T14:00:00Z"
  }
}
```

**Projection updates:**
- `report_settlements` → UPDATE status = 'completed'
- `report_platform_daily` → total_revenue_cents += amount, settlements_completed += 1
- `report_seller_stats` → revenue_cents += amount

---

## 4. Event Consumer Implementation

```ruby
class EventConsumer
  def initialize(event_bus, event_store, projection_worker)
    @event_bus = event_bus
    @event_store = event_store
    @projection_worker = projection_worker
  end

  def start
    @event_bus.subscribe do |event|
      # 1. Store raw event
      @event_store.save(event)
      
      # 2. Project to tables
      @projection_worker.project(event)
    end
  end
end
```

---

## 5. Event Store Implementation

```ruby
class EventStore
  def initialize(mariadb_client)
    @mariadb = mariadb_client
  end

  def save(event)
    @mariadb.insert("report_events", {
      event_type: event.type,
      source_service: event.source,
      payload: event.payload.to_json,
      created_at: event.created_at
    })
  end

  def find_by_type(event_type, since: nil)
    query = "SELECT * FROM report_events WHERE event_type = ?"
    params = [event_type]
    
    if since
      query += " AND created_at >= ?"
      params << since
    end
    
    query += " ORDER BY created_at DESC"
    @mariadb.query(query, params)
  end

  def last_processed_id
    @mariadb.query("SELECT MAX(id) as id FROM report_events").first&.dig("id") || 0
  end
end
```

---

## 6. Event Bus Integration

### 6.1 Kafka Configuration

```yaml
# config/kafka.yml
development:
  brokers: ["localhost:9092"]
  group_id: "reporting-service"
  topics:
    - "selling.events"
    - "buying.events"
    - "bidding.events"
    - "settlement.events"
```

### 6.2 RabbitMQ Configuration

```yaml
# config/rabbitmq.yml
development:
  host: "localhost"
  port: 5672
  exchanges:
    - name: "selling.events"
      type: "topic"
    - name: "buying.events"
      type: "topic"
    - name: "bidding.events"
      type: "topic"
    - name: "settlement.events"
      type: "topic"
```

---

## 7. Event Schema Validation

All events must conform to this schema:

```ruby
EventSchema = {
  event_type: String,      # Required: "product_listed", "bid_placed", etc.
  source_service: String,  # Required: "selling", "buying", "bidding", "settlement"
  payload: Hash,           # Required: Event-specific data
  created_at: Time         # Required: ISO 8601 timestamp
}
```

---

**End of Event Design Document**
