# Shelf — the editorial bookshop

A complete, local-first **BookStore** Flutter app built as an Aptech eProject, with a
distinctive **"Folio"** editorial design (warm paper, ink-black serif type, tactile 3D
book covers, hairline rules, one vermilion accent) and a working **AI Librarian** that
runs online (Gemini) and always falls back to an on-device engine.

> **Honest scope:** payments are **simulated**, Google/Facebook sign-in are **labelled
> demos**, and all data lives in **SQLite on the device**. The only network feature is
> the AI chat, which needs a free Gemini key and is rate-limited.

---

## Quick start (3 commands)

```bash
flutter pub get
flutter run                      # offline AI, full app
# optional: online AI (never commit your key)
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Requires **Flutter 3.19+ / Dart 3.3+** (built and tested on Flutter 3.29.3 / Dart 3.7.2).

## Demo logins (seeded)

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@bookstore.com` | `Admin@123` |
| Customer with data | `demo@bookstore.com` | `Demo@1234` |
| Shopper | `ayesha@example.com` | `Password@123` |
| Shopper | `ali@example.com` | `Password@123` |
| Shopper | `sara@example.com` | `Password@123` |

The **demo** customer already has an address, a Visa •••• 4242, 3 wishlist books, a
**Delivered** order and a **Shipped** order with tracking timelines.

## Feature list

- **Auth:** email sign-up, login/logout, session survives restart, password reset with a
  one-time on-screen code (30 min, single use), login throttling, demo social sign-in.
- **Catalog:** 46 real books across 12 genres; browse by genre & author; Bestsellers; New arrivals.
- **Search & filters:** live suggestions; sort by price/popularity/release/rating; genre + price + in-stock filters; grid/list/**shelf** views.
- **Book page:** 3D cover with parallax, stats, pull-quote review summary, histogram, reviews (write/edit/like), similar books, sticky buy bar.
- **Cart:** stock-aware steppers, coupon `STUDENT10`, perforated receipt summary.
- **Checkout:** 3 numbered steps, simulated payment, order-success stamp.
- **Orders:** history, animated tracking timeline, cancel before shipping, invoice, demo advance.
- **Wishlist / reading list:** heart everywhere, move to cart.
- **Profile:** library card with barcode, details, addresses, payment methods (last-4 only), change password, settings.
- **Admin back office:** dashboard, books CRUD, users, orders, review moderation (role-guarded).
- **AI Librarian:** Gemini + offline TF-IDF engine, confirmation-only actions, no PII sent.
- **Design:** light + "night reading" dark mode, reduce-motion aware, 200% text scale safe.

## Project layout

```
lib/
  core/theme/tokens.dart         Folio design tokens + type scale
  core/widgets/folio_widgets.dart The reference widget kit (covers, nav, reveals…)
  core/widgets/common.dart       Shared app widgets (BookCard, fields, toasts…)
  data/                          schema, models, security, db, seed, repo
  state/app_state.dart           Provider ChangeNotifier
  features/                      splash, onboarding, shell, auth, home, browse,
                                 book, cart, checkout, orders, wishlist, profile,
                                 admin, static, ai
  main.dart / app.dart           Entry + themed MaterialApp
  main_gallery.dart              Standalone look-and-feel + AI gallery
proxy/worker.js                  Optional free Cloudflare Worker (keeps key off phone)
docs/                            Report, guides, diagrams, test cases, demo script
test/                            repo, offline engine, Gemini parse, widget tests
```

## Tests & checks

```bash
flutter analyze        # clean
flutter test           # 84 tests
flutter test --dart-define=GEMINI_API_KEY=test_key test/gemini_parse_test.dart  # online parse path
```

## Building an APK

```bash
flutter build apk --release      # needs Android SDK + JDK 17+ and ~4 GB RAM
```

The Android module is complete (`com.aptech.shelf`, minSdk 21, label “Shelf”, INTERNET
permission). In the build sandbox (1.9 GB RAM) Gradle reached `assembleDebug` but thrashed
and was killed, so no finished APK is included — build it on a normal machine.

## Known limitations

- Simulated payments; no real charge, no full card number or CVV ever stored.
- Demo social login (no real OAuth).
- Local-only data (no cloud sync, no multi-device).
- Online AI needs a free Gemini key, is rate-limited, and can make mistakes; prices and
  stock on the cards always come from the local database.
- Book covers are drawn in code (no network images, no downloaded fonts).

See `docs/` for the full report, user guide, developer guide, test-case table and demo script.
