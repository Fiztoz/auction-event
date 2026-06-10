# Admin Dashboard — Event Message Payloads

**Service:** Reporting  
**Version:** 1.1  
**Date:** 2026-06-10  

## RabbitMQ Configuration

| Setting | Value |
|---------|-------|
| **Exchange** | `{publisher}` (e.g., `selling`, `bidding`, `settlement`, `onboarding`) |
| **Queue** | `reporting` (consumer service name) |
| **Routing Key** | Event type (e.g., `product.listed`) |

### Exchange → Event Mapping

| Exchange | Events |
|----------|--------|
| `selling` | `product.listed`, `product.approved`, `product.rejected`, `auction.started` |
| `bidding` | `bid.placed`, `auction.ended` |
| `settlement` | `settlement.created`, `settlement.invoiced`, `settlement.paid`, `settlement.shipped`, `settlement.completed` |
| `onboarding` | `user.registered` |

---

## Overview

This document lists all event message payloads consumed by the Reporting Service for the admin dashboard.

---

## 1. Approval Queue

### `product_listed`

Fired when a seller creates a new product listing.

```json
{
  "event_type": "product_listed",
  "source_service": "selling",
  "payload": {
    "product_id": "uuid-1234",
    "seller_id": "seller-5678",
    "seller_name": "John's Shop",
    "title": "Vintage Desk Lamp",
    "category": "home",
    "price_cents": 4500,
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

### `product_approved`

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

### `product_rejected`

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

## 2. Active Auctions

### `auction_started`

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

### `bid_placed`

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

### `auction_ended`

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

## 3. Settlement Pipeline

### `invoice_created`

Fired when a winner is invoiced.

```json
{
  "event_type": "invoice_created",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "product_id": "uuid-1234",
    "product_title": "Vintage Desk Lamp",
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

### `settlement.invoiced`

Fired when settlement status changes to invoiced.

```json
{
  "event_type": "settlement.invoiced",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "product_id": "uuid-1234",
    "product_title": "Vintage Desk Lamp",
    "seller_id": "seller-5678",
    "buyer_id": "buyer-2222",
    "amount_cents": 5000,
    "invoiced_at": "2026-06-16T12:30:00Z"
  }
}
```

**Projection updates:**
- `report_settlements` → UPDATE status = 'invoiced'

---

### `settlement.paid`

Fired when payment is recorded.

```json
{
  "event_type": "settlement.paid",
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

### `settlement.shipped`

Fired when shipment is recorded.

```json
{
  "event_type": "settlement.shipped",
  "source_service": "settlement",
  "payload": {
    "settlement_id": "settle-7777",
    "shipped_at": "2026-06-18T14:00:00Z"
  }
}
```

**Projection updates:**
- `report_settlements` → UPDATE status = 'shipped'

---

### `settlement_completed`

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

## 4. Seller Stats

| Event | Fields Used |
|-------|-------------|
| `product_listed` | `seller_id`, `seller_name` |
| `product_approved` | `product_id` (join with seller) |
| `product_rejected` | `product_id` (join with seller) |
| `auction_started` | `seller_id` |
| `bid_placed` | `product_id` (join with seller) |
| `settlement_completed` | `seller_id`, `amount_cents` |

---

## 5. Platform Daily Metrics

| Event | Source Service | Fields Used |
|-------|----------------|-------------|
| `user_registered` | onboarding | `role` (buyer/seller) |
| `product_listed` | selling | `created_at` |
| `auction_started` | bidding | `started_at` |
| `bid_placed` | bidding | `placed_at` |
| `settlement_completed` | settlement | `amount_cents`, `completed_at` |

---

## 6. Event → Dashboard Mapping

| Admin Page | Events |
|------------|--------|
| **Overview Dashboard** | All events (aggregated) |
| **Approval Queue** | `product_listed`, `product_approved`, `product_rejected` |
| **Active Auctions** | `auction_started`, `bid_placed`, `auction_ended` |
| **Settlement Pipeline** | `settlement.created`, `settlement.invoiced`, `settlement.paid`, `settlement.shipped`, `settlement.completed` |
| **Seller Stats** | All events with `seller_id` |
| **Public Browse** | `auction_started`, `bid_placed` (filtered by status) |

---

## 7. Event Schema Reference

All events must conform to this schema:

```json
{
  "event_type": "string (required)",
  "source_service": "string (required)",
  "payload": "object (required)",
  "created_at": "ISO 8601 timestamp (required)"
}
```

### Valid `event_type` Values

| Event Type | Source Service | Description |
|------------|----------------|-------------|
| `product_listed` | selling | New product created |
| `product_approved` | selling | Product approved by admin |
| `product_rejected` | selling | Product rejected by admin |
| `user_registered` | onboarding | New user account |
| `buyer_onboarded` | onboarding | Buyer completed onboarding |
| `auction_started` | bidding | Auction went live |
| `bid_placed` | bidding | New bid placed |
| `auction_ended` | bidding | Auction ended |
| `invoice_created` | settlement | Winner invoiced |
| `settlement.invoiced` | settlement | Settlement invoiced |
| `settlement.paid` | settlement | Payment recorded |
| `settlement.shipped` | settlement | Shipment recorded |
| `settlement_completed` | settlement | Settlement finalized |

---

**End of Document**
