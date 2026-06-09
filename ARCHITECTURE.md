# Architecture Document — Basic4 Auction Platform

**Version:** 1.0  
**Date:** 2026-06-09  
**Status:** Active

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technology Stack](#technology-stack)
3. [System Architecture](#system-architecture)
4. [Application Structure](#application-structure)
5. [Domain Model](#domain-model)
6. [Database Design](#database-design)
7. [API Design](#api-design)
8. [Frontend Architecture](#frontend-architecture)
9. [Infrastructure & Deployment](#infrastructure--deployment)
10. [Security Architecture](#security-architecture)
11. [Design Patterns](#design-patterns)
12. [Integration Points](#integration-points)

---

## Executive Summary

Basic4 is built using **Hexagonal Architecture** (Ports and Adapters) with a strong emphasis on separating domain logic from infrastructure concerns. The system uses Ruby 4.0.5 with Sinatra as the web framework, MongoDB for persistence, and MinIO for object storage.

**Key Architectural Decisions:**
- **Hexagonal Architecture** for testability and maintainability
- **Domain-Driven Design** principles with bounded contexts
- **Result pattern** for explicit error handling
- **Immutable value objects** for domain entities
- **Stateless application design** for scalability
- **Event-driven frontend** with vanilla JavaScript

---

## Technology Stack

### Backend Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Language** | Ruby | 4.0.5 | Primary programming language |
| **Alternative Runtime** | JRuby | 10.0.5.0 | JVM-based Ruby for performance |
| **Web Framework** | Sinatra | Latest | Lightweight HTTP framework |
| **Web Server** | Puma | Latest | Concurrent HTTP server |
| **Database** | MongoDB | 7+ | Document database |
| **Object Storage** | MinIO | Latest | S3-compatible storage |
| **Authentication** | bcrypt | Latest | Password hashing |
| **Session Management** | Rack::Session | Built-in | Cookie-based sessions |

### Frontend Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Framework** | Vanilla JavaScript | No framework dependency |
| **UI Library** | None | Custom HTML/CSS |
| **State Management** | Custom store.js | Reactive state singleton |
| **Event System** | Custom events.js | Pub/sub event bus |
| **API Client** | Custom api.js | Fetch wrapper |
| **Styling** | Custom CSS | Coinbase-inspired theme |

### Infrastructure Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Containerization** | Docker | Application packaging |
| **Orchestration** | Docker Compose | Local development |
| **Process Management** | Puma | Multi-threaded server |
| **Reverse Proxy** | None (dev) | Direct Puma exposure |

### Development Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Testing** | Minitest | Unit and integration tests |
| **HTTP Testing** | rack-test | API testing |
| **Task Runner** | Rake | Build and test tasks |
| **Version Control** | Git | Source code management |
| **Environment Config** | dotenv | Environment variables |

---

## System Architecture

### Hexagonal Architecture (Ports and Adapters)

The system follows **Hexagonal Architecture** to separate core business logic from external dependencies:

```
┌─────────────────────────────────────────────────────────────┐
│                    DRIVING ADAPTERS                          │
│  (HTTP Controllers, CLI, Tests)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Sinatra     │  │  CLI Tools   │  │  Test Suite  │      │
│  │  Routes      │  │  (bin/*)     │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                         │
│  (Use Cases / Services)                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Register    │  │  PlaceBid    │  │  Invoice     │      │
│  │  User        │  │              │  │  Winner      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                              │
│  (Aggregates, Value Objects, Domain Services)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  User        │  │  Product     │  │  Settlement  │      │
│  │  Aggregate   │  │  Aggregate   │  │  Aggregate   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    PORTS (Interfaces)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  UserRepo    │  │  Password    │  │  Object      │      │
│  │  Port        │  │  Hasher      │  │  Storage     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    DRIVEN ADAPTERS                           │
│  (Infrastructure Implementations)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  MongoDB     │  │  BCrypt      │  │  MinIO/S3    │      │
│  │  Repository  │  │  Hasher      │  │  Storage     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Bounded Contexts

The system is organized into **8 bounded contexts**, each representing a distinct business capability:

```
┌─────────────────────────────────────────────────────────────┐
│                    Basic4 System                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ CheckExisting   │  │ Register        │                  │
│  │ Context         │  │ Context         │                  │
│  │ - Email check   │  │ - User signup   │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ VerifyToken     │  │ BuyerOnboarding │                  │
│  │ Context         │  │ Context         │                  │
│  │ - Email verify  │  │ - Ship address  │                  │
│  │ - Resend token  │  │                 │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ CreditScoring   │  │ Identity        │                  │
│  │ Context         │  │ Context         │                  │
│  │ - Score calc    │  │ - Login         │                  │
│  │ - Approve/reject│  │ - Profile       │                  │
│  │ - List pending  │  │ - Password reset│                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ ProductAuction  │  │ Settlement      │                  │
│  │ Context         │  │ Context         │                  │
│  │ - List product  │  │ - Invoice       │                  │
│  │ - Update auction│  │ - Payment       │                  │
│  │ - Start/stop    │  │ - Shipment      │                  │
│  │ - Place bid     │  │ - Complete      │                  │
│  │ - Browse/show   │  │ - Queue/detail  │                  │
│  │ - Upload image  │  │                 │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────────┐              │
│  │ Admin           │  │                      │              │
│  │ Context         │  │                      │              │
│  │ - Approve       │  │                      │              │
│  │ - Reject        │  │                      │              │
│  │ - List pending  │  │                      │              │
│  └─────────────────┘  └──────────────────────┘              │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    Shared Kernel                             │
│  - Aggregates: User, Product, Bid, Settlement, Notification │
│  - Value Objects: EmailVerification, CreditScoreSnapshot,   │
│                   ShippingAddress, PasswordReset             │
│  - Result Pattern: Success/Failure with chaining            │
│  - Container: Dependency injection                          │
└─────────────────────────────────────────────────────────────┘
```

### Shared Kernel

The **Shared Kernel** contains domain concepts used across multiple contexts:

**Aggregates:**
- `User` — User account with onboarding state
- `Product` — Auction listing with bidding state (statuses: pending_approval, draft, live, ended, completed, rejected)
- `Bid` — Individual bid record
- `Settlement` — Post-auction order management
- `Notification` — In-app notification for users (types: product_pending_approval, product_approved, product_rejected)

**Value Objects:**
- `EmailVerification` — Email verification token with expiry
- `CreditScoreSnapshot` — Credit score with inputs and timestamp
- `ShippingAddress` — US-style shipping address
- `PasswordReset` — Password reset token with expiry

**Result Pattern:**
```ruby
module Basic4::Result
  Success = Data.define(:value)
  Failure = Data.define(:field, :message)
  
  module Chain
    def bind(&block)
      success? ? yield(value) : self
    end
    
    def map(&block)
      success? ? Success.new(value: yield(value)) : self
    end
    
    def tap_ok(&block)
      yield(value) if success?
      self
    end
  end
end
```

---

## Application Structure

### Directory Layout

```
auction-event/
├── app.rb                          # Sinatra setup + helpers
├── routes.rb                       # HTTP route definitions
├── config.ru                       # Rack entry point
├── Rakefile                        # Build tasks
├── Gemfile                         # Ruby dependencies
├── Dockerfile                      # Container definition
├── docker-compose.yml              # Service orchestration
│
├── lib/
│   ├── basic4.rb                   # Library module
│   └── basic4/
│       ├── shared/                 # SHARED KERNEL
│       │   ├── shared.rb           # Namespace declarations
│       │   ├── result.rb           # Result pattern
│       │   ├── db.rb               # MongoDB connection
│       │   ├── container.rb        # Dependency injection
│       │   ├── user.rb             # User aggregate
│       │   ├── product.rb          # Product aggregate
│       │   ├── bid.rb              # Bid aggregate
│       │   ├── settlement.rb       # Settlement aggregate
│       │   ├── *_presenter.rb      # JSON presenters
│       │   ├── ports/              # Abstract interfaces
│       │   └── infrastructure/     # Concrete adapters
│       │
│       ├── check_existing/         # CONTEXT 1
│       ├── register/               # CONTEXT 2
│       ├── verify_token/           # CONTEXT 3
│       ├── buyer_onboarding/       # CONTEXT 4
│       ├── credit_scoring/         # CONTEXT 5
│       ├── identity/               # CONTEXT 6
│       ├── product_auction/        # CONTEXT 7
│       └── settlement/             # CONTEXT 8
│
├── views/
│   ├── index.erb                   # SPA mount point
│   ├── browse.erb                  # Public catalog page
│   └── admin.erb                   # Admin console page
│
├── public/
│   ├── css/style.css               # Application styles
│   └── js/                         # Frontend JavaScript
│
├── test/                           # Test suite
│
└── bin/                            # CLI tools
```

### Layer Responsibilities

**1. Presentation Layer (app.rb, routes.rb)**
- HTTP request/response handling
- Parameter extraction and validation
- Session management
- JSON serialization via presenters
- Error handling and status codes

**2. Application Layer (lib/basic4/*/application/)**
- Use case orchestration
- Input validation via Input objects
- Dependency injection via container
- Result pattern for success/failure
- No business logic (delegates to domain)

**3. Domain Layer (lib/basic4/shared/, lib/basic4/*/domain/)**
- Business rules and validation
- Aggregate state transitions
- Value object definitions
- Pure domain services (e.g., credit scoring)

**4. Infrastructure Layer (lib/basic4/shared/infrastructure/)**
- Database access (MongoDB)
- External service integration (MinIO)
- Cryptographic operations (bcrypt)
- Token generation (SecureRandom)
- Time abstraction (SystemClock)

---

## Domain Model

### Aggregate: User

```ruby
User = Data.define(
  :id,                          # UUID
  :email,                       # String (unique)
  :name,                        # String
  :password_hash,               # String (bcrypt)
  :role,                        # "buyer" | "seller" | "admin"
  :step,                        # "verify_email" | "shipping_address" | "done" | "credit_scoring"
  :email_verification,          # EmailVerification (value object)
  :credit_score,                # CreditScoreSnapshot (value object, nullable)
  :shipping_address,            # ShippingAddress (value object, nullable)
  :password_reset,              # PasswordReset (value object, nullable)
  :created_at,                  # Time
  :updated_at                   # Time
)
```

**State Transitions:**
```
[New User] → verify_email → shipping_address → done (buyer)
                                                        ↓
                                              credit_scoring → done (seller)
```

**Key Methods:**
- `verify_email(token, at)` — Validates token and advances to shipping_address
- `save_shipping_address(address, at)` — Saves address and advances to done
- `start_seller_application(at)` — Transitions to credit_scoring step
- `apply_credit_score(score, inputs, at)` — Stores credit score snapshot
- `approve_seller_application(at)` — Changes role to seller, step to done
- `reject_seller_application(at)` — Reverts to buyer, step to done
- `change_email(email, token, at)` — Updates email, resets to verify_email
- `change_password(hash, at)` — Updates password hash
- `issue_password_reset(token, at)` — Creates password reset token
- `consume_password_reset(token, hash, at)` — Validates token and updates password

### Aggregate: Product

```ruby
Product = Data.define(
  :id,                          # UUID
  :seller_id,                   # UUID (references User)
  :title,                       # String (max 120 chars)
  :description,                 # String
  :category,                    # "electronics" | "collectibles" | "fashion" | "home" | "toys" | "other"
  :starting_price_cents,        # Integer (min 1)
  :duration_days,               # Integer (1-30)
  :images,                      # Array<String> (max 3 URLs)
  :status,                      # "pending_approval" | "draft" | "live" | "ended" | "completed" | "rejected"
  :started_at,                  # Time (nullable)
  :ends_at,                     # Time (nullable, informational)
  :ended_at,                    # Time (nullable)
  :current_bid_cents,           # Integer (nullable, denormalized)
  :bid_count,                   # Integer
  :highest_bidder_id,           # UUID (nullable, denormalized)
  :created_at,                  # Time
  :updated_at,                  # Time
  :approved_at,                 # Time (nullable, set when admin approves)
  :rejection_reason,            # String (nullable, set when admin rejects)
)
```

**Statuses:**
- `pending_approval` — Initial state after seller creates product (hidden from public browse)
- `draft` — Approved by admin, ready for seller to start auction
- `live` — Auction is active and accepting bids
- `ended` — Auction has been stopped by seller
- `completed` — Settlement has been finalized by admin
- `rejected` — Admin rejected the product with a reason (hidden from public browse)

**State Transitions:**
```
                    ┌──────────────────┐
                    │ PENDING_APPROVAL │  ← Seller creates
                    └────────┬─────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
    [Admin: Approve]  [Admin: Reject]  [Seller: Edit]
            │                │                │
            ↓                ↓                ↓
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │    DRAFT     │  │  REJECTED    │  │  PENDING     │
    │  (approved)  │  │  + reason    │  │ (resubmit)   │
    └───────┬──────┘  └──────┬───────┘  └──────────────┘
            │                │
    [Seller: Start]   [Seller: Edit & Resubmit]
            │                │
            ↓                ↓
    ┌──────────────┐   (back to PENDING)
    │    LIVE      │
    └───────┬──────┘
            │ [Seller: Stop]
            ↓
    ┌──────────────┐
    │    ENDED     │
    └───────┬──────┘
            │ [Admin: Complete via Settlement]
            ↓
    ┌──────────────┐
    │  COMPLETED   │
    └──────────────┘
```

**Key Methods:**
- `approve(at)` — Transitions `pending_approval → draft`, sets `approved_at`
- `reject(reason, at)` — Transitions `pending_approval → rejected`, sets `rejection_reason`
- `update_details(...)` — Allows editing in `pending_approval`, `draft`, and `rejected` states; editing a rejected product auto-resubmits to `pending_approval`
- `start(at)` — Transitions `draft → live` (only if `approved_at` is set)
- `stop(at)` — Transitions `live → ended`

### Aggregate: Bid

```ruby
Bid = Data.define(
  :id,                          # UUID
  :product_id,                  # UUID (references Product)
  :bidder_id,                   # UUID (references User)
  :bidder_name,                 # String (snapshot at bid time)
  :amount_cents,                # Integer
  :created_at                   # Time
)
```

### Aggregate: Settlement

```ruby
Settlement = Data.define(
  :id,                          # UUID
  :product_id,                  # UUID (references Product)
  :seller_id,                   # UUID (references User)
  :buyer_id,                    # UUID (references User)
  :amount_cents,                # Integer (snapshotted from winning bid)
  :shipping_address,            # ShippingAddress (snapshotted from buyer)
  :status,                      # "invoiced" | "paid" | "shipped" | "completed"
  :invoiced_at,                 # Time
  :paid_at,                     # Time (nullable)
  :shipped_at,                  # Time (nullable)
  :completed_at,                # Time (nullable)
  :created_at,                  # Time
  :updated_at                   # Time
)
```

**State Transitions:**
```
[invoiced] --record_payment--> [paid] --record_shipment--> [shipped] --complete--> [completed]
```

### Aggregate: Notification

```ruby
Notification = Data.define(
  :id,                          # UUID
  :user_id,                     # UUID (recipient, references User)
  :type,                        # "product_pending_approval" | "product_approved" | "product_rejected"
  :title,                       # String (short summary)
  :body,                        # String (detailed message)
  :related_id,                  # String (product ID for navigation)
  :read,                        # Boolean
  :created_at,                  # Time
  :read_at                      # Time (nullable)
)

**Types:**
- `product_pending_approval` — Sent to all admins when a seller creates a product
- `product_approved` — Sent to the seller when an admin approves their product
- `product_rejected` — Sent to the seller when an admin rejects their product (includes reason)

**Key Methods:**
- `mark_read(at)` — Sets `read = true` and `read_at` timestamp

### Value Objects

**EmailVerification:**
- 6-digit numeric token
- 15-minute TTL
- Tracks verification timestamp

**CreditScoreSnapshot:**
- score: Integer (300-850)
- inputs: Hash (income, employment, debt, history_years)
- computed_at: Time

**ShippingAddress:**
- line1, line2 (optional), city, region, postal_code, country

**PasswordReset:**
- 16-character alphanumeric token
- 1-hour TTL

---

## Database Design

### MongoDB Collections

The system uses **4 collections** in MongoDB:

#### 1. users
- Stores user accounts with onboarding state
- Unique index on email
- Nested documents for email_verification, credit_score, shipping_address, password_reset

#### 2. products
- Stores auction listings
- Index on seller_id for querying seller's auctions
- Denormalized bid fields: current_bid_cents, bid_count, highest_bidder_id

#### 3. bids
- Stores individual bid records
- Compound index on (product_id, created_at DESC) for bid history
- Snapshots bidder_name at bid time

#### 4. settlements
- Stores post-auction order management
- Unique index on product_id (one settlement per auction)
- Snapshots winning bid amount and buyer's shipping address

### Data Access Patterns

**Repository Pattern:**
Each aggregate has a dedicated repository port with MongoDB implementation:

```ruby
# Port (interface)
module Basic4::Ports::UserRepository
  def self.find_by_id(id); end
  def self.find_by_email(email); end
  def self.store(user); end
end

# Adapter (implementation)
module Basic4::Infrastructure::MongoUserRepository
  def self.find_by_id(id)
    doc = Basic4::DB.users.find(_id: id).first
    doc && hydrate(doc)
  end
  
  def self.store(user)
    Basic4::DB.users.find_one_and_replace(
      { _id: user.id },
      serialize(user),
      upsert: true
    )
  end
  
  private
  
  def self.hydrate(doc)
    # Convert MongoDB document to User aggregate
  end
  
  def self.serialize(user)
    # Convert User aggregate to MongoDB document
  end
end
```

---

## API Design

### RESTful Endpoints

The API follows RESTful conventions with JSON request/response bodies.

**Authentication & Onboarding:**
- POST `/api/signup` — Register new user
- POST `/api/login` — Authenticate user
- POST `/api/signout` — End session
- GET `/api/me` — Get current user
- POST `/api/onboarding/verify-email` — Verify email token
- POST `/api/onboarding/shipping-address` — Save shipping address
- POST `/api/onboarding/become-seller` — Start seller application
- POST `/api/onboarding/credit-score` — Submit credit score

**Product Auctions:**
- GET `/api/products` — Browse all auctions
- GET `/api/products/:id` — Get auction details + bids
- POST `/api/products` — Create auction listing (seller only)
- PUT `/api/products/:id` — Update draft auction (seller only)
- POST `/api/products/:id/start` — Start auction (seller only)
- POST `/api/products/:id/stop` — Stop auction (seller only)
- POST `/api/products/:id/bid` — Place bid on auction

**Admin Operations:**
- GET `/api/admin/auctions` — List closed auctions
- GET `/api/admin/settlements` — Get settlement queue
- POST `/api/admin/products/:id/settlement` — Create settlement
- POST `/api/admin/settlements/:id/payment` — Record payment
- POST `/api/admin/settlements/:id/shipment` — Record shipment
- POST `/api/admin/settlements/:id/complete` — Complete settlement
- POST `/api/admin/seller-applications/:id/approve` — Approve seller
- POST `/api/admin/seller-applications/:id/reject` — Reject seller

### Request/Response Format

**Success Response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "buyer",
    "step": "done"
  }
}
```

**Error Response:**
```json
{
  "error": "invalid email",
  "field": "email"
}
```

**HTTP Status Codes:**
- `200 OK` — Success
- `201 Created` — Resource created
- `400 Bad Request` — Invalid JSON
- `401 Unauthorized` — Not authenticated
- `403 Forbidden` — Insufficient permissions
- `404 Not Found` — Resource not found
- `422 Unprocessable Entity` — Validation error

### Authentication

**Session-Based Authentication:**
- Uses Rack::Session::Cookie for session management
- Session secret configured via environment variable
- Session contains `user_id` after successful login
- `current_user` helper retrieves user from database

**Authorization Helpers:**
```ruby
def require_user!
  halt 401, json(error: "not signed in") unless session[:user_id]
end

def require_seller!
  require_user!
  halt 403, json(error: "become a seller first") unless current_user&.role == "seller"
end

def require_admin!
  require_user!
  halt 403, json(error: "admins only") unless current_user&.role == "admin"
end
```

---

## Frontend Architecture

### Vanilla JavaScript SPA

The frontend is a **single-page application** built with vanilla JavaScript (no framework):

**Key Components:**
1. **app.js** — Main entry point, routing logic
2. **api.js** — HTTP client wrapper
3. **store.js** — Reactive state management
4. **actions.js** — Side effects (API calls)
5. **events.js** — Pub/sub event bus
6. **components/** — Screen components (signup, login, dashboard, etc.)
7. **subscribers/** — Event listeners (console-logger)

### State Management

**Reactive Store (store.js):**
- Uses Vue's `reactive` for reactivity but no Vue components
- Centralized state object
- Automatic UI updates when state changes

### Event System

**Pub/Sub Bus (events.js):**
- Decouples components via event emission
- 16 event types (UserSignedUp, EmailVerified, AuctionStarted, etc.)
- Console logger subscriber for debugging

### Routing

**Hash-Based Routing (app.js):**
- Routes based on user.step and state.authMode
- No client-side router library
- Simple conditional rendering

### API Client

**Fetch Wrapper (api.js):**
- JSON request/response handling
- Automatic error extraction
- Separate `apiUpload` for multipart uploads

### Component Structure

**Screen Components:**
- Self-contained modules with setup function and template
- No build step required
- Vue-like template syntax (but not actual Vue)

### Styling

**Custom CSS (style.css):**
- Coinbase-inspired design system
- Responsive layout
- Card-based UI
- Form validation states
- Auction status badges

---

## Infrastructure & Deployment

### Container Architecture

**Docker Compose Services:**
- `mongo` — MongoDB 7 database
- `minio` — MinIO object storage
- `app` — JRuby application

**Volumes:**
- `mongo_data` — MongoDB persistence
- `minio_data` — Object storage persistence
- `bundle_cache` — Ruby gem cache

### Application Container

**Dockerfile:**
- JRuby 10.0.5.0 base image (JVM-based)
- Production environment by default
- Puma web server via rackup
- Exposes port 4567

### Environment Configuration

**Required Environment Variables:**
- `MONGO_URL` — MongoDB connection string
- `MONGO_DB` — Database name
- `SESSION_SECRET` — Session signing secret (64+ chars)
- `PORT` — Application port
- `RACK_ENV` — Environment (development/production)
- `MINIO_ENDPOINT` — MinIO server URL
- `MINIO_PUBLIC_URL` — Public URL for images
- `MINIO_ACCESS_KEY` — MinIO access key
- `MINIO_SECRET_KEY` — MinIO secret key
- `MINIO_BUCKET` — MinIO bucket name

### Local Development

**Setup:**
1. Clone repository
2. Configure environment variables
3. Start services with `docker compose up --build`
4. Access application at `http://localhost:4567`

**Development Workflow:**
- Source code mounted as volume (live reload for JS/CSS)
- Ruby changes require `docker compose restart app`
- MongoDB accessible at `localhost:27017`
- MinIO console at `http://localhost:9001`

### Testing

**Test Command:**
```bash
docker compose exec app bundle exec rake test
```

**Test Coverage:**
- Unit tests for domain logic (credit scoring, state transitions)
- Integration tests for API endpoints
- All tests use test database

### CLI Tools

**bin/create_admin:**
- Creates admin account via CLI
- Supports environment variables or command-line arguments

**bin/basic4-report:**
- Generates CSV reports

---

## Security Architecture

### Authentication Security

**Password Hashing:**
- Algorithm: bcrypt
- Cost factor: Default (10-12 rounds)
- Storage: Hash stored in `users.password_hash`

**Session Management:**
- Type: Signed cookie (Rack::Session::Cookie)
- Secret: Configured via environment variable (64+ chars)
- Contents: `user_id` only
- Expiry: Browser session (no persistent cookie)

**Token Generation:**
- Email verification: 6-digit numeric, 15-minute TTL
- Password reset: 16-character alphanumeric, 1-hour TTL
- Implementation: SecureRandom

### Authorization Security

**Role-Based Access Control:**
```ruby
# Three-tier authorization
def require_user!
  halt 401 unless session[:user_id]
end

def require_seller!
  require_user!
  halt 403 unless current_user&.role == "seller"
end

def require_admin!
  require_user!
  halt 403 unless current_user&.role == "admin"
end
```

**Ownership Protection:**
- Sellers can only edit/start/stop their own auctions
- Ownership checks collapse "not found" and "not yours" into single error
- Prevents enumeration attacks

### Data Protection

**Sensitive Data Handling:**
- Passwords: Never logged, never returned in API responses
- Admin PII: Only visible to Admin role in settlement context
- Bidder identity: Hidden from other bidders (shows "You" for current user)

**Input Validation:**
- Email format validation (regex)
- Password length validation (min 8 chars)
- Numeric field validation (positive integers)
- Category whitelist validation
- Image type/size validation

### Security Best Practices

**Implemented:**
- Password hashing with bcrypt
- Session signing with strong secret
- CSRF protection via same-origin cookies
- Input validation on all endpoints
- Error message normalization (no information leakage)
- Token expiration for verification/reset
- Ownership checks on mutable operations
- Role-based access control

---

## Design Patterns

### 1. Hexagonal Architecture (Ports and Adapters)

**Purpose:** Separate domain logic from infrastructure

**Implementation:**
- **Ports:** Abstract interfaces in `lib/basic4/shared/ports/`
- **Adapters:** Concrete implementations in `lib/basic4/shared/infrastructure/`
- **Dependency Injection:** Via `Basic4::Container`

### 2. Result Pattern (Monadic Error Handling)

**Purpose:** Explicit success/failure without exceptions

**Implementation:**
```ruby
module Basic4::Result
  Success = Data.define(:value)
  Failure = Data.define(:field, :message)
  
  module Chain
    def bind(&block)
      success? ? yield(value) : self
    end
    
    def map(&block)
      success? ? Success.new(value: yield(value)) : self
    end
    
    def tap_ok(&block)
      yield(value) if success?
      self
    end
  end
end
```

### 3. Aggregate Pattern (Domain-Driven Design)

**Purpose:** Encapsulate business rules and state transitions

**Characteristics:**
- Immutable data structures (Ruby Data.define)
- Methods return new instances (no mutation)
- Validation inside aggregate methods
- State transitions are explicit

### 4. Repository Pattern

**Purpose:** Abstract data persistence

**Implementation:**
- Port defines interface
- Adapter implements MongoDB operations
- Hydration/serialization for nested objects

### 5. Presenter Pattern (View Models)

**Purpose:** Transform domain objects for API responses

**Implementation:**
- Converts aggregates to JSON-safe hashes
- Hides sensitive fields (password_hash)
- Formats nested value objects

### 6. Use Case Pattern (Application Services)

**Purpose:** Orchestrate domain operations

**Implementation:**
- Single public `call` method
- Validates input
- Orchestrates domain operations
- Returns Result (Success/Failure)

### 7. Value Object Pattern

**Purpose:** Immutable, validated data structures

**Characteristics:**
- Immutable (Ruby Data.define)
- Value equality (not identity)
- Validation at construction
- No behavior (pure data)

### 8. Event Bus Pattern (Frontend)

**Purpose:** Decouple components via pub/sub

**Implementation:**
- `on(fn)` — Subscribe to events
- `emit(name, payload)` — Publish events
- Listeners receive event objects with name, payload, timestamp

### 9. Reactive Store Pattern (Frontend)

**Purpose:** Centralized state management with reactivity

**Implementation:**
- Uses Vue's `reactive` function
- Automatic UI updates when state changes
- No framework dependency (vanilla JS)

### 10. Container Pattern (Dependency Injection)

**Purpose:** Manage dependencies and enable testing

**Implementation:**
- Production container returns infrastructure modules
- Test container returns mocks/stubs
- Use cases accept container parameter

---

## Integration Points

### 1. MongoDB Integration

**Connection Management:**
- Connection pooling (Mongo driver default)
- Index management on startup
- Upsert operations for aggregates
- Hydration/serialization for nested objects

**Indexes:**
- `users.email` (unique) — Fast email lookup
- `products.seller_id` — Seller's auctions query
- `bids.product_id, created_at` — Bid history (sorted)
- `settlements.product_id` (unique) — Settlement lookup

### 2. MinIO/S3 Integration

**Object Storage:**
- S3-compatible API (works with AWS S3, MinIO, etc.)
- Automatic bucket creation on first use
- Public read policy for product images
- Separate public URL for browser access

**Features:**
- Image upload via multipart form
- Validates content type and size
- Returns public URL for display
- Key format: `products/{seller_id}/{uuid}.{ext}`

### 3. BCrypt Integration

**Password Hashing:**
- Automatic salt generation
- Configurable cost factor
- Constant-time comparison

### 4. Notification Integration

**Current Implementation (stdout):**
- Logs verification tokens to console
- Logs password reset tokens to console
- Suitable for development

**Future Integration (SMTP):**
- Send emails via SMTP
- Template-based email content
- Configurable SMTP settings

### 5. Clock Integration

**Time Abstraction:**
- SystemClock returns current UTC time
- Test double returns fixed time
- Enables deterministic testing

---

## Performance Considerations

### Database Optimization

**Query Patterns:**
- Use `find_one_and_replace` with `upsert: true` for aggregate storage
- Batch reads where possible (e.g., settlement queue)
- Denormalize frequently accessed data (current_bid_cents on Product)

### Concurrency

**JRuby Benefits:**
- True multi-threading (JVM)
- Parallel request handling
- Better throughput than MRI Ruby

### Scalability Path

**Current Limitations:**
- Single application instance
- Session stored in cookies (no shared state needed)
- MongoDB single node

**Scaling Strategy:**
1. **Horizontal scaling:** Add more app instances (stateless design)
2. **Load balancer:** Nginx or HAProxy in front of Puma
3. **MongoDB replica set:** For read scalability and failover
4. **Redis:** For session storage if cookies become limiting
5. **CDN:** For static assets and product images

---

## Testing Strategy

### Test Pyramid

```
        /\
       /  \
      / E2E\        (Future: Selenium/Capybara)
     /------\
    / Integr.\      (API tests with rack-test)
   /----------\
  /   Unit     \    (Domain logic, use cases)
 /--------------\
```

### Unit Tests

**Domain Logic:**
- Credit scoring calculations
- State transitions
- Validation rules

**State Transitions:**
- User onboarding steps
- Auction lifecycle
- Settlement workflow

### Integration Tests

**API Testing with rack-test:**
- HTTP request/response
- Session management
- Authorization checks
- Error handling

### Test Database

**Isolation:**
- Separate test database
- Dropped before each test
- Indexes recreated

---

## Monitoring & Observability

### Current Implementation

**Health Check:**
```ruby
get "/api/health" do
  json status: "ok", db: (Basic4::DB.client.database.command(ping: 1).ok? ? "up" : "down")
rescue => e
  status 503
  json status: "degraded", error: e.message
end
```

**Logging:**
- Puma request logs (stdout)
- Application errors (stdout/stderr)
- Token notifications (stdout)

### Future Enhancements

**Metrics:**
- Request latency (Puma stats)
- Database query times
- Error rates
- Active users

**Structured Logging:**
- JSON-formatted logs
- Correlation IDs
- Request tracing

**APM Integration:**
- New Relic or Datadog for distributed tracing
- Error tracking (Sentry)
- Performance monitoring

---

## Deployment Checklist

### Pre-Deployment

- Set secure session secret (64+ chars)
- Configure production MongoDB (replica set)
- Configure production MinIO/S3 (with proper credentials)
- Set production environment
- Enable HTTPS (reverse proxy or load balancer)
- Configure log aggregation
- Set up monitoring and alerting
- Create admin account via CLI

### Post-Deployment

- Verify health check endpoint
- Test user registration flow
- Test auction lifecycle
- Test settlement flow
- Verify email notifications (if SMTP configured)
- Check database indexes
- Monitor error rates
- Set up backups

---

## Future Architecture Enhancements

### Short-Term (v1.1)

1. **Email Integration:** SMTP notifier for verification/reset emails
2. **HTTPS:** Reverse proxy with Let's Encrypt
3. **Rate Limiting:** Rack middleware for API protection
4. **Audit Logging:** Track critical operations (settlements, admin actions)

### Medium-Term (v1.2)

1. **Real-time Updates:** WebSockets for bid notifications
2. **Search:** Full-text search for auctions (MongoDB Atlas Search)
3. **Analytics:** Dashboard for sellers (auction performance)
4. **Mobile App:** React Native or Flutter

### Long-Term (v2.0)

1. **Microservices:** Split into separate services (auth, auctions, settlements)
2. **Event Sourcing:** Track all state changes as events
3. **Payment Integration:** Stripe or PayPal for escrow
4. **Recommendations:** ML-based auction suggestions
5. **Multi-tenancy:** Support multiple auction houses

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-09 | System | Initial architecture document |

---

**End of Architecture Document**
