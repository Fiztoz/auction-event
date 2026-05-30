# Basic4

A Ruby 4 project with two things in it:

1. A small **library module** (`Basic4`) with a CSV report generator, a `Ractor`-based parallel greeter, and a `greet` helper.
2. A **4-step user onboarding web app** built with **Sinatra**, **MongoDB**, and **Vue.js**, themed after Coinbase's visual language.

Requires Ruby `4.0.5` (see `.ruby-version`).

---

## Onboarding flow

```
  ┌─────────┐    ┌──────────────┐    ┌───────────────┐    ┌──────┐
  │ Signup  │ →  │ Verify email │ →  │ Credit score  │ →  │ Done │
  └─────────┘    └──────────────┘    └───────────────┘    └──────┘
```

1. **Signup** — email format + uniqueness validated, bcrypt-hashed password.
2. **Verify email** — a 6-digit token is generated, stored on the user doc with a 15-minute TTL, and **logged to stdout** (no SMTP). The user submits the code to advance.
3. **Credit scoring** — collects annual income, employment status, existing debt, and years of credit history, then computes a deterministic score in `300..850`.
4. **Done** — welcome screen displaying the computed score.

State lives on the user document (`step` field). Each step is guarded server-side so the API can't be skipped or replayed out of order.

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

---

## Run with Docker Compose

```bash
cp .env.example .env          # edit SESSION_SECRET
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

---

## HTTP API

| Method | Path                              | Auth      | Body                                            |
|--------|-----------------------------------|-----------|-------------------------------------------------|
| POST   | `/api/signup`                     | none      | `{ email, password, name }`                     |
| POST   | `/api/onboarding/verify-email`    | session   | `{ token }`                                     |
| POST   | `/api/onboarding/resend-token`    | session   | —                                               |
| POST   | `/api/onboarding/credit-score`    | session   | `{ income, employment, debt, history_years }`   |
| GET    | `/api/me`                         | session   | —                                               |
| POST   | `/api/signout`                    | session   | —                                               |
| GET    | `/api/health`                     | none      | —                                               |

All responses are JSON. Validation failures return `422` with `{ error, field }`. The session cookie is set on successful signup; the client uses it for the rest of the flow.

---

## Project layout

The web app is a modular monolith — bounded domain modules with one-way
dependencies (`Onboarding → Identity → Core`, plus `Onboarding → Scoring`).
All HTTP routes live in `app.rb`; only the services move into modules.

```
.
├── app.rb                                 Sinatra routing shell
├── config.ru                              Rack entry
├── lib/
│   ├── basic4.rb                          Library module (greet / parallel_greet / report)
│   └── basic4/
│       ├── db.rb                          Mongo client + index setup
│       ├── result.rb                      Basic4::Result — Success/Failure (Data), Chain mixin (bind/map/tap_ok)
│       ├── scoring.rb                     Basic4::Scoring — pure score calculator
│       ├── identity/                      Functional services + ports & adapters
│       │   ├── user.rb                    Shared constants, find, public_view, token helpers
│       │   ├── inputs.rb                  Data.define value objects (Signup, Login, ProfileUpdate, …)
│       │   ├── ports.rb                   Consolidated port docstrings + DuplicateEmail
│       │   ├── adapters.rb                Consolidated adapter MODULES (MongoUserRepo, BcryptHasher, SecureRandomTokens, StdoutNotifier, SystemClock)
│       │   ├── registration.rb            signup — module_function + .then pipeline
│       │   ├── authentication.rb          .call — module_function + small composed helpers
│       │   ├── profile.rb                 update — module_function + procedural composition over conditional changes
│       │   └── password_reset.rb          .request + .reset — module_function + pipelines
│       └── onboarding/
│           ├── email_verification.rb      .verify and .resend
│           └── credit_scoring.rb          .save (persists scoring result)
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
