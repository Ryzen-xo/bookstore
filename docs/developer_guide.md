# Shelf — Developer Guide

How the code is organised, how to run and extend it, and why each dependency exists.

## 1. Prerequisites

- **Flutter 3.19+ / Dart 3.3+** (built and tested on **Flutter 3.29.3 / Dart 3.7.2**).
- For an Android APK: **Android SDK** (platform 35, build-tools 35) and **JDK 17+**.
- For iOS: macOS + Xcode (not required to run the tests or the Android build).

```bash
flutter pub get
flutter analyze
flutter test
flutter run                                   # offline AI
flutter run --dart-define=GEMINI_API_KEY=…    # online AI (never commit the key)
```

## 2. Project layout

```
lib/
  core/theme/tokens.dart          Folio colours, type scale, theme builder
  core/widgets/folio_widgets.dart Reference kit: covers, nav, buttons, reveals…
  core/widgets/common.dart        App widgets: BookCard, fields, toasts, sheets…
  data/
    schema.dart                   14 tables + 4 indexes (kSchema)
    models.dart                   Typed models + Pricing + AppError
    security.dart                 PasswordHasher (salted SHA-256)
    db.dart                       AppDatabase.open + nowTs
    seed.dart                     46 books, 12 genres, users, demo data
    repo.dart                     ALL SQL (parameterised), the only DB gateway
  state/app_state.dart            Provider ChangeNotifier + AppStateScope
  features/                       one folder per feature (auth, home, browse, …)
  app.dart / main.dart            Themed MaterialApp + guarded entry point
  main_gallery.dart               Standalone look-and-feel + AI gallery
proxy/worker.js                   Optional Cloudflare Worker (keeps key off device)
test/                             repo, offline engine, Gemini parse, widgets
docs/                             report, guides, diagrams, test cases, demo script
```

## 3. Architecture rules

1. **Widgets never write SQL.** Every query lives in `lib/data/repo.dart` and uses `?`
   placeholders. The repo returns typed models and throws friendly `AppError`s.
2. **One state object.** `AppState` (a `ChangeNotifier`) owns session, cart count,
   wishlist ids, theme and navigation. Read it via `AppStateScope.of/read`.
3. **Colours only via `context.f`; text only via `FolioText`.** No raw Material chrome,
   no glass/blur. Use the Folio widgets instead of default Material components.
4. **Local-first.** SQLite on device; the only network call is the AI chat, which always
   falls back to the offline engine.
5. **Safety.** `mounted` checks after every `await`, controllers disposed, no `print`
   (use `debugPrint` in debug), and a global error handler in `main.dart`
   (`FlutterError.onError` + `runZonedGuarded`).

## 4. Dependencies & justification

### Runtime (the fixed, zero-cost stack)

| Package | Why it’s here |
|---------|---------------|
| `provider` | Idiomatic `ChangeNotifier` state with no code generation. |
| `sqflite` | Mature SQLite plugin: transactions, indexes, foreign keys. |
| `path` | Resolve the on-device database file path. |
| `shared_preferences` | Tiny settings: theme, onboarding, demo tools, session id, chat history. |
| `crypto` | SHA-256 password hashing with a per-user random salt. |
| `http` | The single HTTPS call to Gemini (or the proxy). |

### Dev dependencies (justified)

| Package | Why it’s needed |
|---------|-----------------|
| `flutter_test` | Widget tests, including the 200% text-scale accessibility checks. |
| `sqflite_common_ffi` (+ transitive `sqlite3`) | Runs the **real** repository against an in-memory SQLite database in unit tests, so the SQL itself is verified — not mocked. This is the only way to test transactions, foreign keys and the seed without a device. |
| `http` (`MockClient` from `package:http/testing.dart`) | Tests the Gemini JSON parser, id-validation, markdown cleaning, 429/timeout handling **without any network call**. `http` is already a runtime dependency; the testing library ships with it, so this adds no new package. |

> No routing package is used — navigation is the built-in `Navigator` with
> `MaterialPageRoute`. No extra packages beyond the list above.

## 5. The data contract

- `AppDatabase.open({String? pathOverride})` creates + seeds on first run; tests pass
  `inMemoryDatabasePath`.
- `Repo` exposes auth, catalog, cart, orders, reviews, wishlist, addresses, payments and
  admin methods. See `lib/data/repo.dart` for the full surface.
- **Checkout** is one transaction: validate stock → insert order/items/event → generate
  `TRK-<id>-PK` → decrement stock / increment sold → clear cart → commit (rollback on
  failure).
- **Login throttle** is per-`Repo`-instance (5 attempts / 30 s per email), so each test’s
  fresh repo starts clean while a running app session throttles correctly.
- **FK safety**: `order_items.book_id` has no cascade, so deleting a sold book fails and
  the repo turns it into a friendly `AppError`.

## 6. The AI layer

- `OfflineEngine` (`features/ai/offline_engine.dart`): weighted TF-IDF
  (title ×3, author/genre/tags ×2, description ×1), IDF `log((N+1)/(df+1))+1`, L2 norm,
  blended with rating and popularity. Parses genre/price/pages/mood/author constraints,
  applies them strictly, relaxes tags if empty, and handles follow-ups
  (cheaper/shorter/something else/same author). Always available.
- `GeminiService` (`features/ai/gemini_service.dart`): reads the key from
  `--dart-define=GEMINI_API_KEY` (or `AI_PROXY_URL`). Requests JSON, strips markdown
  fences, and **validates every returned book id and action against the real candidate
  list** — hallucinated ids are dropped. Any failure returns `null`.
- `ChatController` orchestrates both: try Gemini, fall back to the offline engine on
  `null`. Actions are **confirm-only** in the UI. Only the message, anonymous book
  metadata and the latest order’s id/status/tracking are sent — never PII.

### Keeping the key secret

- Never put the key in any file, doc, screenshot, commit, test or log.
- Pass it at run time: `flutter run --dart-define=GEMINI_API_KEY=your_key`.
- Or deploy `proxy/worker.js` to a free Cloudflare Worker and pass
  `--dart-define=AI_PROXY_URL=https://your-worker.example.workers.dev` so the key lives
  only in the Worker’s environment variables.

## 7. Testing

```bash
flutter analyze        # static analysis (includes test/)
flutter test           # 84 tests
flutter test --dart-define=GEMINI_API_KEY=test_key test/gemini_parse_test.dart  # online parse path
flutter build bundle   # whole-app Dart kernel compile (no Android SDK needed)
```

See `docs/test_cases.md` for the full case list. The widget suite renders `BookCard` and
`AuthPage` at 100% and 200% text scale to catch overflow regressions.

## 8. Building a release

```bash
# Android (needs Android SDK + JDK 17+)
flutter build apk --release
# or an app bundle
flutter build appbundle --release
```

The release build type currently signs with the debug key (Flutter default). For a real
release, add a signing config in `android/app/build.gradle.kts`. `minSdk` is 21,
`applicationId` is `com.aptech.shelf`, the label is **Shelf**, and the manifest declares
`INTERNET`.

## 9. Extending

- **Add a book**: admin → Books → Add, or extend `seed.dart`.
- **Add a genre**: it’s created automatically by `saveBook` when a new genre name is used.
- **Add a page**: create it under `features/<name>/`, use `FolioPage` + Folio widgets, read
  state via `AppStateScope`, and call the repo for data.
- **Add an AI capability**: extend `OfflineEngine.parse/respond` and the Gemini system
  prompt; keep actions confirm-only and ids validated.

## 10. Known limitations

- Simulated payments and demo social login; local-only data (no cloud sync).
- Online AI needs a free key, is rate-limited and can err; the offline engine is the floor.
- Covers are code-drawn; system fonts only (no network images or downloaded fonts).
