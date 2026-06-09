# Requirements Document — Basic4 Auction Platform

**Version:** 1.0  
**Date:** 2026-06-09  
**Status:** Active

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Functional Requirements](#functional-requirements)
3. [Non-Functional Requirements](#non-functional-requirements)
4. [User Roles & Permissions](#user-roles--permissions)
5. [Business Rules](#business-rules)
6. [Acceptance Criteria](#acceptance-criteria)

---

## Executive Summary

Basic4 is a peer-to-peer auction platform with escrow-based settlement. The system supports three user roles (Buyer, Seller, Admin) and manages the complete lifecycle of product auctions from listing through settlement and payment.

**Core Value Proposition:**
- Secure user onboarding with email verification and credit scoring
- Transparent auction process with real-time bidding
- Admin-managed escrow settlement to protect both buyers and sellers
- Simple, intuitive interface for all user types

---

## Functional Requirements

### FR-1: User Management

#### FR-1.1: Registration & Authentication

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1.1 | Users MUST register with email, password (min 8 chars), and name | High |
| FR-1.1.2 | Email addresses MUST be unique across the system | High |
| FR-1.1.3 | Passwords MUST be hashed using bcrypt before storage | High |
| FR-1.1.4 | New users MUST receive a 6-digit email verification token | High |
| FR-1.1.5 | Verification tokens MUST expire after 15 minutes | High |
| FR-1.1.6 | Users MUST be able to request password reset via email token | High |
| FR-1.1.7 | Password reset tokens MUST expire after 1 hour | High |
| FR-1.1.8 | System MUST NOT reveal whether email exists during password reset (security) | High |

#### FR-1.2: User Roles

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.2.1 | System MUST support three roles: Buyer, Seller, Admin | High |
| FR-1.2.2 | All new registrations MUST start as Buyer role | High |
| FR-1.2.3 | Buyers MUST complete onboarding (email verification + shipping address) before bidding | High |
| FR-1.2.4 | Buyers MUST be able to upgrade to Seller via credit scoring | High |
| FR-1.2.5 | Admin users MUST be created via CLI tool, not registration | High |
| FR-1.2.6 | Admin users MUST have pre-verified emails | High |

#### FR-1.3: Buyer Onboarding

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.3.1 | Buyers MUST complete 3-step onboarding: signup → verify email → shipping address | High |
| FR-1.3.2 | System MUST enforce step sequence (cannot skip steps) | High |
| FR-1.3.3 | Shipping address MUST include: line1, line2 (optional), city, region, postal_code, country | High |
| FR-1.3.4 | All required address fields MUST be validated as non-empty | High |
| FR-1.3.5 | Users MUST be able to resend verification token | Medium |

#### FR-1.4: Seller Credit Scoring

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.4.1 | Buyers MUST submit credit score application to become Sellers | High |
| FR-1.4.2 | Credit score inputs: annual income, employment status, existing debt, years of credit history | High |
| FR-1.4.3 | Employment status MUST be one of: employed, self_employed, student, unemployed | High |
| FR-1.4.4 | Credit score MUST be calculated using deterministic formula (300-850 range) | High |
| FR-1.4.5 | Admin MUST approve or reject seller applications | High |
| FR-1.4.6 | Rejected applicants MUST remain as Buyers | High |

**Credit Score Formula:**
```
base_score = 500
income_points = min(income / 1000, 150)
employment_bonus = {employed: +50, self_employed: +30, student: 0, unemployed: -50}
history_points = min(years * 5, 75)
dti_penalty = if (debt/income > 0.5) then -100 else if (debt/income > 0.3) then -50 else 0
final_score = clamp(base + income + employment + history + dti, 300, 850)
```

#### FR-1.5: Profile Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.5.1 | Users MUST be able to update their name | Medium |
| FR-1.5.2 | Users MUST be able to update their email (requires re-verification) | Medium |
| FR-1.5.3 | Users MUST be able to change their password | Medium |
| FR-1.5.4 | Email/password changes MUST require current password verification | High |
| FR-1.5.5 | Email changes MUST trigger new verification token | High |

---

### FR-2: Product Auction Management

#### FR-2.1: Auction Lifecycle

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1.1 | Sellers MUST be able to create auction listings | High |
| FR-2.1.2 | New auctions MUST start in PENDING_APPROVAL status | High |
| FR-2.1.3 | Admin MUST be able to approve pending products (PENDING_APPROVAL → DRAFT) | High |
| FR-2.1.4 | Admin MUST be able to reject pending products with a reason (PENDING_APPROVAL → REJECTED) | High |
| FR-2.1.5 | Sellers MUST be able to edit products in PENDING_APPROVAL, DRAFT, or REJECTED status | High |
| FR-2.1.6 | Editing a REJECTED product MUST resubmit it to PENDING_APPROVAL for re-review | High |
| FR-2.1.7 | Sellers MUST be able to start approved auctions (DRAFT → LIVE) | High |
| FR-2.1.8 | Sellers MUST be able to stop auctions (LIVE → ENDED) | High |
| FR-2.1.9 | Admin MUST be able to complete auctions via settlement (ENDED → COMPLETED) | High |
| FR-2.1.10 | LIVE auctions MUST NOT be editable | High |
| FR-2.1.11 | ENDED/COMPLETED auctions MUST NOT be editable or startable | High |

**Auction Status Transitions:**
```
PENDING_APPROVAL --[Admin approves]--> DRAFT ──[Seller starts]──> LIVE ──[Seller stops]──> ENDED ──[Admin completes]──> COMPLETED
PENDING_APPROVAL --[Admin rejects]--> REJECTED --[Seller edits]--> PENDING_APPROVAL
```

#### FR-2.2: Auction Listing Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.2.1 | Auctions MUST have: title (max 120 chars), description, category, starting price, duration | High |
| FR-2.2.2 | Categories MUST be: electronics, collectibles, fashion, home, toys, other | High |
| FR-2.2.3 | Starting price MUST be >= $0.01 (1 cent) | High |
| FR-2.2.4 | Duration MUST be between 1 and 30 days | High |
| FR-2.2.5 | Auctions MUST support up to 3 images | Medium |
| FR-2.2.6 | Images MUST be stored in object storage (MinIO/S3) | High |
| FR-2.2.7 | Images MUST be limited to JPEG, PNG, WebP, GIF formats | High |
| FR-2.2.8 | Individual images MUST be limited to 5MB | Medium |

#### FR-2.3: Auction Visibility

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.3.1 | Approved products and LIVE auctions MUST be visible on public browse page | High |
| FR-2.3.2 | PENDING_APPROVAL products MUST NOT appear on public browse | High |
| FR-2.3.3 | REJECTED products MUST NOT appear on public browse | High |
| FR-2.3.4 | DRAFT (approved) auctions MUST be tagged as "draft" on seller dashboard | Medium |
| FR-2.3.5 | LIVE auctions MUST be tagged as "live" on browse | High |
| FR-2.3.6 | ENDED auctions MUST be tagged as "ended" on browse | High |
| FR-2.3.7 | COMPLETED auctions MUST be tagged as "completed" on browse | High |
| FR-2.3.8 | Sellers MUST see their own auctions on dashboard with status badges | High |
| FR-2.3.9 | Admin MUST see only ENDED/COMPLETED and PENDING_APPROVAL auctions | High |

---

### FR-3: Bidding System

#### FR-3.1: Bid Placement

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1.1 | Only authenticated users MUST be able to place bids | High |
| FR-3.1.2 | Bids MUST only be allowed on LIVE auctions | High |
| FR-3.1.3 | Bids MUST only be allowed before auction ends_at time | High |
| FR-3.1.4 | Sellers MUST NOT be able to bid on their own auctions | High |
| FR-3.1.5 | First bid MUST be >= starting_price_cents | High |
| FR-3.1.6 | Subsequent bids MUST strictly exceed current_bid_cents | High |
| FR-3.1.7 | Bid amounts MUST be positive integers (cents) | High |

#### FR-3.2: Bid History

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.2.1 | All bids MUST be recorded in bid history | High |
| FR-3.2.2 | Bid history MUST be sorted newest-first | High |
| FR-3.2.3 | Bidder names MUST be displayed in bid history | High |
| FR-3.2.4 | Current user's bids MUST be shown as "You" | Medium |
| FR-3.2.5 | Bidder name MUST be snapshot at bid time (not live reference) | Medium |

#### FR-3.3: Bid Denormalization

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.3.1 | Product document MUST store current_bid_cents | High |
| FR-3.3.2 | Product document MUST store highest_bidder_id | High |
| FR-3.3.3 | Product document MUST store bid_count | High |

---

### FR-4: Settlement System

#### FR-4.1: Settlement Lifecycle

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1.1 | Only Admin MUST be able to manage settlements | High |
| FR-4.1.2 | Settlements MUST only be created for ENDED auctions with winning bids | High |
| FR-4.1.3 | Settlement MUST start in INVOICED status | High |
| FR-4.1.4 | Settlement status MUST progress: INVOICED → PAID → SHIPPED → COMPLETED | High |
| FR-4.1.5 | Each status transition MUST be enforced sequentially | High |
| FR-4.1.6 | Completing settlement MUST mark auction as COMPLETED | High |

**Settlement Status Transitions:**
```
INVOICED --[Admin records payment]--> PAID --[Admin records shipment]--> SHIPPED --[Admin releases funds]--> COMPLETED
```

#### FR-4.2: Settlement Data

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.2.1 | Settlement MUST snapshot winning bid amount at creation time | High |
| FR-4.2.2 | Settlement MUST snapshot winner's shipping address at creation time | High |
| FR-4.2.3 | Settlement MUST record seller_id and buyer_id | High |
| FR-4.2.4 | Settlement MUST record timestamps for each status transition | High |
| FR-4.2.5 | Only one settlement MUST exist per auction | High |

#### FR-4.3: Settlement Queue

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.3.1 | Admin MUST see settlement queue of all ENDED auctions with winners | High |
| FR-4.3.2 | Settlement queue MUST show current settlement status | High |
| FR-4.3.3 | Settlement queue MUST show winner information | High |

#### FR-4.4: Admin Auction Detail

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.4.1 | Admin MUST see full auction details | High |
| FR-4.4.2 | Admin MUST see seller identity (name, email) | High |
| FR-4.4.3 | Admin MUST see winner identity (name, email, shipping address) | High |
| FR-4.4.4 | Admin MUST see complete bid history | High |
| FR-4.4.5 | Admin MUST see settlement status and actions | High |

---

### FR-5: User Interface

#### FR-5.1: Public Pages

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1.1 | Home page MUST redirect to browse page | High |
| FR-5.1.2 | Browse page MUST display all auctions in card grid | High |
| FR-5.1.3 | Browse page MUST be accessible without authentication | High |
| FR-5.1.4 | Auction cards MUST show: image, category, status, title, description, price, bid count | High |
| FR-5.1.5 | Auction detail page MUST show full description, images, bid history | High |
| FR-5.1.6 | Auction detail page MUST show bidding interface for LIVE auctions | High |

#### FR-5.2: Authenticated Pages

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.2.1 | Login page MUST support email/password authentication | High |
| FR-5.2.2 | Signup page MUST collect name, email, password | High |
| FR-5.2.3 | Dashboard MUST show user profile information | High |
| FR-5.2.4 | Dashboard MUST show "My Auctions" for Sellers | High |
| FR-5.2.5 | Dashboard MUST provide "Become a Seller" option for Buyers | High |
| FR-5.2.6 | Profile edit page MUST allow name, email, password changes | Medium |

#### FR-5.3: Admin Console

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.3.1 | Admin console MUST have four tabs: Closed Auctions, Settlements, Seller Applications, Pending Products | High |
| FR-5.3.2 | Closed Auctions tab MUST show all ENDED/COMPLETED auctions | High |
| FR-5.3.3 | Settlements tab MUST show settlement queue with action buttons | High |
| FR-5.3.4 | Seller Applications tab MUST show pending applications with approve/reject buttons | High |
| FR-5.3.5 | Pending Products tab MUST show products awaiting admin approval with approve/reject actions | High |
| FR-5.3.6 | Admin MUST be redirected to /admin after login | High |

---

### FR-6: Notifications

#### FR-6.1: In-App Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-6.1.1 | System MUST create a notification when a seller lists a product (to all admins) | High |
| FR-6.1.2 | System MUST create a notification when an admin approves a product (to the seller) | High |
| FR-6.1.3 | System MUST create a notification when an admin rejects a product (to the seller) | High |
| FR-6.1.4 | Notifications MUST be stored in the database `notifications` collection | High |
| FR-6.1.5 | Each notification MUST have: user_id, type, title, body, related_id, read status, timestamps | High |
| FR-6.1.6 | Users MUST be able to list their own notifications | High |
| FR-6.1.7 | Users MUST be able to mark a notification as read | High |
| FR-6.1.8 | Users MUST see an unread notification count | High |
| FR-6.1.9 | Notification bell MUST display unread badge on dashboard header | High |
| FR-6.1.10 | Frontend MUST poll for new notifications every 30 seconds | Medium |
| FR-6.1.11 | Notifications MUST also be logged to stdout for backwards compatibility | Medium |

#### Notification Types

| Type | Trigger | Recipient | Content |
|------|---------|-----------|---------|
| `product_pending_approval` | Seller creates product | All admins | "{seller} listed '{product}' for review" |
| `product_approved` | Admin approves | Product seller | "Your product '{product}' has been approved" |
| `product_rejected` | Admin rejects | Product seller | "Your product '{product}' was not approved. Reason: {reason}" |

---

## Non-Functional Requirements

### NFR-1: Performance

| ID | Requirement | Target | Priority |
|----|-------------|--------|----------|
| NFR-1.1 | Page load time (browse page) | < 2 seconds | High |
| NFR-1.2 | API response time (95th percentile) | < 500ms | High |
| NFR-1.3 | Bid placement response time | < 300ms | High |
| NFR-1.4 | Support concurrent users | 100+ users | Medium |
| NFR-1.5 | Database queries per request | < 10 queries | Medium |

### NFR-2: Security

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-2.1 | Passwords MUST be hashed with bcrypt | High |
| NFR-2.2 | Sessions MUST use secure, signed cookies | High |
| NFR-2.3 | Session secret MUST be >= 64 characters | High |
| NFR-2.4 | Password reset MUST NOT reveal email existence | High |
| NFR-2.5 | Auction ownership MUST NOT be probed (collapsed error messages) | High |
| NFR-2.6 | Email/password changes MUST require current password | High |
| NFR-2.7 | All user inputs MUST be validated and sanitized | High |
| NFR-2.8 | HTTPS MUST be used in production | High |

### NFR-3: Reliability & Availability

| ID | Requirement | Target | Priority |
|----|-------------|--------|----------|
| NFR-3.1 | System uptime | 99.5% | Medium |
| NFR-3.2 | Data durability | No data loss | High |
| NFR-3.3 | Backup frequency | Daily | Medium |
| NFR-3.4 | Recovery time objective (RTO) | < 4 hours | Medium |
| NFR-3.5 | Recovery point objective (RPO) | < 1 hour | Medium |

### NFR-4: Scalability

| ID | Requirement | Target | Priority |
|----|-------------|--------|----------|
| NFR-4.1 | Horizontal scaling support | Yes | Low |
| NFR-4.2 | Stateless application design | Yes | Medium |
| NFR-4.3 | Database connection pooling | Yes | Medium |
| NFR-4.4 | Object storage scaling | Unlimited | Medium |

### NFR-5: Maintainability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-5.1 | Code MUST follow hexagonal architecture pattern | High |
| NFR-5.2 | Domain logic MUST be separate from infrastructure | High |
| NFR-5.3 | All use cases MUST be unit testable | High |
| NFR-5.4 | Test coverage MUST be > 80% | Medium |
| NFR-5.5 | Code MUST be documented with inline comments | Medium |

### NFR-6: Usability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-6.1 | Interface MUST be responsive (mobile-friendly) | High |
| NFR-6.2 | Error messages MUST be clear and actionable | High |
| NFR-6.3 | Form validation MUST provide immediate feedback | High |
| NFR-6.4 | Auction status MUST be clearly visible | High |
| NFR-6.5 | Bid history MUST be easy to read | Medium |

### NFR-7: Compatibility

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-7.1 | Support modern browsers (Chrome, Firefox, Safari, Edge) | High |
| NFR-7.2 | Support Ruby 4.0.5+ | High |
| NFR-7.3 | Support JRuby 10.0.5.0+ | Medium |
| NFR-7.4 | Support MongoDB 7+ | High |
| NFR-7.5 | Support MinIO/S3-compatible storage | High |

---

## User Roles & Permissions

### Permission Matrix

| Feature | Guest | Buyer | Seller | Admin |
|---------|-------|-------|--------|-------|
| Browse auctions | ✅ | ✅ | ✅ | ❌ (only closed) |
| View auction details | ✅ | ✅ | ✅ | ✅ (closed only) |
| Register account | ✅ | ❌ | ❌ | ❌ |
| Login/Logout | ✅ | ✅ | ✅ | ✅ |
| Complete onboarding | ❌ | ✅ | ❌ | ❌ |
| Place bids | ❌ | ✅ | ✅ | ❌ |
| Create auctions | ❌ | ❌ | ✅ | ❌ |
| Edit draft auctions | ❌ | ❌ | ✅ (own) | ❌ |
| Start auctions | ❌ | ❌ | ✅ (own) | ❌ |
| Stop auctions | ❌ | ❌ | ✅ (own) | ❌ |
| View own auctions | ❌ | ❌ | ✅ | ❌ |
| Become seller | ❌ | ✅ | ❌ | ❌ |
| Edit profile | ❌ | ✅ | ✅ | ✅ |
| View closed auctions | ❌ | ❌ | ❌ | ✅ |
| Manage settlements | ❌ | ❌ | ❌ | ✅ |
| Approve/reject sellers | ❌ | ❌ | ❌ | ✅ |
| View seller/winner PII | ❌ | ❌ | ❌ | ✅ |

### Role-Specific Dashboards

**Buyer Dashboard:**
- Profile information
- "Become a Seller" button
- Browse auctions link
- Edit profile link

**Seller Dashboard:**
- Profile information + credit score
- "My Auctions" list with action buttons
- "Sell a Product" button
- Browse auctions link
- Edit profile link

**Admin Dashboard:**
- Profile information
- Admin console link (/admin)
- Browse auctions link
- Edit profile link

---

## Business Rules

### BR-1: Auction Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-1.1 | Auctions MUST be manually started by seller | Prevents premature bidding |
| BR-1.2 | Auctions MUST be manually stopped by seller | Gives seller control over timing |
| BR-1.3 | No automatic auction closure at ends_at | Simplifies system, manual control preferred |
| BR-1.4 | Sellers CANNOT bid on own auctions | Prevents price manipulation |
| BR-1.5 | Bids MUST exceed current highest bid | Ensures competitive bidding |
| BR-1.6 | Only one settlement per auction | Prevents double-payment issues |

### BR-2: User Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-2.1 | All new users start as Buyers | Controlled seller onboarding |
| BR-2.2 | Email MUST be verified before bidding | Reduces fraud |
| BR-2.3 | Shipping address REQUIRED for buyers | Needed for settlement |
| BR-2.4 | Credit score REQUIRED for sellers | Assesses seller reliability |
| BR-2.5 | Admin accounts created via CLI only | Security control |

### BR-3: Settlement Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-3.1 | Settlement only for auctions with winners | No winner = no transaction |
| BR-3.2 | Settlement snapshots data at creation | Prevents post-hoc changes |
| BR-3.3 | Sequential status transitions required | Enforces proper workflow |
| BR-3.4 | Completing settlement completes auction | Links settlement to auction lifecycle |
| BR-3.5 | Only Admin can manage settlements | Escrow model for trust |

---

## Acceptance Criteria

### AC-1: User Onboarding Flow

**Scenario: Complete buyer onboarding**
```
GIVEN a new user visits the site
WHEN they register with valid credentials
AND verify their email with the 6-digit token
AND provide a complete shipping address
THEN they become a Buyer with step="done"
AND can place bids on live auctions
```

### AC-2: Seller Upgrade Flow

**Scenario: Buyer becomes Seller**
```
GIVEN a Buyer with step="done"
WHEN they click "Become a Seller"
AND submit credit scoring information
AND Admin approves the application
THEN they become a Seller
AND can create auction listings
```

### AC-3: Auction Lifecycle Flow

**Scenario: Complete auction lifecycle**
```
GIVEN a Seller with an auction in DRAFT status
WHEN they start the auction
THEN status becomes LIVE and bidding opens
WHEN bids are placed by Buyers
THEN bid history is updated and current_bid increases
WHEN Seller stops the auction
THEN status becomes ENDED and bidding closes
WHEN Admin creates settlement and completes it
THEN status becomes COMPLETED
```

### AC-4: Settlement Flow

**Scenario: Complete settlement process**
```
GIVEN an ENDED auction with a winning bid
WHEN Admin creates settlement
THEN settlement status is INVOICED with snapshotted data
WHEN Admin records payment
THEN settlement status is PAID
WHEN Admin records shipment
THEN settlement status is SHIPPED
WHEN Admin releases funds
THEN settlement status is COMPLETED
AND auction status becomes COMPLETED
```

### AC-5: Security Scenarios

**Scenario: Password reset security**
```
GIVEN a user requests password reset for email "user@example.com"
WHEN the email does not exist in the system
THEN the API returns success (200 OK)
AND no token is generated
AND the response is identical to existing email case
```

**Scenario: Auction ownership protection**
```
GIVEN Seller A owns auction with id="123"
WHEN Seller B tries to edit auction "123"
THEN the API returns 422 "listing not found"
AND does NOT reveal that the auction exists
```

---

## Future Requirements (Out of Scope for v1.0)

### FR-FUTURE-1: Email Notifications
- Email notifications for approval status changes
- Email notifications for bid updates
- Email notifications for auction status changes
- Email notifications for settlement progress

### FR-FUTURE-2: Advanced Features
- Automatic auction closure at ends_at
- Watchlist functionality
- Auction search and filtering
- Categories with subcategories
- Auction recommendations

### FR-FUTURE-3: Payment Integration
- Direct payment processing
- Escrow account management
- Automatic fund transfers
- Transaction history

### FR-FUTURE-4: Analytics
- Seller performance metrics
- Auction success rates
- Bid activity analytics
- Revenue reporting

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-09 | System | Initial requirements document |

---

**End of Requirements Document**
