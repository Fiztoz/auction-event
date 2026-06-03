# Basic4

A Ruby 4 project with two things in it:

1. A small **library module** (`Basic4`) with a CSV report generator, a `Ractor`-based parallel greeter, and a `greet` helper.
2. A **4-step user onboarding web app** built with **Sinatra**, **MongoDB**, and **Vue.js**, themed after Coinbase's visual language.

Requires Ruby `4.0.5` (see `.ruby-version`). Also runs on **JRuby 10.0.5.0**
(Ruby 3.4 compat) — see [Running on JRuby](#running-on-jruby).

---

## Onboarding flow

Every new account is a **buyer**. Selling is an opt-in **upgrade**.

```
  Buyer:   Signup → Verify email → Shipping address → Done (role=buyer)
  Upgrade: Done buyer → "Become a seller" → Credit score → Done (role=seller)
```

1. **Signup** — email format + uniqueness validated, bcrypt-hashed password. New users start as `role: "buyer"`.
2. **Verify email** — a 6-digit token is generated, stored on the user doc with a 15-minute TTL, and **logged to stdout** (no SMTP). The user submits the code to advance.
3. **Shipping address** — US-style address (line1, optional line2, city, region, postal code, country) for where orders ship. Completing it lands the buyer at `done`.
4. **Done (buyer)** — dashboard with the public catalog (`/browse`) and a **Become a seller** option.

**Become a seller (upgrade):** a done buyer opts in, which re-enters onboarding at the **credit scoring** step (annual income, employment, existing debt, years of credit history → deterministic score in `300..850`). On completion the user's `role` flips to `seller` and the seller dashboard (sell / edit listings) unlocks. Selling endpoints are gated by `require_seller!` (`role == "seller"`).

State lives on the user document (`role` + `step` fields). Each step is guarded server-side so the API can't be skipped or replayed out of order.

### Credit-score formula

`Basic4::CreditScoring.score` is pure and deterministic:

```
base                500
+ income / 1000     capped at +150
+ employment        employed +50 · self_employed +30 · student 0 · unemployed −50
+ history_years × 5 capped at +75
− DTI penalty       debt/income > 0.5 → −100 · 0.3..0.5 → −50 · else 0
clamped to          [300, 850]
```

Worked example — income `80_000`, employed, debt `10_000`, 5y history → **655**.

### Auction lifecycle

A listing is created as a **draft** and is **started manually by the seller**:

```
  create → draft → (seller clicks Start) → live
```

- **draft** — editable; visible to the seller in "My auctions" and tagged `draft` on `/browse`.
- **Start** (`POST /api/products/:id/start`) flips it to **live** and records `started_at` and `ends_at` (= `started_at` + `duration_days`). There is no automatic close yet — `ends_at` is informational.
- Once **live**, the listing is **locked**: `PUT /api/products/:id` returns `422` (drafts only). Starting an already-live auction also returns `422`.

`/browse` lists everything (drafts and live), each tagged with its status.

### Bidding

Any **signed-in** user can bid on a **live** auction from `/browse` (the page prompts
sign-in if you're logged out). Rules (`POST /api/products/:id/bid` with `{ amount_cents }`):

- the auction must be `live` and not past its `ends_at` (else `422`);
- you can't bid on **your own** listing (`422`);
- the **first** bid must be ≥ the starting price; each **later** bid must strictly exceed the
  current highest (no fixed increment).

The highest bid is denormalized on the product (`current_bid_cents`, `bid_count`,
`highest_bidder_id`); there's no settlement/checkout step yet.

---

## Run with Docker Compose

The `app` image is **JRuby-backed** (`jruby:10.0.5.0-jre`). First boot is
~5–10 s slower than MRI; steady-state throughput is higher (JVM JIT, true
threaded Puma).

```bash
cp .env.example .env          # edit SESSION_SECRET (must be ≥64 chars)
docker compose up --build
```

Open <http://localhost:4567>. To read the verification token during signup:

```bash
docker compose logs -f app | grep "verification token"
```

State persists in the named `mongo_data` volume across restarts.

## Run locally

Requires a running MongoDB on `mongodb://localhost:27017`.

```bash
bundle install
bundle exec rackup -p 4567    # or: rake server
```

### Running on JRuby

The Sinatra app runs under JRuby 10.0.5.0 (Ruby 3.4 compat) on the JVM. MRI
remains the default; JRuby is opt-in via `RBENV_VERSION`. JRuby 10.1.x is
**not** supported — `bson-5.2.0-java` crashes on its newer
`RubyFixnum` internals.

```bash
rbenv install jruby-10.0.5.0          # one-off
RBENV_VERSION=jruby-10.0.5.0 bundle install
RBENV_VERSION=jruby-10.0.5.0 bundle exec rake test
RBENV_VERSION=jruby-10.0.5.0 bundle exec rackup -p 4567
```

The two `Basic4.parallel_greet` tests skip under JRuby because `Ractor`
isn't implemented — `parallel_greet` is library code, not used by the API.

---

## HTTP API

| Method | Path                               | Auth    | Body                                            |
|--------|------------------------------------|---------|-------------------------------------------------|
| POST   | `/api/check-existing`              | none    | `{ email }` → `{ exists: Boolean }`             |
| POST   | `/api/signup`                      | none    | `{ email, password, name }`                     |
| POST   | `/api/onboarding/verify-email`     | session | `{ token }`                                     |
| POST   | `/api/onboarding/resend-token`     | session | —                                               |
| POST   | `/api/onboarding/shipping-address` | session | `{ line1, line2?, city, region, postal_code, country }` |
| POST   | `/api/onboarding/become-seller`    | session | — (done buyer → credit-scoring step)            |
| POST   | `/api/onboarding/credit-score`     | session | `{ income, employment, debt, history_years }` → flips role to `seller` |
| GET    | `/browse`                          | none    | public storefront page (HTML)                   |
| GET    | `/api/products`                    | none    | — → all listings, newest-first                  |
| POST   | `/api/products`                    | seller  | `{ title, description, category, starting_price_cents, duration_days, images[] }` |
| PUT    | `/api/products/:id`                | seller  | same as POST (owner only; draft only)           |
| POST   | `/api/products/:id/start`          | seller  | — (owner only; draft → live)                    |
| POST   | `/api/products/:id/bid`            | session | `{ amount_cents }` (not own; live; beats current) |
| POST   | `/api/products/images`             | seller  | multipart `file` → `{ url }` (MinIO)            |
| GET    | `/api/products/mine`               | seller  | — → caller's own listings                       |
| GET    | `/api/me`                          | session | —                                               |
| POST   | `/api/signout`                     | session | —                                               |
| GET    | `/api/health`                      | none    | —                                               |

All responses are JSON (except `/browse`). Validation failures return `422` with `{ error, field }`. The session cookie is set on successful signup. **Auth column:** `session` = signed in (`401` otherwise); `seller` = signed in **and** `role == "seller"` (`403` otherwise, via `require_seller!`).

---

## Project layout

The web app is organized as **five sub-domains** (bounded contexts) on top of a
single hexagonal **shared kernel**. The kernel owns cross-cutting concerns —
the `Basic4::User` aggregate, `Basic4::Result`, the Mongo connection, ports, and
production adapters — while each sub-domain owns its own use cases. URL →
handler mapping lives in `routes.rb`; `app.rb` owns Sinatra setup and helpers.

```
.
├── app.rb                                 Sinatra setup + helpers (respond_with, current_user, json_body)
├── routes.rb                              URL → handler mapping (reopens Basic4::OnboardingApp)
├── config.ru                              Rack entry
├── lib/
│   ├── basic4.rb                          Library module (greet / parallel_greet / report)
│   └── basic4/
│       ├── shared/                        SHARED KERNEL — Basic4::* top-level types
│       │   ├── shared.rb                  Namespace index (declares all sub-domain modules)
│       │   ├── result.rb                  Basic4::Result — Success/Failure + Chain mixin
│       │   ├── db.rb                      Basic4::DB — Mongo client + index setup
│       │   ├── user.rb                    Basic4::User aggregate + EmailVerification, CreditScoreSnapshot, PasswordReset value objects; constants; behaviors returning Result<User>
│       │   ├── user_presenter.rb          Basic4::UserPresenter — Basic4::User → public Hash
│       │   ├── ports/                     Abstract interfaces (DuplicateEmail lives in user_repository.rb)
│       │   │   ├── user_repository.rb
│       │   │   ├── password_hasher.rb
│       │   │   ├── token_generator.rb
│       │   │   ├── notifier.rb
│       │   │   └── clock.rb
│       │   ├── infrastructure/            Concrete adapters — only place that knows Mongo / BCrypt / SecureRandom / $stdout / Time
│       │   │   ├── mongo_user_repository.rb
│       │   │   ├── bcrypt_password_hasher.rb
│       │   │   ├── secure_random_token_generator.rb
│       │   │   ├── stdout_notifier.rb
│       │   │   └── system_clock.rb
│       │   └── container.rb               Composition root — Basic4::Container.production returns the port→adapter map
│       ├── check_existing/                SUB-DOMAIN 1 — pre-signup uniqueness check
│       │   └── application/
│       │       ├── inputs.rb              Inputs::CheckEmail
│       │       └── check_email.rb         .call(input, container:) → Result.success({ exists: Boolean })
│       ├── register/                      SUB-DOMAIN 2 — signing up
│       │   └── application/
│       │       ├── inputs.rb              Inputs::Signup
│       │       └── register_user.rb       .call(input, container:) — .map/.bind/.tap_ok pipeline
│       ├── verify_token/                  SUB-DOMAIN 3 — email verification flow
│       │   └── application/
│       │       ├── verify_email_token.rb  .call(user_id, token:, container:)
│       │       └── resend_email_token.rb  .call(user_id, container:)
│       ├── credit_scoring/                SUB-DOMAIN 4 — credit-score computation
│       │   ├── domain/scoring.rb          Pure score calculator (Basic4::CreditScoring::Domain::Scoring) + InvalidInput
│       │   └── application/
│       │       ├── inputs.rb              Inputs::CreditScoreSubmission
│       │       └── compute_credit_score.rb
│       └── identity/                      SUB-DOMAIN 5 — login / profile / password reset
│           └── application/
│               ├── inputs.rb              Inputs::Login, ProfileUpdate, PasswordResetRequest, PasswordResetSubmit
│               ├── authenticate_user.rb
│               ├── update_profile.rb
│               ├── request_password_reset.rb     Boolean return, no leak
│               └── reset_password.rb
├── views/index.erb                        Vue 3 mount + Inter font (loads app.js as ES module)
├── public/
│   ├── css/style.css                      Coinbase-themed styles
│   └── js/                                Vue 3 SPA as native ES modules
│       ├── app.js                         Entry — installs subscribers, mounts App, routes by step + authMode
│       ├── api.js                         fetch wrapper + STEPS constant
│       ├── store.js                       Reactive state singleton + form helpers
│       ├── actions.js                     Side-effecting actions; emits domain events on each success
│       ├── events.js                      Tiny pub/sub bus — on(fn), emit(name, payload)
│       ├── subscribers/
│       │   └── console-logger.js          install() registers a console.log listener for every event
│       └── components/                    One screen per file
│           ├── signup-screen.js
│           ├── login-screen.js
│           ├── password-forgot-screen.js
│           ├── password-reset-screen.js
│           ├── verify-email-screen.js
│           ├── credit-scoring-screen.js
│           ├── edit-profile-screen.js
│           └── dashboard-screen.js
├── test/
│   ├── test_helper.rb                     Shared rack-test setup + helpers
│   ├── test_basic4.rb                     Library tests
│   ├── test_scoring.rb                    Scoring engine unit tests
│   ├── test_identity.rb                   Signup, login, profile, password reset
│   └── test_onboarding.rb                 Verify-email, resend, credit-score step
├── Dockerfile                             ruby:4.0.5-slim image
├── docker-compose.yml                     app + mongo + healthcheck
└── .env.example
```

---

## Tests

```bash
rake test
```

- `test_basic4.rb` and `test_credit_scoring.rb` have no external dependencies.
- `test_onboarding_app.rb` uses `rack-test` against a live MongoDB (`MONGO_DB=basic4_onboarding_test`); it auto-skips when Mongo isn't reachable.

---

## CLI utilities

The library ships two small scripts in `bin/`:

```bash
ruby bin/basic4 "Ruby"                # prints: Hello, Ruby!
ruby bin/basic4-report input.csv out.txt   # writes a score report + average
```

`bin/basic4-report` expects a CSV with `name,email,score` columns.
