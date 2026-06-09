# AUCTIONS.md — Complete User Journey Map

> **Project:** Basic4 — Auction & Escrow Platform
> **Architecture:** Ruby/Sinatra + MongoDB + Vue.js 3 SPA + MinIO (S3) + Hexagonal/Modular Monolith
> **Roles:** `guest` → `buyer` → `seller` | `admin` (back-office)

This document maps every feature in the system as a **user journey**, organized by actor. No feature is omitted — every API endpoint, UI screen, business rule, and state transition is represented.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Guest Journey](#2-guest-journey)
3. [Buyer Journey](#3-buyer-journey)
4. [Seller Journey](#4-seller-journey)
5. [Admin Journey](#5-admin-journey)
6. [Auction Lifecycle](#6-auction-lifecycle)
7. [Settlement Lifecycle](#7-settlement-lifecycle)
8. [Bidding Journey](#8-bidding-journey)
9. [Account Management Journey](#9-account-management-journey)
10. [Technical Architecture Summary](#10-technical-architecture-summary)

---

## 1. System Overview

### 1.1 Three Actor Types

| Actor | Role | What They Can Do |
|-------|------|-----------------|
| **Guest** | Unauthenticated visitor | Browse catalog, check email availability, sign up, log in, reset password |
| **Buyer** | Authenticated user with `role: "buyer"` | Everything a guest can do + bid on live auctions, save shipping address, upgrade to seller |
| **Seller** | Authenticated user with `role: "seller"` | Everything a buyer can do + create/edit/start/stop auctions, manage listings |
| **Admin** | Authenticated user with `role: "admin"` | View closed auctions, manage settlements, approve/reject seller applications |

### 1.2 Onboarding Flow

```
Guest ──► Signup ──► Verify Email ──► Shipping Address ──► Buyer (done)
                                                          │
                                                          ▼
                                              Become Seller ──► Credit Scoring ──► Seller (done)
```

### 1.3 Auction Lifecycle

```
Draft ──► [Seller Start] ──► Live ──► [Seller Stop] ──► Ended ──► [Admin Settlement] ──► Completed
   │                          │                           │
   │ [Edit]                   │ [Bid]                   │ [Invoice Winner]
   │                          │ [View Detail]             │ [Record Payment]
   │                          │ [Bid History]             │ [Record Shipment]
   │                          │                           │ [Release Funds]
```

### 1.4 Settlement Lifecycle

```
Ended ──► [Invoice] ──► Invoiced ──► [Payment] ──► Paid ──► [Shipment] ──► Shipped ──► [Complete] ──► Completed
```

---

## 2. Guest Journey

### 2.1 Landing on the Storefront

1. **Guest visits `/` (home)** → Redirected to public storefront `/browse`
2. **Sees public catalog** — all auctions across all sellers (draft / live / ended / completed), sorted newest-first
3. **Each card shows:** thumbnail image, category badge, status badge, title, description, current price (or starting price), bid count
4. **Can click into any auction** for detail view with full description, images, and bid history
5. **Header shows:** "Sign in / Sell →" link to `/app`

### 2.2 Checking Email Availability (Pre-Signup)

1. **Guest enters email** on signup form or uses "Check existing" feature
2. **Frontend calls** `POST /api/check-existing` with `{ email }`
3. **Backend validates** email format against regex
4. **Returns** `{ exists: true|false }` — no account leakage, just boolean
5. **Purpose:** Prevents duplicate registration attempts, smooth UX

### 2.3 Signing Up

1. **Guest navigates to `/app`** → sees Signup Screen (Step 1 of 3)
2. **Form fields:** Name, Email, Password (min 8 chars)
3. **Frontend calls** `POST /api/signup` with `{ email, password, name }`
4. **Backend validates:**
   - Email format valid
   - Password ≥ 8 characters
   - Name not empty
   - Email not already registered (unique index on MongoDB)
5. **Backend creates user:**
   - `role: "buyer"`
   - `step: "verify_email"`
   - `email_verification` with 6-digit token + 15-minute TTL
   - Bcrypt-hashed password
   - UUID as user ID
6. **Backend notifies:** Token logged to stdout (`StdoutNotifier`) — no SMTP yet
7. **Backend establishes session** via Sinatra session cookie
8. **Frontend advances** to Verify Email Screen (Step 2 of 3)
9. **Event emitted:** `UserSignedUp`

### 2.4 Logging In

1. **Guest navigates to `/app`** → switches to Login Screen
2. **Form fields:** Email, Password
3. **Frontend calls** `POST /api/login` with `{ email, password }`
4. **Backend validates:**
   - Finds user by email
   - Verifies password with BCrypt
   - Returns generic "invalid email or password" on failure (no leakage)
5. **Backend establishes session**
6. **Frontend fetches user state** via `GET /api/me`
7. **Renders appropriate screen** based on `user.step`:
   - `verify_email` → Verify Email Screen
   - `shipping_address` → Shipping Address Screen
   - `done` → Dashboard Screen
   - `credit_scoring` → Credit Scoring Screen
8. **Event emitted:** `UserAuthenticated`
9. **If admin:** Auto-redirects to `/admin` console

### 2.5 Password Reset

#### 2.5.1 Requesting a Reset

1. **Guest clicks "Forgot password?"** on Login Screen
2. **Switches to Password Forgot Screen**
3. **Form field:** Email
4. **Frontend calls** `POST /api/password/forgot` with `{ email }`
5. **Backend behavior:**
   - Validates email format
   - Finds user by email (silently returns 200 even if not found — no leakage)
   - Generates random password reset token (16-char alphanumeric)
   - Sets 1-hour TTL on token
   - Logs token to stdout
   - Stores updated user
6. **Frontend shows info:** "If an account exists, a reset token has been issued. Check server logs."
7. **Event emitted:** `PasswordResetRequested`

#### 2.5.2 Resetting with Token

1. **Guest clicks "I already have a token"** or receives link with `?reset=<token>`
2. **Switches to Password Reset Screen**
3. **Form fields:** Reset token (auto-filled from URL), New password (min 8 chars)
4. **Frontend calls** `POST /api/password/reset` with `{ token, new_password }`
5. **Backend validates:**
   - Token not empty
   - New password ≥ 8 chars
   - Finds user by token
   - Checks token not expired
   - Hashes new password with BCrypt
   - Clears password reset token
6. **Frontend shows success** and redirects to Login Screen
7. **Event emitted:** `PasswordResetCompleted`

---

## 3. Buyer Journey

### 3.1 Buyer Onboarding

#### 3.1.1 Step 1: Signup (already covered in Guest Journey)

#### 3.1.2 Step 2: Verify Email

1. **Buyer sees Verify Email Screen** with their email displayed
2. **Backend sent 6-digit token** (logged to stdout) with 15-minute TTL
3. **Buyer can resend token:**
   - Click "Resend" → Frontend calls `POST /api/onboarding/resend-token`
   - Backend generates new 6-digit token, resets TTL to 15 minutes
   - Logs new token to stdout
   - Event emitted: `VerificationTokenResent`
4. **Buyer enters 6-digit code** and submits
5. **Frontend calls** `POST /api/onboarding/verify-email` with `{ token }`
6. **Backend validates:**
   - User is at `verify_email` step
   - Token matches stored token
   - Token not expired
   - Marks email as verified
   - Advances `step` to `shipping_address`
7. **Frontend advances** to Shipping Address Screen (Step 3 of 3)
8. **Event emitted:** `EmailVerified`

#### 3.1.3 Step 3: Shipping Address

1. **Buyer sees Shipping Address Screen**
2. **Form fields:**
   - Address line 1 (required)
   - Address line 2 (optional)
   - City (required)
   - State/region (required)
   - ZIP/postal code (required)
   - Country (required, default "US")
3. **Frontend calls** `POST /api/onboarding/shipping-address` with `{ line1, line2?, city, region, postal_code, country }`
4. **Backend validates:** All required fields present and non-empty
5. **Backend stores** `ShippingAddress` value object on user
6. **Backend advances** `step` to `done`
7. **Buyer is now "done"** — full buyer status achieved
8. **Frontend shows Dashboard Screen**
9. **Event emitted:** `ShippingAddressSaved`

### 3.2 Browsing Auctions as Buyer

1. **Buyer visits `/browse`** or clicks "Browse all auctions" from dashboard
2. **Sees product grid** — all listings from all sellers, newest-first
3. **Each card shows:**
   - First image (or "No photo" placeholder)
   - Category badge
   - Status badge: `draft`, `live`, `ended`, `completed`
   - Title (max 120 chars)
   - Description
   - Current price or starting price
   - Bid count
   - "View & bid →" link
4. **Can click any auction** for detail view
5. **Detail view shows:**
   - Full image gallery
   - Category + status badges
   - Title + full description
   - Current bid / starting price + bid count
   - **Bid history** (newest-first, bidder names shown — own bids shown as "You")
   - **Bidding interface** (if live and not expired)

### 3.3 Placing a Bid

1. **Buyer opens auction detail** for a live auction
2. **Sees bidding interface** (if signed in, not their own listing, auction is live)
3. **Enters bid amount** — input masks as currency (e.g., "$50.00" = 5000 cents)
4. **Clicks "Place bid"**
5. **Frontend calls** `POST /api/products/:id/bid` with `{ amount_cents }`
6. **Backend validates:**
   - Auction is `live`
   - Current time is before `ends_at` (informational deadline)
   - Bidder is NOT the seller (can't bid on own listing)
   - Amount is a positive integer
   - First bid must be ≥ `starting_price_cents`
   - Later bids must strictly exceed `current_bid_cents`
7. **Backend updates product:**
   - `current_bid_cents` = new amount
   - `highest_bidder_id` = bidder ID
   - `bid_count` += 1
8. **Backend records bid** in `bids` collection:
   - Bid ID (UUID)
   - Product ID
   - Bidder ID
   - Bidder name (snapshot, not live reference)
   - Amount in cents
   - Timestamp
9. **Frontend refreshes** detail view with updated product + bid history
10. **Event emitted:** (implicit via bid history update)

### 3.4 Becoming a Seller (Upgrade)

1. **Buyer at `done` step** sees "Become a seller" button on dashboard
2. **Clicks button**
3. **Frontend calls** `POST /api/onboarding/become-seller`
4. **Backend validates:**
   - User is at `done` step
   - User is not already a seller
   - Advances `step` to `credit_scoring`
   - Keeps `role` as `buyer` (not yet approved)
5. **Frontend shows Credit Scoring Screen**
6. **Event emitted:** `SellerApplicationStarted`

### 3.5 Credit Scoring

1. **Buyer sees Credit Scoring Screen**
2. **Form fields:**
   - Annual income (USD, number)
   - Employment status (select: employed, self_employed, student, unemployed)
   - Existing debt (USD, number)
   - Years of credit history (integer)
3. **Frontend calls** `POST /api/onboarding/credit-score` with `{ income, employment, debt, history_years }`
4. **Backend validates inputs:**
   - Income: non-negative number
   - Employment: must be one of 4 valid statuses
   - Debt: non-negative number
   - History years: non-negative integer
5. **Backend computes credit score** (pure deterministic formula):
   - Base: 500
   - + income/1000 (capped at +150)
   - + employment bonus: employed +50, self_employed +30, student 0, unemployed -50
   - + history_years × 5 (capped at +75)
   - - DTI penalty: debt/income > 0.5 → -100, 0.3..0.5 → -50, else 0
   - Clamped to [300, 850]
6. **Backend stores** `CreditScoreSnapshot` on user (score, inputs, timestamp)
7. **Backend flips `role` to `seller` and `step` to `done`**
8. **Frontend shows Dashboard** with seller features unlocked
9. **Event emitted:** `BecameSeller`

### 3.6 Viewing Profile

1. **Buyer at `done` step** sees Dashboard Screen
2. **Profile card shows:**
   - Name
   - Role (Buyer / Seller / Admin)
   - Email + verified badge
   - Credit score (if computed)
   - "Edit profile" button
   - "Sign out" button
   - "Browse all auctions" link

---

## 4. Seller Journey

### 4.1 Seller Dashboard

1. **Seller logs in** → Dashboard Screen shows seller-specific features:
   - "+ Sell a product at auction" button
   - "My auctions" list (sorted newest-first)
   - Each auction shows: thumbnail, title, status badge, price info, action buttons
2. **Auction statuses in dashboard:**
   - `pending_approval` → "Awaiting admin approval" + "Edit" link
   - `draft` → "Start" button + "Edit" link
   - `live` → current bid + bid count + "Stop" button
   - `ended` → "Sold for $X · Y bids" or "Ended — no bids"
   - `completed` → same as ended (settled)
   - `rejected` → "Rejected — {reason}" + "Edit & Resubmit" button
3. **Notification bell:**
   - Bell icon in top-right corner with unread badge
   - Shows count of unread notifications
   - Click to open dropdown panel (30-second polling refreshes count automatically)
   - Each notification: title, body, time ago, click to navigate to related product
   - Mark as read on click

### 4.2 Creating a Product Listing

1. **Seller clicks "+ Sell a product at auction"**
2. **Two-step wizard:**
   - **Step 1: Product details**
     - Title (max 120 chars, required)
     - Description (required)
     - Category (select: electronics, collectibles, fashion, home, toys, other)
     - Photos (optional, up to 3 images, multipart upload)
   - **Step 2: Auction terms**
     - Starting price (USD, min $0.01)
     - Duration (days, 1-30)
3. **Image upload flow:**
   - Seller selects file → Frontend calls `POST /api/products/images` (multipart)
   - Backend validates: content type (jpeg/png/webp/gif), size ≤ 5MB
   - Backend stores in MinIO (S3-compatible) under `products/{seller_id}/{uuid}.{ext}`
   - Backend returns public URL
   - Frontend shows thumbnail with remove button
   - Max 3 images enforced
4. **Seller clicks "Save draft"**
5. **Frontend calls** `POST /api/products` with full payload
6. **Backend validates:**
   - All required fields present
   - Category is valid
   - Starting price ≥ 1 cent
   - Duration in [1, 30] days
   - Images ≤ 3
   - Image URLs are valid strings
7. **Backend creates product** with `status: "pending_approval"`
8. **Backend fans out notifications** to all admin users (type: `product_pending_approval`)
9. **Backend logs to stdout** for backwards compatibility
10. **Frontend redirects to dashboard** with "Product submitted for admin review"
11. **Event emitted:** `ProductListedForAuction`

### 4.2.1 Product Pending Approval

1. **Seller sees product** in dashboard with "Awaiting admin approval" badge
2. **No "Start" or "Start Auction" button** — product is not yet approved
3. **Seller can still edit** the product while pending (same as editing a draft)
4. **Seller can see** the current status as `pending_approval`
5. **Product is NOT visible** on public browse page

### 4.2.2 Product Approved

1. **Admin reviews and approves** the product (see Admin Journey §5.7)
2. **Seller receives notification:** "Your product '{title}' has been approved" (type: `product_approved`)
3. **Product status changes** to `draft` (the standard "approved draft" state)
4. **Seller sees** "Approved — Ready to start" badge on dashboard
5. **Seller can now start** the auction as normal
6. **Product becomes visible** on public browse page

### 4.2.3 Product Rejected

1. **Admin reviews and rejects** the product with a reason (see Admin Journey §5.7)
2. **Seller receives notification:** "Your product '{title}' was not approved. Reason: {reason}" (type: `product_rejected`)
3. **Product status changes** to `rejected`
4. **Seller sees** "Rejected — {reason}" badge on dashboard
5. **Product is NOT visible** on public browse page

### 4.2.4 Editing a Rejected Product (Resubmission)

1. **Seller sees rejected product** on dashboard with the rejection reason displayed
2. **Seller clicks "Edit & Resubmit"** button
3. **Frontend opens Sell Product Screen** pre-filled with existing values, plus rejection reason
4. **Seller modifies fields** based on feedback and clicks "Save changes"
5. **Frontend calls** `PUT /api/products/:id` with updated payload
6. **Backend validates:**
   - Product exists and belongs to seller
   - Product is in `rejected` status
7. **Backend transitions:**
   - `status: "pending_approval"` (resubmitted for re-review)
   - Clears `rejection_reason`
   - Triggers admin notification again
8. **Frontend redirects to dashboard** with "Submitted for re-review"
9. **Admin sees product** back in Pending Products queue

### 4.3 Editing a Draft Auction

1. **Seller sees draft in dashboard** → clicks "Edit"
2. **Frontend opens Sell Product Screen** pre-filled with existing values
3. **Seller modifies fields** and clicks "Save changes"
4. **Frontend calls** `PUT /api/products/:id` with updated payload
5. **Backend validates:**
   - Product exists and belongs to seller (collapsed error — "listing not found")
   - Product is in `draft` status (live auctions cannot be edited)
   - Same field validations as create
6. **Backend updates product**
7. **Frontend redirects to dashboard** with "Auction updated"
8. **Event emitted:** `AuctionUpdated`

### 4.4 Starting an Auction

1. **Seller sees draft in dashboard** → clicks "Start"
2. **Frontend calls** `POST /api/products/:id/start`
3. **Backend validates:**
   - Product exists and belongs to seller
   - Product is in `draft` status
4. **Backend transitions:**
   - `status: "live"`
   - `started_at: now`
   - `ends_at: now + (duration_days × 86400 seconds)`
5. **Frontend refreshes dashboard** with updated status
6. **Event emitted:** `AuctionStarted`
7. **Auction is now live** — visible to all on `/browse`, open for bidding

### 4.5 Stopping an Auction

1. **Seller sees live auction in dashboard** → clicks "Stop"
2. **Frontend calls** `POST /api/products/:id/stop`
3. **Backend validates:**
   - Product exists and belongs to seller
   - Product is `live`
4. **Backend transitions:**
   - `status: "ended"`
   - `ended_at: now`
   - Bidding is now closed (future bids return 422)
5. **Frontend refreshes dashboard** with updated status
6. **Event emitted:** `AuctionStopped`
7. **Outcome visible:**
   - If bids existed: "Sold for $X to [winner]"
   - If no bids: "Ended — no bids"

### 4.6 Managing "My Auctions"

1. **Seller sees all their auctions** on dashboard
2. **Frontend loads** `GET /api/products/mine` on mount
3. **Backend returns** seller's auctions sorted newest-first
4. **Seller can:**
   - Start a draft
   - Edit a draft
   - Stop a live auction
   - View ended/completed outcomes

---

## 5. Admin Journey

### 5.1 Admin Account Creation

1. **Admin accounts are NOT created via signup** — they are bootstrapped out-of-band
2. **CLI tool:** `bin/create_admin` or `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/create_admin`
3. **Backend creates user with:**
   - `role: "admin"`
   - `step: "done"`
   - Pre-verified email
   - Bcrypt-hashed password
4. **Idempotent:** Re-running with existing email promotes that user to admin

### 5.2 Admin Login

1. **Admin navigates to `/app`** → Login Screen
2. **Enters credentials** → `POST /api/login`
3. **Backend authenticates** and returns user with `role: "admin"`
4. **Frontend detects admin role** → auto-redirects to `/admin`

### 5.3 Admin Console Overview

**Admin console (`/admin`) has four tabs:**

#### 5.3.1 Closed Auctions Tab

1. **Admin sees all `ended` and `completed` auctions** across all sellers
2. **Sorted by `ended_at` descending** (most recently closed first)
3. **Each card shows:** thumbnail, category, status badge, title, description, final price, bid count
4. **Click "View & settle →"** for detail view
5. **Backend:** `GET /api/admin/auctions` — requires `role == "admin"` (403 otherwise)

#### 5.3.2 Settlements Tab (Work Queue)

1. **Admin sees all ended auctions with a winner** that need settlement
2. **Each row shows:**
   - Product thumbnail + title
   - Final price + winner name
   - Settlement progress bar: `invoiced → paid → shipped → completed`
   - Action button (context-aware based on current state)
3. **Backend:** `GET /api/admin/settlements` — returns queue items
4. **Excludes auctions without a winner** (no settlement needed)

#### 5.3.3 Seller Applications Tab

1. **Admin sees all buyers** who completed credit scoring and await approval
2. **Each row shows:**
   - Applicant name + email
   - Credit score + submission date
   - "Approve" and "Reject" buttons
3. **Backend:** `GET /api/admin/seller-applications`

#### 5.3.4 Pending Products Tab

1. **Admin sees all products** in `pending_approval` status
2. **Sorted by `created_at` ASC** (oldest-first — FIFO queue)
3. **Each row shows:**
   - Product thumbnail
   - Title
   - Seller name
   - Starting price
   - Created date
   - "Approve" and "Reject" action buttons
4. **Approve flow:**
   - Admin clicks "Approve" → `POST /api/admin/products/:id/approve`
   - Product transitions to `draft` status
   - Seller receives `product_approved` notification
5. **Reject flow:**
   - Admin clicks "Reject" → modal asks for required reason
   - Admin enters reason → `POST /api/admin/products/:id/reject` with `{ reason: "..." }`
   - Product transitions to `rejected` status with reason stored
   - Seller receives `product_rejected` notification with reason
6. **Tab shows count badge** of pending items
7. **Page refreshes** after each approve/reject action
8. **Backend:** `GET /api/admin/pending-products` — requires `role == "admin"` (403 otherwise)

### 5.4 Admin Auction Detail View

1. **Admin opens a closed auction** from any tab
2. **Detail shows:**
   - Full product info (images, description, category, status)
   - Final price + bid count
   - **Seller identity card:** real name, email
   - **Winner identity card:** real name, email, shipping address
   - **Settlement section** with progress bar and action buttons
   - Full bid history (newest-first)
3. **Backend:** `GET /api/admin/auctions/:id` — returns:
   - `{ product, bids[], seller, winner, settlement }`

### 5.5 Approving/Rejecting Seller Applications

1. **Admin clicks "Approve"** on an applicant
2. **Frontend calls** `POST /api/admin/seller-applications/:id/approve`
3. **Backend validates:**
   - User exists and is at `credit_scoring` step
   - User has a credit score on file
   - Flips `role` to `seller` and `step` to `done`
4. **Frontend refreshes** applications list
5. **Reject flow:**
   - `POST /api/admin/seller-applications/:id/reject`
   - Reverts `role` to `buyer` and `step` to `done`
   - Keeps credit score on file for record

---

## 6. Auction Lifecycle

### 6.1 State Machine

```
                    ┌─────────────┐
                    │    DRAFT    │◄── [Create] ── Seller
                    └──────┬──────┘
                           │ [Start]
                           ▼
                    ┌─────────────┐
                    │    LIVE     │◄── [Bid] ── Any signed-in user (not seller)
                    └──────┬──────┘
                           │ [Stop]
                           ▼
                    ┌─────────────┐
                    │    ENDED    │◄── [Invoice] ── Admin
                    └──────┬──────┘
                           │ [Complete Settlement]
                           ▼
                    ┌─────────────┐
                    │  COMPLETED  │
                    └─────────────┘
```

### 6.2 State Rules

| State | Who Can Edit | Bidding Allowed | Visible To Admin | Visible To Public |
|-------|-------------|-----------------|------------------|-------------------|
| `draft` | Seller only | No | No | Yes (tagged "draft") |
| `live` | No one | Yes | No | Yes (tagged "live") |
| `ended` | No one | No | Yes | Yes (tagged "ended") |
| `completed` | No one | No | Yes | Yes (tagged "completed") |

### 6.3 Transitions

| Transition | Trigger | Guard |
|-----------|---------|-------|
| `draft` → `live` | Seller clicks "Start" | Must be seller, must own product, must be draft |
| `live` → `ended` | Seller clicks "Stop" | Must be seller, must own product, must be live |
| `ended` → `completed` | Admin completes settlement | Must be ended, must have settlement, settlement must be `shipped` |

### 6.4 Time Tracking

- `created_at` — when listing was created
- `started_at` — when auction went live
- `ends_at` — informational deadline (`started_at + duration_days`)
- `ended_at` — when auction was manually stopped
- No automatic closing at `ends_at` — seller must manually stop

---

## 7. Settlement Lifecycle

### 7.1 State Machine

```
[Ended auction with winner]
         │
         ▼ [Invoice Winner]
    ┌─────────┐
    │INVOICED │◄── Admin opens settlement, snapshots amount + shipping address
    └────┬────┘
         │ [Record Payment]
         ▼
    ┌─────────┐
    │  PAID   │◄── Admin records payment received
    └────┬────┘
         │ [Record Shipment]
         ▼
    ┌─────────┐
    │ SHIPPED │◄── Admin records item shipped
    └────┬────┘
         │ [Complete Settlement]
         ▼
    ┌─────────┐
    │COMPLETED│◄── Admin releases funds, auction marked completed
    └─────────┘
```

### 7.2 Settlement Actions

#### 7.2.1 Invoice Winner

1. **Admin opens ended auction** with a winning bid
2. **Clicks "Invoice winner"**
3. **Frontend calls** `POST /api/admin/products/:id/settlement`
4. **Backend validates:**
   - Auction is `ended`
   - Has a winning bid (`highest_bidder_id`)
   - Not already settled (one settlement per auction)
   - Winner exists and has shipping address
5. **Backend creates settlement:**
   - `status: "invoiced"`
   - `amount_cents` = final bid amount
   - `shipping_address` = snapshot of winner's address (immutable)
   - `seller_id`, `buyer_id` recorded
6. **Backend returns** settlement object
7. **Frontend shows** settlement progress bar at "invoiced"

#### 7.2.2 Record Payment

1. **Admin clicks "Mark payment received"**
2. **Frontend calls** `POST /api/admin/settlements/:id/payment`
3. **Backend validates:**
   - Settlement exists
   - Current status is `invoiced`
4. **Backend transitions:** `status: "paid"`, records `paid_at`
5. **Frontend updates** progress bar

#### 7.2.3 Record Shipment

1. **Admin clicks "Mark shipped"**
2. **Frontend calls** `POST /api/admin/settlements/:id/shipment`
3. **Backend validates:**
   - Settlement exists
   - Current status is `paid`
4. **Backend transitions:** `status: "shipped"`, records `shipped_at`
5. **Frontend updates** progress bar

#### 7.2.4 Complete Settlement

1. **Admin clicks "Release funds & complete"**
2. **Frontend calls** `POST /api/admin/settlements/:id/complete`
3. **Backend validates:**
   - Settlement exists
   - Current status is `shipped`
4. **Backend transitions:**
   - Settlement: `status: "completed"`, records `completed_at`
   - Auction: `status: "completed"` (mirrors settlement completion)
5. **Frontend updates** progress bar to complete
6. **Queue item removed** from active settlements

### 7.3 Settlement Guards

| Action | Required Status | Error If Violated |
|--------|----------------|-------------------|
| Invoice | `ended` + has winner | 422 `status` or `winner` |
| Payment | `invoiced` | 422 `status` |
| Shipment | `paid` | 422 `status` |
| Complete | `shipped` | 422 `status` |
| Double-invoice | Not already settled | 422 `settlement` |
| Double-payment | Not already `paid` | 422 `status` |

---

## 8. Bidding Journey

### 8.1 Bid Rules

1. **Who can bid:** Any signed-in user (buyer, seller, or admin) except the seller who owns the listing
2. **When can bid:** Only when auction is `live` AND current time is before `ends_at`
3. **First bid:** Must be ≥ `starting_price_cents`
4. **Subsequent bids:** Must strictly exceed `current_bid_cents`
5. **No fixed increment:** Just needs to be higher
6. **Amount type:** Positive integer (cents)

### 8.2 Bid History

1. **Displayed on auction detail** page (both public `/browse` and admin `/admin`)
2. **Sorted newest-first**
3. **Bidder names shown:**
   - To the bidder themselves: "You" (with `mine: true` flag)
   - To others: Bidder's actual name (snapshot at bid time)
4. **Backend stores** `bidder_name` as snapshot — changing name later doesn't affect bid history

### 8.3 Bid Denormalization

The `products` collection stores derived bid data for fast reads:
- `current_bid_cents` — highest bid amount
- `highest_bidder_id` — ID of top bidder
- `bid_count` — total number of bids

The `bids` collection stores the full bid history as a separate audit trail.

---

## 9. Account Management Journey

### 9.1 Editing Profile

1. **User clicks "Edit profile"** on dashboard
2. **Switches to Edit Profile Screen**
3. **Form fields:**
   - Name (required)
   - Email (required)
   - New password (optional, min 8 chars if provided)
   - Current password (required if changing email or password)
4. **Frontend calls** `PATCH /api/profile` with changed fields only
5. **Backend validates:**
   - If changing password: new password ≥ 8 chars, current password provided and correct
   - If changing email: current password provided and correct, email format valid, not duplicate
   - If changing name: not empty
6. **If email changed:**
   - Resets `step` to `verify_email`
   - Issues new verification token
   - Logs token to stdout
   - User must re-verify email
7. **Backend updates user** and stores
8. **Frontend returns to dashboard** with "Profile updated"
9. **Event emitted:** `ProfileUpdated`

### 9.2 Signing Out

1. **User clicks "Sign out"** on dashboard
2. **Frontend calls** `POST /api/signout`
3. **Backend clears session**
4. **Frontend resets state** → shows Login Screen
5. **Event emitted:** `UserSignedOut`

### 9.3 Session Persistence

1. **On page load** (`/app` or `/admin`), frontend calls `GET /api/me`
2. **If session valid:** Auto-restores user state and routes to correct screen
3. **If session invalid/expired:** Shows Login Screen
4. **Event emitted:** `SessionResumed`

---

## 10. Technical Architecture Summary

### 10.1 Bounded Contexts (Sub-Domains)

| Context | Files | Responsibility |
|---------|-------|---------------|
| `CheckExisting` | `lib/basic4/check_existing/` | Pre-signup email uniqueness check |
| `Register` | `lib/basic4/register/` | User signup, password hashing, initial state |
| `VerifyToken` | `lib/basic4/verify_token/` | Email verification token verification and resend |
| `BuyerOnboarding` | `lib/basic4/buyer_onboarding/` | Shipping address persistence |
| `CreditScoring` | `lib/basic4/credit_scoring/` | Credit score computation, seller approval/rejection |
| `Identity` | `lib/basic4/identity/` | Login, profile update, password reset |
| `ProductAuction` | `lib/basic4/product_auction/` | Listing CRUD, auction start/stop, bidding, image upload |
| `Admin` | `lib/basic4/admin/` | Product approval (approve/reject/list pending) |
| `Settlement` | `lib/basic4/settlement/` | Settlement lifecycle, admin detail views, queue |

### 10.2 Shared Kernel

- **Aggregates:** `User`, `Product`, `Bid`, `Settlement`, `Notification`
- **Value Objects:** `EmailVerification`, `CreditScoreSnapshot`, `ShippingAddress`, `PasswordReset`
- **Result Pattern:** `Basic4::Result` with `Success`/`Failure` and chain methods (`bind`, `map`, `tap_ok`)
- **Ports (interfaces):** `UserRepository`, `ProductRepository`, `BidRepository`, `SettlementRepository`, `PasswordHasher`, `TokenGenerator`, `Notifier`, `Clock`, `ObjectStorage`
- **Infrastructure:** MongoDB repos, BCrypt, SecureRandom, Stdout notifier, System clock, MinIO S3

### 10.3 Data Storage

| Collection | Database | Indexes |
|-----------|----------|---------|
| `users` | MongoDB | `email: 1` (unique) |
| `products` | MongoDB | `seller_id: 1` |
| `bids` | MongoDB | `product_id: 1, created_at: -1` |
| `settlements` | MongoDB | `product_id: 1` (unique) |
| `notifications` | MongoDB | `(user_id: 1, created_at: -1)`, `(user_id: 1, read: 1)` |

### 10.4 Frontend Architecture

- **Vue 3 SPA** with Composition API
- **Native ES modules** (no build step)
- **State management:** Reactive singleton (`store.js`)
- **Event bus:** Tiny pub/sub (`events.js`) with `on()` / `emit()`
- **API layer:** `api.js` (JSON) + `apiUpload.js` (multipart)
- **Components:** One screen per file, route-based rendering
- **Subscriber pattern:** `console-logger.js` logs all events

### 10.5 API Endpoints Summary

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/check-existing` | None | Check email availability |
| POST | `/api/signup` | None | Create account |
| POST | `/api/login` | None | Authenticate |
| POST | `/api/signout` | Session | End session |
| GET | `/api/me` | Session | Current user |
| POST | `/api/onboarding/verify-email` | Session | Verify email token |
| POST | `/api/onboarding/resend-token` | Session | Resend verification token |
| POST | `/api/onboarding/shipping-address` | Session | Save shipping address |
| POST | `/api/onboarding/become-seller` | Session | Start seller upgrade |
| POST | `/api/onboarding/credit-score` | Session | Submit credit score |
| GET | `/api/products` | None | Browse all auctions |
| GET | `/api/products/:id` | None | Auction detail + bid history |
| POST | `/api/products/:id/bid` | Session | Place bid |
| POST | `/api/products` | Seller | Create listing |
| PUT | `/api/products/:id` | Seller | Edit draft listing |
| POST | `/api/products/:id/start` | Seller | Start auction |
| POST | `/api/products/:id/stop` | Seller | Stop auction |
| POST | `/api/products/images` | Seller | Upload image |
| GET | `/api/products/mine` | Seller | My auctions |
| GET | `/api/admin/auctions` | Admin | Closed auctions list |
| GET | `/api/admin/auctions/:id` | Admin | Admin detail view |
| GET | `/api/admin/settlements` | Admin | Settlement queue |
| POST | `/api/admin/products/:id/settlement` | Admin | Invoice winner |
| POST | `/api/admin/settlements/:id/payment` | Admin | Record payment |
| POST | `/api/admin/settlements/:id/shipment` | Admin | Record shipment |
| POST | `/api/admin/settlements/:id/complete` | Admin | Complete settlement |
| GET | `/api/admin/seller-applications` | Admin | Pending sellers |
| POST | `/api/admin/seller-applications/:id/approve` | Admin | Approve seller |
| POST | `/api/admin/seller-applications/:id/reject` | Admin | Reject seller |
| GET | `/api/admin/pending-products` | Admin | List products awaiting approval |
| POST | `/api/admin/products/:id/approve` | Admin | Approve product (→ draft) |
| POST | `/api/admin/products/:id/reject` | Admin | Reject product with reason |
| GET | `/api/notifications` | User | List my notifications |
| PATCH | `/api/notifications/:id/read` | User | Mark notification read |
| GET | `/api/notifications/unread-count` | User | Get unread count |
| PATCH | `/api/profile` | Session | Update profile |
| POST | `/api/password/forgot` | None | Request password reset |
| POST | `/api/password/reset` | None | Reset password with token |
| GET | `/api/health` | None | Health check (DB + app) |

### 10.6 Validation & Error Patterns

- **422 errors** return `{ error: "message", field: "field_name" }`
- **401 errors** for unauthenticated access to protected endpoints
- **403 errors** for role mismatches (e.g., buyer trying to sell)
- **404 errors** for missing resources (with collapsed "not found / not yours" for ownership privacy)
- **Step guards** prevent skipping onboarding steps
- **Status guards** prevent invalid auction/settlement transitions

### 10.7 Event Bus (Frontend)

Events emitted by the frontend:
- `UserSignedUp` — after successful signup
- `UserAuthenticated` — after successful login
- `SessionResumed` — after page load with valid session
- `UserSignedOut` — after signout
- `EmailVerified` — after email verification
- `VerificationTokenResent` — after resending token
- `ShippingAddressSaved` — after shipping address saved
- `SellerApplicationStarted` — after clicking "Become a seller"
- `BecameSeller` — after credit score submitted and approved
- `ProfileUpdated` — after profile changes saved
- `ProductListedForAuction` — after creating a listing
- `AuctionUpdated` — after editing a draft
- `AuctionStarted` — after starting an auction
- `AuctionStopped` — after stopping an auction
- `PasswordResetRequested` — after requesting password reset
- `PasswordResetCompleted` — after resetting password

---

## 11. Complete State Reference

### 11.1 User States

| `role` | `step` | Screen Shown | Actions Available |
|--------|--------|-------------|-------------------|
| `buyer` | `verify_email` | Verify Email | Resend token, verify |
| `buyer` | `shipping_address` | Shipping Address | Save address |
| `buyer` | `done` | Dashboard | Browse, bid, become seller, edit profile |
| `buyer` | `credit_scoring` | Credit Scoring | Submit credit score |
| `seller` | `done` | Dashboard | Browse, bid, create auctions, manage listings, edit profile |
| `admin` | `done` | Admin Console | View closed auctions, manage settlements, approve sellers |

### 11.2 Product States

| Status | Description | Actions |
|--------|-------------|---------|
| `draft` | Created, editable, not yet visible for bidding | Edit, Start, Delete (implied) |
| `live` | Active, bidding open, locked from edits | Stop, Bid |
| `ended` | Bidding closed, awaiting settlement | View, Invoice (admin) |
| `completed` | Settlement finished, funds released | View (read-only) |

### 11.3 Settlement States

| Status | Description | Next Action |
|--------|-------------|-------------|
| `invoiced` | Winner invoiced, awaiting payment | Record payment |
| `paid` | Payment received, awaiting shipment | Record shipment |
| `shipped` | Item shipped, awaiting fund release | Complete settlement |
| `completed` | Funds released, order closed | None |

---

*End of AUCTIONS.md — every feature, screen, API endpoint, business rule, and state transition is documented above.*
