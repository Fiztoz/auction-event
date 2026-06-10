# Reporting Service - Quick Start Guide

## Overview

The Reporting Service is a standalone microservice for platform analytics and admin dashboards, built with Ruby/Sinatra, MariaDB, and Vue.js.

## Services Added to Docker Compose

| Service | Port | Description |
|---------|------|-------------|
| `mariadb` | 3306 | MariaDB 11 database |
| `reporting` | 4568 | Reporting API service |
| `reporting-seeder` | - | Demo data seeder (run once) |

## Quick Start

### 1. Start All Services

```bash
# From project root
docker compose up -d
```

### 2. Seed Demo Data

```bash
# Run the seeder to populate demo data
docker compose run --rm reporting-seeder
```

### 3. Access Services

| Service | URL |
|---------|-----|
| **Main App** | http://localhost:4567 |
| **Admin Dashboard** | http://localhost:4568 |
| **API Health Check** | http://localhost:4568/api/health |
| **MariaDB** | localhost:3306 |
| **MongoDB** | localhost:27017 |
| **MinIO Console** | http://localhost:9001 |

## API Endpoints

### Health Check
```
GET /api/health
```

### Platform Overview
```
GET /api/reports/overview
```

### Approval Queue
```
GET  /api/reports/approval-queue?status=pending_approval
POST /api/reports/approval-queue/:id/approve
POST /api/reports/approval-queue/:id/reject
```

### Settlements
```
GET  /api/reports/settlements?status=invoiced
POST /api/reports/settlements/:id/payment
POST /api/reports/settlements/:id/shipment
POST /api/reports/settlements/:id/complete
```

### Active Auctions
```
GET /api/reports/active-auctions?status=live
```

### Seller Stats
```
GET /api/reports/sellers
```

### Bid Activity
```
GET /api/reports/bid-activity?days=7
```

## Demo Data Seeded

- 31 days of platform metrics
- 8 products in approval queue (5 pending, 3 rejected)
- 10 active auctions
- 8 settlements in pipeline
- 5 sellers with 31 days of stats
- 720 hours of bid activity

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MARIADB_HOST` | mariadb | MariaDB host |
| `MARIADB_PORT` | 3306 | MariaDB port |
| `MARIADB_DATABASE` | reporting | Database name |
| `MARIADB_USER` | root | Database user |
| `MARIADB_PASSWORD` | reporting_password | Database password |
| `API_PORT` | 4568 | API server port |
| `RACK_ENV` | development | Environment |

## Development

### Local Development (without Docker)

```bash
cd lib/reporting

# Install dependencies
bundle install

# Start MariaDB (via Docker)
docker compose up -d mariadb

# Seed demo data
ruby bin/seed_demo_data.rb

# Start the API
bundle exec rackup -p 4568
```

### Run Tests

```bash
cd lib/reporting
bundle exec rake test
```

## Project Structure

```
lib/reporting/
├── api/app.rb              # Sinatra API (10 endpoints)
├── config/
│   ├── env.rb              # Environment configuration
│   └── database.rb         # MariaDB connection
├── db/mariadb/init/
│   └── 01_schema.sql       # 7 tables schema
├── bin/
│   ├── seed_demo_data.rb   # Demo data seeder
│   ├── start.sh            # Startup script
│   └── stop.sh             # Stop script
├── views/
│   └── admin.erb           # Admin dashboard HTML
├── public/
│   ├── css/style.css       # Dashboard styles
│   └── js/app.js           # Vue.js application
├── test/
│   └── test_api.rb         # API tests
├── Dockerfile
├── docker-compose.yml
├── Gemfile
├── README.md
└── TASKS.md
```

## Next Phase (Future)

- [ ] RabbitMQ integration for real-time events
- [ ] ClickHouse for analytics (optional)
- [ ] Seller dashboard
- [ ] Buyer dashboard
- [ ] WebSocket for real-time updates
- [ ] Email notifications

---

**Status:** Admin Dashboard Phase Complete ✅
