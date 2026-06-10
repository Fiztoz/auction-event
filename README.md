# Reporting Service

A **read-only** reporting and analytics microservice for the Auction Event platform. This service displays data from other microservices via event consumption.

## ⚠️ Design Principle

> **This service is READ-ONLY.** It does NOT perform actions like approve/reject, record payment, etc.  
> Actions are handled by other microservices via events.

## Features

- 📊 Platform analytics dashboard
- ✅ Approval queue monitoring (view only)
- 💰 Settlement pipeline tracking (view only)
- 🔨 Active auctions monitoring
- 🏆 Seller leaderboard
- 📈 Bid activity analytics
- 🌐 Public auction browse

## Tech Stack

- **Backend:** Ruby + Sinatra + Puma
- **Database:** MariaDB 11
- **Message Queue:** RabbitMQ (Bunny gem)
- **Frontend:** ERB templates + CSS
- **Container:** Docker + Docker Compose

## Quick Start

```bash
# Start all services
docker compose up -d

# Seed demo data (one-time)
docker compose run --rm seeder

# Run tests
docker compose run --rm test

# Access the app
open http://localhost:4567
```

### Docker Profiles

| Profile | Services | Command |
|---------|----------|----------|
| (default) | mariadb, rabbitmq, app | `docker compose up -d` |
| seed | seeder | `docker compose run --rm seeder` |
| test | test | `docker compose run --rm test` |

## Services

| Service | Port | Description |
|---------|------|-------------|
| `app` | 4567 | Sinatra web application |
| `mariadb` | 3306 | MariaDB database |
| `rabbitmq` | 5672 | RabbitMQ message broker |
| `rabbitmq-management` | 15672 | RabbitMQ management UI |

## URLs

| Page | URL |
|------|-----|
| Admin Dashboard | http://localhost:4567/admin |
| Approval Queue | http://localhost:4567/admin/approval |
| Settlements | http://localhost:4567/admin/settlements |
| Active Auctions | http://localhost:4567/admin/auctions |
| Seller Leaderboard | http://localhost:4567/admin/sellers |
| Public Browse | http://localhost:4567/browse |

## API Endpoints

All API endpoints are **read-only**:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/reports/overview` | GET | Platform overview |
| `/api/reports/approval-queue` | GET | Approval queue |
| `/api/reports/settlements` | GET | Settlements |
| `/api/reports/active-auctions` | GET | Active auctions |
| `/api/reports/sellers` | GET | Seller stats |
| `/api/reports/bid-activity` | GET | Bid activity |

## Events Consumed

This service consumes events from RabbitMQ:

### Exchange → Event Mapping

| Exchange | Events |
|----------|--------|
| `selling` | `product.listed`, `product.approved`, `product.rejected`, `auction.started` |
| `bidding` | `bid.placed`, `auction.ended` |
| `settlement` | `settlement.created`, `settlement.invoiced`, `settlement.paid`, `settlement.shipped`, `settlement.completed` |
| `onboarding` | `user.registered` |

## Development

```bash
# Run locally (without Docker)
bundle install
ruby bin/seed.rb
bundle exec rackup -p 4567

# Run tests
ruby test/test_*.rb
```

## Documentation

- [Architecture](docs/reporting-service/ARCHITECTURE.md)
- [Database Schema](docs/reporting-service/DATABASE.md)
- [Event Design](docs/reporting-service/EVENTS.md)
- [Event Payloads](docs/reporting-service/EVENT_PAYLOADS.md)
- [Implementation Guide](docs/reporting-service/IMPLEMENTATION.md)
- [Design System](docs/reporting-service/DESIGN.md)

## License

Internal use only.
