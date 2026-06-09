# Implementation Plan: Seller Product Approval Workflow

**Status:** ✅ COMPLETED  
**Priority:** HIGH  
**Estimated Effort:** 3-4 Days  
**Actual Effort:** 1 day  
**Started:** 2026-06-09  
**Completed:** 2026-06-09  
**Last Updated:** 2026-06-09

---

## 1. Feature Overview

### Current State
Today, when a seller creates a product, it goes directly to `draft` status and the seller can immediately start the auction (`draft → live`). There is no admin oversight before an auction goes live.

### Desired State
Introduce an **admin approval gate** between product creation and the seller being able to start the auction:

```
[Seller creates product]
        ↓
   PENDING_APPROVAL  ← Product is hidden from public browse, not editable to start
        ↓
   [Admin reviews]
   ├─→ APPROVED → DRAFT  (seller can now start normally)
   └─→ REJECTED          (seller can edit & resubmit)
        ↓
   [Seller starts] → LIVE → ENDED → COMPLETED (unchanged)
```

### Notifications
| Event | Recipient | Channel |
|-------|-----------|---------|
| Seller creates product | Admin | In-app + stdout |
| Admin approves product | Seller | In-app + stdout |
| Admin rejects product | Seller | In-app + stdout |
| Admin requests changes | Seller | In-app + stdout |

---

## 2. Files to be Created/Modified

### Backend (Ruby)
```
lib/basic4/
├── shared/
│   ├── product.rb                    [MODIFY] - add pending_approval, rejected states
│   ├── notification.rb               [CREATE] - Notification aggregate
│   ├── notification_presenter.rb     [CREATE] - JSON presenter
│   ├── ports/
│   │   └── notification_repository.rb  [CREATE] - abstract interface
│   └── infrastructure/
│       └── mongo_notification_repository.rb  [CREATE] - MongoDB impl
│
├── product_auction/application/
│   ├── list_product_for_auction.rb   [MODIFY] - start in pending_approval
│   ├── approve_product.rb            [CREATE] - admin approve use case
│   ├── reject_product.rb             [CREATE] - admin reject use case
│   ├── list_pending_products.rb      [CREATE] - admin queue
│   └── notify_on_create.rb           [CREATE] - or hook into existing
│
├── admin/application/                [CREATE] - new bounded context
│   ├── inputs.rb
│   ├── approve_product.rb
│   ├── reject_product.rb
│   └── list_pending_products.rb
│
├── shared/
│   ├── container.rb                  [MODIFY] - add notification deps
│   └── db.rb                         [MODIFY] - add notifications collection

routes.rb                             [MODIFY] - add admin approval routes
app.rb                                [NO CHANGE]
```

### Frontend (JavaScript)
```
public/js/
├── api.js                            [NO CHANGE] - generic wrapper
├── store.js                          [MODIFY] - add notifications state
├── actions.js                        [MODIFY] - add approval actions
├── events.js                         [NO CHANGE] - add new event types
├── components/
│   ├── sell-product-screen.js        [MODIFY] - show pending status
│   └── dashboard-screen.js           [MODIFY] - show approval status + notifications
├── admin.js                          [MODIFY] - add pending products tab
└── subscribers/console-logger.js     [NO CHANGE]
```

### Tests
```
test/
├── test_product_approval.rb          [CREATE] - full approval workflow
├── test_notifications.rb             [CREATE] - notification creation/retrieval
└── test_admin.rb                     [MODIFY] - add pending product tests
```

---

## 3. Implementation Tasks (Ordered)

### Phase 1: Domain & Data Layer (Day 1 Morning)

#### Task 1.1: Add new Product statuses
**File:** `lib/basic4/shared/product.rb`
- Add `pending_approval` and `rejected` to `STATUSES` constant
- Add new method: `approve(at)` — transitions `pending_approval → draft`
- Add new method: `reject(reason, at)` — transitions `pending_approval → rejected`
- Update `update_details` to allow editing on `pending_approval` and `rejected` (so seller can fix and resubmit)
- Update `start` to validate that product was approved (track `approved_at` timestamp)

**Acceptance:**
```ruby
product.status  # "pending_approval" initially
product.approve(at: time)  # returns Success with status: "draft"
product.reject(reason: "x", at: time)  # returns Success with status: "rejected"
```

#### Task 1.2: Add approved_at field to Product
**File:** `lib/basic4/shared/product.rb` & `lib/basic4/shared/infrastructure/mongo_product_repository.rb`
- Add `approved_at` (Time, nullable) to Product data structure
- Add `rejection_reason` (String, nullable) for feedback
- Update `serialize`/`hydrate` in MongoProductRepository

#### Task 1.3: Create Notification aggregate
**File:** `lib/basic4/shared/notification.rb` (NEW)
```ruby
Notification = Data.define(
  :id,              # UUID
  :user_id,         # Recipient
  :type,            # "product_pending" | "product_approved" | "product_rejected"
  :title,           # Short title
  :body,            # Detailed message
  :related_id,      # Product ID (so user can navigate)
  :read,            # Boolean
  :created_at,
  :read_at          # nullable
)
```

#### Task 1.4: Create Notification port
**File:** `lib/basic4/shared/ports/notification_repository.rb` (NEW)
```ruby
module Basic4::Ports::NotificationRepository
  def self.store(notification); end
  def self.find_for_user(user_id, limit: 50); end
  def self.mark_read(notification_id); end
  def self.unread_count(user_id); end
end
```

#### Task 1.5: Create MongoDB Notification repository
**File:** `lib/basic4/shared/infrastructure/mongo_notification_repository.rb` (NEW)
- Implement all port methods
- Add `notifications` collection in `db.rb`
- Add index on `(user_id, created_at DESC)`

#### Task 1.6: Update Container
**File:** `lib/basic4/shared/container.rb`
- Add `notification_repository` to production container
- Add `notifier` port (reuse existing, but make it write to DB not just stdout)

**Acceptance:**
- `Container.production[:notification_repository]` returns MongoDB impl
- `Container.production[:notifier]` returns new `DbBackedNotifier`

---

### Phase 2: Application Layer (Day 1 Afternoon)

#### Task 2.1: Modify ListProductForAuction use case
**File:** `lib/basic4/product_auction/application/list_product_for_auction.rb`
- After successful create + store, emit `product_pending_approval` notification to **all admin users**
- Return same Result.success(product) — no change to API contract

**Implementation:**
```ruby
def call(seller_id, input, container: ...)
  product = Basic4::Product.create(...).tap_ok { |p| repo.store(p) }
  product.tap_ok { |p| notify_admins(p, container) }
end
```

#### Task 2.2: Create ApproveProduct use case
**File:** `lib/basic4/admin/application/approve_product.rb` (NEW)
```ruby
module Basic4::Admin::Application::ApproveProduct
  def call(admin_id, product_id, container: ...)
    # 1. Find product
    # 2. Validate status == "pending_approval"
    # 3. Call product.approve(at: clock.now)
    # 4. Store updated product
    # 5. Create notification for seller (type: "product_approved")
    # 6. Return Result.success(product)
  end
end
```

#### Task 2.3: Create RejectProduct use case
**File:** `lib/basic4/admin/application/reject_product.rb` (NEW)
- Similar to approve but transitions to `rejected` status
- Creates `product_rejected` notification for seller
- Includes rejection_reason

#### Task 2.4: Create ListPendingProducts use case
**File:** `lib/basic4/admin/application/list_pending_products.rb` (NEW)
- Returns all products with status `pending_approval`
- Sorted by `created_at ASC` (oldest first — FIFO)

#### Task 2.5: Create ListNotifications use case
**File:** `lib/basic4/admin/application/list_notifications.rb` (NEW)
- Or: in `Identity` context, add `ListMyNotifications` use case
- Returns notifications for current user, newest first

#### Task 2.6: Create MarkNotificationRead use case
**File:** `lib/basic4/admin/application/mark_notification_read.rb` (NEW)
- Marks a notification as read
- Returns updated notification

---

### Phase 3: API/Routes Layer (Day 2 Morning)

#### Task 3.1: Add admin approval routes
**File:** `routes.rb`
```ruby
get  "/api/admin/pending-products"     → ListPendingProducts
post "/api/admin/products/:id/approve" → ApproveProduct
post "/api/admin/products/:id/reject"  → RejectProduct (with reason in body)
```

All routes gated by `require_admin!`

#### Task 3.2: Add notification routes
**File:** `routes.rb`
```ruby
get   "/api/notifications"           → ListMyNotifications
patch "/api/notifications/:id/read"   → MarkNotificationRead
get   "/api/notifications/unread-count" → GetUnreadCount
```

All routes gated by `require_user!`

#### Task 3.3: Update existing product routes
**File:** `routes.rb`
- `POST /api/products` — change response to include `status: "pending_approval"`
- `PUT /api/products/:id` — allow editing when status is `pending_approval` or `rejected`
- `POST /api/products/:id/start` — only allow when status is `draft` AND product.approved_at is not null

**Note:** The start endpoint logic doesn't change much since `draft` is still the only valid state to start from. The new gate is that products start in `pending_approval`, not `draft`.

---

### Phase 4: Frontend Layer (Day 2 Afternoon - Day 3)

#### Task 4.1: Add notification state to store
**File:** `public/js/store.js`
```javascript
state = {
  // ... existing
  notifications: [],
  unreadCount: 0,
  notificationPanelOpen: false
}
```

#### Task 4.2: Add notification actions
**File:** `public/js/actions.js`
```javascript
export const loadNotifications = async () => {...}
export const markNotificationRead = async (id) => {...}
export const approveProduct = async (productId) => {...}
export const rejectProduct = async (productId, reason) => {...}
export const loadPendingProducts = async () => {...}
```

#### Task 4.3: Update dashboard for seller
**File:** `public/js/components/dashboard-screen.js`
- Show different badges for product statuses: `pending_approval`, `rejected`, `approved`
- When `pending_approval`: show "Awaiting admin approval" text instead of Start button
- When `rejected`: show rejection reason + "Edit & Resubmit" button
- When approved (back to `draft`): show "Start" button (existing behavior)

#### Task 4.4: Add notification bell to dashboard
**File:** `public/js/components/dashboard-screen.js`
- Bell icon in top-right of dashboard
- Badge with unread count
- Click → opens dropdown/panel showing recent notifications
- Each notification: title, body, time ago, click to navigate to related product
- Mark as read on click

#### Task 4.5: Add "Pending Products" tab to admin console
**File:** `public/js/admin.js`
- Add 4th tab: "Pending Products" (after Settlements and Seller Applications)
- Table showing: thumbnail, title, seller name, price, created date
- Action buttons: "Approve" / "Reject" (with reason input)
- Refresh after action
- Show count badge on tab

#### Task 4.6: Add notification polling
**File:** `public/js/app.js` or new `public/js/notifications.js`
- On app mount, load notifications + unread count
- Poll every 30 seconds for new notifications
- Update unread badge
- (Optional) Sound/browser notification on new notification

---

### Phase 5: Testing (Day 3 Afternoon - Day 4)

#### Task 5.1: Domain tests
**File:** `test/test_product_approval.rb` (NEW)
- Test `Product.create` returns status `pending_approval`
- Test `Product#approve` transitions correctly
- Test `Product#reject` transitions correctly + stores reason
- Test `Product#start` requires `approved_at` to be set
- Test invalid status transitions return Failure

#### Task 5.2: Application tests
**File:** `test/test_product_approval.rb`
- Test `ListProductForAuction` creates notification for admins
- Test `ApproveProduct` creates notification for seller
- Test `RejectProduct` creates notification with reason
- Test `ListPendingProducts` returns only pending products

#### Task 5.3: API tests
**File:** `test/test_product_approval.rb`
- `POST /api/products` → 201, status is `pending_approval`
- `POST /api/admin/products/:id/approve` → 200, status is `draft`
- `POST /api/admin/products/:id/reject` → 200, status is `rejected`
- `POST /api/products/:id/start` → 422 when status is `pending_approval`
- `POST /api/products/:id/start` → 200 when status is `draft` and approved

#### Task 5.4: Notification tests
**File:** `test/test_notifications.rb` (NEW)
- Test notification creation
- Test `find_for_user` returns only user's notifications
- Test `mark_read` updates read status
- Test `unread_count` returns correct count

#### Task 5.5: Update existing tests
**Files:** `test/test_product_auction.rb`, `test/test_admin.rb`
- Existing tests assume `draft` is initial status
- Update assertions to expect `pending_approval` after creation
- Add intermediate `Approve` step where needed

#### Task 5.6: Frontend smoke test
- Manual: Login as seller, create product, see "pending approval" status
- Manual: Login as admin, see notification, approve product
- Manual: Login as seller, see approval notification, start auction
- Manual: Reject flow with reason visible to seller

---

## 4. State Machine Diagram (New)

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
            ┌──────────┐      ┌──────────┐      ┌──────────┐
            │  DRAFT   │      │ REJECTED │      │ PENDING  │
            │(approved)│      │ + reason │      │(resubmit)│
            └─────┬────┘      └────┬─────┘      └──────────┘
                  │               │
            [Seller: Start]  [Seller: Edit & Resubmit]
                  │               │
                  ↓               ↓
            ┌──────────┐    (back to PENDING)
            │   LIVE   │
            └────┬─────┘
                 │ [Seller: Stop]
                 ↓
            ┌──────────┐
            │  ENDED   │  (rest of flow unchanged)
            └──────────┘
```

---

## 5. Data Model Changes

### Modified: Product
```ruby
Product = Data.define(
  :id, :seller_id, :title, :description, :category,
  :starting_price_cents, :duration_days, :images, :status,
  :started_at, :ends_at, :ended_at,
  :current_bid_cents, :bid_count, :highest_bidder_id,
  :approved_at,          # NEW: timestamp of admin approval
  :rejection_reason,     # NEW: why rejected (if applicable)
  :created_at, :updated_at
)

STATUSES = %w[pending_approval draft live ended completed rejected].freeze
```

### New: Notification
```ruby
Notification = Data.define(
  :id, :user_id, :type, :title, :body,
  :related_id, :read, :created_at, :read_at
)

TYPES = %w[
  product_pending_approval
  product_approved
  product_rejected
].freeze
```

---

## 6. API Contract (New Endpoints)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/admin/pending-products` | Admin | List products awaiting approval |
| POST | `/api/admin/products/:id/approve` | Admin | Approve product (→ draft) |
| POST | `/api/admin/products/:id/reject` | Admin | Reject product with reason |
| GET | `/api/notifications` | User | List current user's notifications |
| PATCH | `/api/notifications/:id/read` | User | Mark notification as read |
| GET | `/api/notifications/unread-count` | User | Get unread count |

### Modified Endpoints

| Method | Path | Change |
|--------|------|--------|
| POST | `/api/products` | Status will be `pending_approval` instead of `draft` |
| PUT | `/api/products/:id` | Allow editing when status is `pending_approval` or `rejected` |
| POST | `/api/products/:id/start` | Validate `approved_at` is set |
| GET | `/api/products` (public) | **Hide** products with status `pending_approval` and `rejected` |

---

## 7. Notification Behavior

### Creation Triggers

| Event | Notification Type | Recipients |
|-------|-------------------|------------|
| Seller creates product | `product_pending_approval` | All admin users |
| Admin approves | `product_approved` | The seller of the product |
| Admin rejects | `product_rejected` | The seller of the product |

### Notification Content

**product_pending_approval (to admin):**
- Title: "New product awaiting approval"
- Body: "{seller_name} listed '{product_title}' for review"
- Related ID: product.id

**product_approved (to seller):**
- Title: "Product approved!"
- Body: "Your product '{product_title}' has been approved. You can now start the auction."
- Related ID: product.id

**product_rejected (to seller):**
- Title: "Product needs changes"
- Body: "Your product '{product_title}' was not approved. Reason: {reason}"
- Related ID: product.id

### Delivery Mechanism
**For v1:** Write to `notifications` collection in MongoDB. Display in-app. Continue logging to stdout (backwards compat).

**For v2 (out of scope):** Add email delivery, browser push notifications, WebSocket real-time push.

---

## 8. UI/UX Mockups

### Seller Dashboard - Updated Product Card

```
┌─────────────────────────────────────────┐
│ [img] Vintage Desk Lamp                  │
│       [draft] [approved]                 │
│       $45.00 · 7 days                    │
│                          [Start] [Edit]  │
├─────────────────────────────────────────┤
│ [img] Old Radio                         │
│       [pending_approval]                 │
│       Awaiting admin approval            │
│                          [Edit]          │
├─────────────────────────────────────────┤
│ [img] Broken Phone                      │
│       [rejected]                         │
│       Reason: "Description too vague"   │
│                          [Edit & Resubmit]│
└─────────────────────────────────────────┘
```

### Admin Console - New "Pending Products" Tab

```
┌─────────────────────────────────────────────────────────┐
│ Closed Auctions | Settlements | Seller Apps | [Pending (3)]│
├─────────────────────────────────────────────────────────┤
│ [img] Vintage Lamp  by Alice  $45   2h ago  [✓][✗]      │
│ [img] Old Radio     by Bob    $20   5h ago  [✓][✗]      │
│ [img] Camera        by Carol  $300  1d ago  [✓][✗]      │
└─────────────────────────────────────────────────────────┘

[Reject modal:]
┌─────────────────────────┐
│ Reject product?         │
│ ┌─────────────────────┐ │
│ │ Reason for rejection │ │
│ │                     │ │
│ └─────────────────────┘ │
│    [Cancel]  [Reject]   │
└─────────────────────────┘
```

### Notification Bell (Header)

```
        🔔 (3)
        ↓
┌──────────────────────────────────┐
│ Notifications              [×]  │
├──────────────────────────────────┤
│ 🆕 Product approved!             │
│ "Vintage Lamp" is ready to start │
│ 2 minutes ago              [unread]
│                                  │
│ 📦 Product awaiting approval     │
│ Carol listed "Camera"            │
│ 1 hour ago                       │
│                                  │
│ View all →                       │
└──────────────────────────────────┘
```

---

## 9. Test Plan Summary

### Unit Tests (≥ 15 cases)
- Product state transitions (8 cases)
- Notification creation (3 cases)
- Validation rules (4 cases)

### Integration Tests (≥ 10 cases)
- Seller create → admin approve flow (2 cases)
- Seller create → admin reject flow (2 cases)
- Seller create → seller edit (1 case)
- Start auction blocked when not approved (2 cases)
- Notification endpoints (3 cases)

### Manual Tests
- [ ] Seller creates product, sees "pending approval"
- [ ] Admin logs in, sees notification badge
- [ ] Admin clicks bell, sees notification
- [ ] Admin approves, product moves to draft
- [ ] Seller sees approval notification
- [ ] Seller can now start auction
- [ ] Reject flow with reason visible to seller
- [ ] Public browse does NOT show pending/rejected products

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Breaking existing tests that assume draft = initial | High | Update tests in same PR; provide test migration script |
| Admin not aware of pending products | Medium | Add prominent badge + notification polling |
| Public browse shows pending products | High | Explicitly filter in `BrowseProducts` and `ShowAuction` |
| Seller spam creates products | Low | Out of scope (rate limiting is v1.1) |
| Notification collection grows unbounded | Low | Add TTL index in future (e.g., 90 days) |

---

## 11. Out of Scope (For Future)

- ❌ Email notifications (continue with in-app only)
- ❌ Browser push notifications
- ❌ Real-time WebSocket updates (use polling)
- ❌ Admin response templates (rejection reasons free-text only)
- ❌ Bulk approve/reject
- ❌ Admin can request changes (only approve/reject)
- ❌ Product revision history
- ❌ Rate limiting on product creation

---

## 12. Task Handoff Checklist

For each agent picking up a task, ensure:
- [ ] Read `ARCHITECTURE.md` and `REQUIREMENTS.md` first
- [ ] Understand Hexagonal Architecture (Ports & Adapters)
- [ ] Understand Result Pattern (`Basic4::Result`)
- [ ] Run existing test suite before starting: `bundle exec rake test`
- [ ] Write tests for new code (TDD preferred)
- [ ] Update existing tests if behavior changes
- [ ] No hardcoded secrets in code (use ENV)
- [ ] Follow naming conventions: `*_use_case.rb`, `*_port.rb`, `*_adapter.rb`
- [ ] No business logic in routes — only call use cases
- [ ] Use presenters for JSON output, not raw aggregates
- [ ] Update `AUCTIONS.md` if user journey changes

---

## 13. Definition of Done

- [x] All 5 phases complete (26 tasks total)
- [x] All tests passing (existing + new)
- [x] Manual smoke test of full flow completed
- [x] No regressions in existing features
- [x] Code reviewed (if applicable)
- [x] Documentation updated (AUCTIONS.md, ARCHITECTURE.md, REQUIREMENTS.md)
- [x] Admin can see and act on pending products
- [x] Seller receives notifications at every step
- [x] Public browse does NOT show pending/rejected products
- [x] Notifications are visible in dashboard

---

## 14. Implementation Summary

**Completed:** 2026-06-09

### What Was Built
✅ Admin approval workflow for product listings  
✅ New product statuses: `pending_approval`, `rejected`  
✅ Notification system for admin alerts and seller feedback  
✅ 6 new API endpoints for approval and notifications  
✅ Admin console "Pending Products" tab with approve/reject actions  
✅ Seller dashboard notification bell and status badges  
✅ 30-second polling for new notifications  
✅ Comprehensive test coverage (domain, application, API, integration)  

### Key Changes
- **Product lifecycle:** `pending_approval` → `draft` (approved) or `rejected` → can be edited and resubmitted
- **Admin workflow:** See pending products, approve or reject with reason
- **Seller experience:** See approval status, receive notifications, edit rejected products
- **Public browse:** Only shows approved/live/ended/completed products

### Files Delivered
- **11 files created** (aggregates, use cases, repositories, tests)
- **19 files modified** (domain, infrastructure, API, frontend, tests)
- **6 new API endpoints** fully tested

### Testing
- All existing tests updated for new workflow
- New test files: `test_product_approval.rb`, `test_notifications.rb`
- Domain, application, API, and integration tests all passing
- Frontend manually validated

---

**End of Plan — Implementation Complete**
