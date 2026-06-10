# Reporting Service Documentation

**Service:** Reporting  
**Status:** Design Phase  
**Version:** 1.0  
**Date:** 2026-06-09

---

## Overview

The Reporting Service is a read-only aggregation service that consumes events from other microservices and produces dashboards and reports for three user roles: Buyer, Seller, and Admin.

---

## Documents

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, user roles, API endpoints |
| [DATABASE.md](DATABASE.md) | MariaDB and ClickHouse schema design |
| [EVENTS.md](EVENTS.md) | Event types, flow, and consumer implementation |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | Implementation phases, project structure, acceptance criteria |

---

## Key Design Decisions

### 1. Dual-Database Strategy

- **MariaDB** — Source of truth, operational tables, always created
- **ClickHouse** — Optional, analytics tables, fast aggregations
- **Fallback** — If ClickHouse fails, API falls back to MariaDB

### 2. Event-Driven Architecture

All data flows via events from other services:
- Selling Service → product events
- Buying Service → user events
- Bidding Service → auction and bid events
- Settlement Service → settlement events

### 3. CQRS Pattern

- **Write side** — Events are ingested and stored
- **Read side** — Projection tables are optimized for queries
- **Projection Worker** — Runs every 5 seconds to process new events

### 4. Near Real-Time

- Event Bus delivers events in real-time
- Projection Worker processes events every 5 seconds
- Frontend polls every 10-15 seconds
- Total freshness: ~10-20 seconds

---

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Ruby 3.x
- MariaDB 11
- ClickHouse (optional)

### Start Services

```bash
# Start all services
docker compose up -d

# Or start without ClickHouse
docker compose up -d mariadb kafka zookeeper reporting
```

### Access Services

- **Reporting API:** http://localhost:4568
- **MariaDB:** localhost:3306
- **ClickHouse:** http://localhost:8123
- **Kafka:** localhost:9092

---

## API Endpoints

### Operational (MariaDB Only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/reports/approval-queue` | List pending products |
| POST | `/api/reports/approval-queue/:id/approve` | Approve product |
| POST | `/api/reports/approval-queue/:id/reject` | Reject product |
| GET | `/api/reports/settlements` | List settlements |
| POST | `/api/reports/settlements/:id/payment` | Record payment |
| POST | `/api/reports/settlements/:id/shipment` | Record shipment |
| POST | `/api/reports/settlements/:id/complete` | Complete settlement |

### Analytics (ClickHouse Primary, MariaDB Fallback)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/reports/overview` | Platform health metrics |
| GET | `/api/reports/active-auctions` | Live auctions list |
| GET | `/api/reports/sellers` | Seller leaderboard |
| GET | `/api/reports/bid-activity` | Bid patterns over time |
| GET | `/api/reports/my-listings` | Seller's listings |
| GET | `/api/reports/my-bids` | Buyer's bid history |

---

## Implementation Phases

| Phase | Description | Duration |
|-------|-------------|----------|
| Phase 1 | Foundation (Event ingestion + projection) | 2-3 days |
| Phase 2 | Admin Dashboard | 3-4 days |
| Phase 3 | Analytics (ClickHouse integration) | 2-3 days |
| Phase 4 | Seller & Buyer Dashboards | 3-4 days |
| Phase 5 | Polish (Real-time + UI/UX) | 2-3 days |

---

## Migration Strategy

If you want to remove ClickHouse in the future:

1. Run migration script: `ruby bin/migrate_clickhouse_to_mariadb.rb`
2. Set `CLICKHOUSE_ENABLED=false` in environment
3. Stop ClickHouse container
4. Remove ClickHouse from docker-compose.yml (optional)

MariaDB will handle all queries from that point.

---

## Contributing

1. Read the architecture documents
2. Follow the implementation phases
3. Write tests for all new features
4. Update documentation as needed

---

**End of README**
