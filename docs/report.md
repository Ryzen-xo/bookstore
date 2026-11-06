# Shelf — BookStore Flutter App · Project Report

**Aptech eProject · "Shelf" — an editorial, local-first bookshop with an AI Librarian**

| | |
|---|---|
| Project | Shelf (BookStore) |
| Platform | Flutter 3.19+ / Dart 3.3+ (built on 3.29.3 / 3.7.2) |
| State | Provider (`ChangeNotifier`) |
| Database | SQLite via `sqflite` (on-device, local-first) |
| AI | Google Gemini (`gemini-2.0-flash`) + on-device TF-IDF fallback |
| Design | "Folio" — warm paper, ink serif, vermilion accent, code-drawn 3D covers |
| Cost | Zero — free Gemini tier, no paid services, no network images or fonts |

---

## 1. Abstract

Shelf is a complete mobile bookshop that runs entirely on the device. A customer can
browse a 46-book catalogue, search and filter, read and write reviews, manage a reading
list, check out with a simulated payment, and track orders. An administrator gets a
back office for books, users, orders and reviews. The signature feature is the **AI
Librarian**: a chat assistant that recommends real books from the local catalogue, using
Google Gemini when a key is present and an on-device TF-IDF engine otherwise — so it
works with no network at all. The whole experience is wrapped in a deliberate editorial
design language ("Folio") that avoids stock Material styling.

## 2. Problem statement

Small bookshops need a polished, affordable storefront app that works offline, protects
customer data, and still offers modern conveniences like conversational recommendations.
Most student projects either hard-code a catalogue, leak API keys into the app, or depend
on a backend that costs money. Shelf demonstrates a production-shaped alternative:
local-first data, a typed repository, hashed credentials, simulated payments, and an AI
layer that degrades gracefully and never invents books.

## 3. Objectives

1. Deliver a full shopping journey: discover → details → cart → checkout → orders.
2. Keep all data on-device in a normalised SQLite schema, accessed through one repository.
3. Provide role-based administration with guarded routes.
4. Add an AI assistant that is useful online **and** offline, and that only acts on
   explicit user confirmation.
5. Apply a consistent, distinctive design system with accessibility built in.
6. Verify the build with static analysis and an automated test suite.

## 4. Scope

**In scope:** authentication (email + demo social), catalogue, search/filter/sort,
reviews, wishlist, cart, coupon, 3-step checkout, order tracking/cancel/invoice, profile
(addresses, payment methods, security, settings), admin back office, AI chat, light/dark
themes, onboarding, FAQ and About.

**Out of scope (by design):** real payment processing, real OAuth, cloud sync,
multi-device accounts, push notifications, and real book-cover photography. These are
simulated or omitted to keep the project free, private and self-contained.

## 5. Technology stack & justification

| Package | Why |
|---------|-----|
| `provider` | Lightweight, idiomatic `ChangeNotifier` state; no codegen. |
| `sqflite` | Mature SQLite plugin; transactions, indexes, foreign keys. |
| `path` | Resolve the on-device database path. |
| `shared_preferences` | Tiny key/value settings (theme, onboarding, demo tools). |
| `crypto` | SHA-256 password hashing with a per-user salt. |
| `http` | The single network call to Gemini (or a proxy). |

**Dev dependencies** (justified in the developer guide): `sqflite_common_ffi` +
`sqlite3` run the real repository against an in-memory SQLite database in unit tests;
`http`'s `MockClient` tests the Gemini JSON parser without a network; `flutter_test`
drives widget tests including a 200% text-scale accessibility check.

## 6. System architecture

Shelf is a layered, local-first app:

- **Presentation** (`lib/features/*`, `lib/core/widgets/*`) — Folio widgets only; never
  writes SQL.
- **State** (`lib/state/app_state.dart`) — a single `AppState` `ChangeNotifier` exposed
  through an inherited scope; owns session, cart count, wishlist ids, theme and navigation.
- **Data** (`lib/data/repo.dart`) — the *only* place SQL lives. All queries are
  parameterised. Returns typed models and throws friendly `AppError`s.
- **Storage** (`lib/data/schema.dart`, `db.dart`, `seed.dart`) — 14 tables, 4 indexes,
  foreign keys ON, seeded with 46 books and demo accounts.
- **AI** (`lib/features/ai/*`) — `ChatController` orchestrates `GeminiService` (online) and
  `OfflineEngine` (offline), validates returned book ids against real candidates, and
  only performs add/save actions after a confirmation tap.

See `docs/diagrams/` for the ERD, use-case, data-flow, class and sequence diagrams
(Mermaid `.mmd`, renderable in GitHub/VS Code or mermaid.live).

## 7. Database design

14 tables: `users`, `authors`, `genres`, `books`, `addresses`, `payment_methods`,
`password_resets`, `cart_items`, `wishlist_items`, `reviews`, `review_likes`, `orders`,
`order_items`, `order_events`. Four indexes speed the hot paths (books by genre/author,
reviews by book, orders by user). Foreign keys are enforced; order items snapshot title
and price so history is stable even if a book changes. The full column list is in
`lib/data/schema.dart` and the ERD.

## 8. Key algorithms & flows

- **Checkout** is a single transaction: validate cart and stock → insert order + items +
  a `Placed` event → generate `TRK-<id>-PK` → decrement stock, increment sold → clear cart
  → commit (rollback on any failure). See `sequence_checkout.mmd`.
- **Offline recommendations** use weighted TF-IDF (title ×3, author/genre/tags ×2,
  description ×1) with IDF `log((N+1)/(df+1))+1` and L2 normalisation, blended with rating
  and popularity. Hard constraints (genre, price, pages, in-stock, bestseller, fresh,
  classic) are parsed from natural language and applied strictly, then relaxed if empty.
  Follow-ups ("cheaper", "shorter", "something else", "same author") reuse conversation
  state. See `sequence_ai.mmd`.
- **Gemini safety**: the model is asked for JSON and given only candidate book ids; any id
  it returns that is not a real candidate is dropped, so it can never hallucinate a book
  into a card. Prices/stock on cards always come from the database.

## 9. Security & privacy

- Passwords: SHA-256 + per-user random salt; never stored in plain text.
- Login throttling: 5 attempts / 30 s per email.
- Password reset: 8-hex uppercase code, 30-minute expiry, single use.
- Payments: brand, last-4 and expiry only — never full PAN or CVV.
- AI: only the message, candidate book metadata and the latest order's id/status/tracking
  are sent; no name, email, address or card data. The key is supplied at run time via
  `--dart-define` (or a Cloudflare Worker proxy) and is never committed.
- SQL: 100% parameterised; widgets never touch the database.

## 10. Design system ("Folio")

Warm paper background, ink-black serif display type, a single vermilion accent, hairline
rules, and tactile 3D book covers drawn entirely in code. No glass/blur, no default
Material chrome. Colours are read only through `context.f`; text only through `FolioText`.
A "night reading" dark theme mirrors every token. Motion is gentle and respects
reduce-motion; the layout is verified at 200% text scale.

## 11. Testing & verification

| Check | Command | Result |
|-------|---------|--------|
| Static analysis | `flutter analyze` | **No issues found** (incl. `test/`) |
| Unit + widget tests | `flutter test` | **84 / 84 passed** (~19 s) |
| Online parse path | `flutter test --dart-define=GEMINI_API_KEY=test_key test/gemini_parse_test.dart` | **9 / 9 passed** |
| Dart kernel compile | `flutter build bundle` | **exit 0** (app + gallery targets) |

Test breakdown: repository 35, offline engine 34 (≥15 natural-language queries), Gemini
parse 9 (MockClient), widgets 6 (incl. 200% text scale). The widget suite caught and fixed
a real overflow in the book card at large text. See `docs/test_cases.md`.

**APK build:** attempted in this sandbox. Java 21 and the Android SDK (platform 35,
build-tools 35) were installed and Gradle reached `assembleDebug`, but the box has only
~1.9 GB RAM, so the Gradle/Kotlin build thrashed swap and had to be killed (exit 143).
The Android module is complete and standard (`com.aptech.shelf`, minSdk 21, v2 embedding,
INTERNET permission, label “Shelf”), so `flutter build apk --release` will succeed on a
normal machine with **4 GB+ RAM, the Android SDK and JDK 17+**.

**Not verified in this environment:** no finished APK, no emulator/device run, no
screenshots captured, and no live Gemini network call (the parse path is tested with a
mock). See the honest limitations in the README and developer guide.

## 12. Limitations & future work

- Simulated payments and demo social login (no real money, no real OAuth).
- Local-only data; no cloud sync or multi-device.
- Online AI needs a free key, is rate-limited, and can err; the offline engine is the
  guaranteed floor.
- Future: real OAuth, a sync backend, push notifications, barcode scanning, and a
  recommendation model trained on reading history.

## 13. Conclusion

Shelf meets every objective: a complete, offline-capable bookshop with guarded admin, a
safe and graceful AI assistant, a distinctive accessible design, and a green automated
test suite — all at zero cost and with no secrets in the codebase.

## 14. Deliverables index

- Source: `lib/`, `test/`, `proxy/worker.js`, Android/iOS config.
- Docs: `report.md`, `user_guide.md`, `developer_guide.md`, `test_cases.md`,
  `demo_script.md`, `screenshots/README.md`, root `README.md`.
- Diagrams: `docs/diagrams/*.mmd` (ERD, use-case, data-flow, class, checkout & AI sequences).
