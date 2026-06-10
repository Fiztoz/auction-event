# Refinement Brief — Reporting Service

**Branch:** `reporting-fee` · **Date:** 2026-06-10
**Audience:** Agent (or developer) doing the cleanup pass. Read this fully before editing.

## Context

This branch deletes the old `basic4` monolith (`lib/`, `routes.rb`, `views/`, `test/`, most of `public/js/`) and replaces it with a **read-only Reporting Service**: Sinatra + MariaDB projections + RabbitMQ consumer. The new code works, but the rewrite left behind bugs, stale docs, and dead files. Everything below was verified against the working tree on 2026-06-10.

**Hard constraint:** this service is READ-ONLY. Writes happen only through event handlers in `app/models/report.rb`. Do not add action endpoints (approve/reject/pay/etc.).

---

## P1 — Bugs (fix first)

### 1. `/api/health` is shadowed and always reports `ok`
`AdminController` is mounted as middleware via `use` in `app.rb:34`, and it defines its own `/api/health` (`app/controllers/admin_controller.rb:91-94`) that unconditionally returns `status: ok`. Middleware routes win, so the real health check in `app.rb:43-56` (which pings MariaDB/RabbitMQ and returns 503 when degraded) **never executes**.
**Fix:** delete the `/api/health` route from `AdminController`. Verify with `curl localhost:4567/api/health` while MariaDB is stopped — it must return 503/`degraded`.

### 2. No event idempotency despite the dedup table existing
`db/mariadb/init/01_schema.sql` creates `report_events` with `UNIQUE KEY uk_event_id`, but `Report.process_event` (`app/models/report.rb:97`) never reads or writes it. Combined with `nack(..., requeue: true)` in `config/rabbitmq.rb:88`, any handler error causes infinite redelivery, and each redelivery **double-increments** counters (`update_daily_metric`, `update_seller_stat`).
**Fix:**
- At the start of `process_event`, `INSERT IGNORE` the event's `event_id` into `report_events`; skip processing when the row already existed (check `affected_rows`).
- Change the consumer's error path to dead-letter or drop after N attempts instead of requeueing forever (a simple `requeue: false` + log is acceptable for this training project).

### 3. `RabbitMQ.connect` returns `nil` when already connected
`config/rabbitmq.rb:33` — `return if @connection&.connected?` returns `nil`, which the caller in `app.rb:115` treats as failure ("RabbitMQ not available"). **Fix:** `return true if @connection&.connected?`.

### 4. `settlement.created` is recorded with status `invoiced`
`app/models/report.rb:113-114` routes both `settlement.created` and `settlement.invoiced` to `handle_settlement_created`, which hardcodes `'invoiced'`. The `ON DUPLICATE KEY` clause also only bumps `updated_at`, so a later `settlement.invoiced` never changes status. **Fix:** insert `settlement.created` as a distinct initial status (schema allows it — check the `status` column) or update `status` in the duplicate-key branch.

### 5. `active_auctions` daily gauge goes negative across days
`handle_auction_ended` calls `update_daily_metric('active_auctions', -1)` (`app/models/report.rb:181`). `report_platform_daily` rows are per-day; an auction that starts Monday and ends Tuesday leaves Tuesday's row at `-1`. **Fix:** compute the gauge from `report_active_auctions WHERE status='live'` at read time (in `Report.latest_metrics` or a view) instead of incrementing a daily counter, or carry the previous day's value forward when inserting a new daily row. Pick one and document it in `docs/reporting-service/DATABASE.md`.

### 6. `/browse/:id` loads every auction to find one
`app/controllers/reports_controller.rb:19-24` fetches all rows then filters in Ruby. **Fix:** add `Report.auction_by_id(product_id)` using a `WHERE product_id = ?` query.

---

## P2 — Dead code and broken references (delete/repair)

| Item | Problem | Action |
|------|---------|--------|
| `bin/basic4`, `bin/basic4-report`, `bin/create_admin` | Require deleted `lib/basic4` / `Basic4::*` — crash on run | Delete all three |
| `Rakefile` | Default task runs `test/**/test_*.rb`; `test/` was deleted | Keep the task but note there are no tests yet (see P4), or point it at the future `test/` dir |
| `README.md:100` | "Run tests: `ruby test/test_*.rb`" — no tests exist | Remove or rewrite once tests exist |
| `README.md:110` | Links `docs/reporting-service/DESIGN.md` — file is actually at repo root `DESIGN.md` | Move `DESIGN.md` into `docs/reporting-service/` and fix the link |
| `AUCTIONS.md`, `AUCTIONS.html`, `PLAN.md`, `REQUIREMENTS.md`, root `ARCHITECTURE.md` | Describe the deleted monolith (MongoDB/Vue/MinIO architecture) | Delete, or move to `docs/archive/basic4/` if history matters; `AUCTIONS.html` should just be deleted (generated artifact) |
| `bin/mock_events/Archive.zip` | Binary artifact in source tree | Delete and add `*.zip` to `.gitignore` |
| `public/php.png` | Leftover unrelated asset | Delete |
| `.env.example` | Says `NODE_ENV` — this is a Ruby app | Replace with `RACK_ENV=development` |
| `Gemfile` | `gem 'erb'` is stdlib (unneeded); `# Security` comment sits above rackup/puma (mislabeled) | Remove the erb gem line, fix the comment |
| `.DS_Store` | Tracked and modified even though `.gitignore` now ignores it | `git rm --cached .DS_Store` (also `bin/mock_events/.DS_Store` etc. if tracked) |

---

## P3 — Consistency between docs and code

1. **Event names:** `README.md:75-89` uses underscore names (`product_listed`) and attributes `auction_started` to **bidding**. The code (`config/rabbitmq.rb:22-27`) uses dot names and binds `auction.started` to the **selling** exchange, while `TASKS.md:153` says bidding. Decide the truth (the code's binding is what actually runs — and `bin/mock_events/selling.rb` publishes it), then align README, TASKS.md, and `docs/reporting-service/EVENTS.md` to identical names and sources.
2. **Settlement events:** README lists only `invoice_created`/`settlement_completed`; code consumes five settlement events. Align.
3. `docs/reporting-service/EVENTS.md:178-184` still shows `event_type: "auction_started"` payload examples with underscores — update to dot notation to match routing keys.

---

## P4 — Hardening (do after P1–P3)

1. **Tests.** There are zero tests. Minimum useful set (Minitest is already in the Gemfile):
   - `Report.process_event` handler tests against a test DB (or extract SQL-free logic), covering idempotent replay (same `event_id` twice → counters increment once).
   - Rack::Test request specs for `/api/health` degraded path and one report endpoint.
2. **Consumer thread robustness** (`app.rb:110-134`): the `Thread.new` + `sleep 5` runs once; if RabbitMQ is down at boot it never retries. Wrap connect in a retry loop with backoff. Also guard so the thread only starts under the web process (it currently starts whenever `app.rb` is required).
3. **Field-name interpolation:** `update_daily_metric`/`update_seller_stat` (`app/models/report.rb:246-262`) interpolate `field` into SQL. Callers are internal so it's not injectable today; add a whitelist constant of allowed column names and raise on anything else.
4. **Compose/Dockerfile:** app runs as MariaDB `root` and `RACK_ENV=development` in the container; MariaDB and RabbitMQ ports are published to the host. Fine for local training, but add a non-root DB user and stop publishing 3306 if this ever leaves a laptop.
5. **Auth on `/admin`:** acknowledged in TASKS.md as low priority — leave as-is, but keep it on the roadmap.

---

## Git hygiene (do last)

The entire rewrite is **uncommitted** (127 files, −8353/+1549). After the fixes above, commit in logical units rather than one blob, e.g.:
1. `chore: remove basic4 monolith` (deletions)
2. `feat(reporting): service skeleton — config, schema, docker`
3. `feat(reporting): read-only views + API`
4. `feat(reporting): event consumer + projections`
5. `docs(reporting): align event docs with implementation`

Do **not** push or open a PR without the user's go-ahead.

## Acceptance checklist

- [ ] `curl /api/health` returns 503 when MariaDB is stopped
- [ ] Replaying the same event (same `event_id`) twice changes counters once
- [ ] A handler exception does not cause infinite redelivery
- [ ] `docker compose up -d && docker compose run --rm seeder` works; all pages in README's URL table render
- [ ] `grep -r basic4 .` (excluding `.git`) returns nothing
- [ ] README, TASKS.md, and docs/reporting-service/EVENTS.md list identical event names/sources matching `config/rabbitmq.rb`
- [ ] `rake test` runs green (once tests exist)
