# Shelf — Test Cases

**Suite status: 84 / 84 passing** (`flutter test`, ~10–19 s). Static analysis
(`flutter analyze`, including `test/`) reports **no issues**. Both `main.dart` and
`main_gallery.dart` compile to Dart kernel (`flutter build bundle`, exit 0).

Run them:

```bash
flutter test
flutter test --dart-define=GEMINI_API_KEY=test_key test/gemini_parse_test.dart  # online parse path
```

Legend: ✅ = passed in the verified run.

## A. Repository — `test/repo_test.dart` (35)

Real SQLite via `sqflite_common_ffi` (in-memory), fresh DB per test.

### PasswordHasher (3)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 1 | Hash then verify round-trips | `salt:hash`, verify true / wrong false | ✅ |
| 2 | Two hashes of same password differ | random salt | ✅ |
| 3 | Strength rules | short / no-digit / no-letter rejected; `abcdefg1` ok | ✅ |

### Pricing (3)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 4 | STUDENT10 gives 10% off | 100→10, case-insensitive, unknown→0, 0→0 | ✅ |
| 5 | Shipping thresholds | 20→2.99, 30→0, 45→0, 0→0 | ✅ |
| 6 | Total combines subtotal/discount/shipping | 20→22.99, 100→90, 20+coupon→20.99 | ✅ |

### Auth (6)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 7 | Seeded demo login | demo user, not admin | ✅ |
| 8 | Admin login | isAdmin true | ✅ |
| 9 | Wrong password | generic AppError | ✅ |
| 10 | Register validates + rejects duplicates | new id; dup + bad email rejected | ✅ |
| 11 | Login throttles after 5 failures | 6th attempt “Too many” | ✅ |
| 12 | Social login creates demo account | `demo.google@shelf.app`, idempotent | ✅ |

### Password reset (2)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 13 | Token single-use + expires | 8 chars; reuse + expiry rejected | ✅ |
| 14 | Change password requires old | wrong old rejected; new works | ✅ |

### Catalog (5)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 15 | Seed ~46 books / 12 genres | ≥40 books, 12 genres | ✅ |
| 16 | Search title/author/genre | Dune; Andy Weir ≥2; Fantasy only | ✅ |
| 17 | Price sort + filter | ascending; maxPrice respected | ✅ |
| 18 | New arrivals sorted desc | 3, created_at descending | ✅ |
| 19 | Suggest titles + authors | “har” non-empty; “a” empty (min 2) | ✅ |

### Cart (3)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 20 | Add / change qty / remove | counts 2→3→0 | ✅ |
| 21 | Cannot exceed stock | over-stock add/set rejected | ✅ |
| 22 | Out of stock cannot be added | AppError | ✅ |

### Orders (6)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 23 | placeOrder decrements stock + clears cart | stock−2, cart 0, Placed event | ✅ |
| 24 | Rolls back when stock short | cart/order/stock unchanged | ✅ |
| 25 | Empty cart cannot order | AppError | ✅ |
| 26 | Cancel only before shipping + restores stock | Cancelled; shipped cancel rejected | ✅ |
| 27 | Admin cancel restores stock; advance flows | stock restored; Processing→Shipped | ✅ |
| 28 | Admin stats exclude cancelled revenue | revenue > 0 from seeded orders | ✅ |

### Reviews (4)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 29 | One review per user per book, editable | upsert to rating 5 | ✅ |
| 30 | Like toggles on/off | true then false | ✅ |
| 31 | Rating histogram has 5 buckets | length 5 | ✅ |
| 32 | Review body capped at 600 chars | 601 rejected | ✅ |

### Wishlist (1)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 33 | Toggle adds and removes | true then false | ✅ |

### Admin (2)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 34 | saveBook creates author/genre; deleteBook FK-safe | new book; sold-book delete rejected; fresh delete ok | ✅ |
| 35 | setUserActive / setUserAdmin | deactivate blocks login; admin flag set | ✅ |

## B. Offline engine — `test/offline_engine_test.dart` (34)

### Constraint parsing (12)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 36 | “under 15 dollars” | maxPrice 15 | ✅ |
| 37 | “cheap” | maxPrice 12 | ✅ |
| 38 | “short” | maxPages 300 | ✅ |
| 39 | “long epic” | minPages 450 | ✅ |
| 40 | sci-fi / scifi / science fiction | genre Science Fiction | ✅ |
| 41 | programming / tech | genre Technology | ✅ |
| 42 | self help | genre Self-Help | ✅ |
| 43 | cozy / funny / dark | tags mapped | ✅ |
| 44 | “books by Andy Weir” | author “andy weir” | ✅ |
| 45 | “something like Dune” | likeTitle “dune” | ✅ |
| 46 | bestseller / new / classic | flags set | ✅ |
| 47 | cheaper / shorter / something else / same author | follow-up flags | ✅ |

### Results respect constraints (13)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 48 | cozy under $12 | non-empty, all ≤ 12 | ✅ |
| 49 | short sci-fi | sci-fi < 300p, includes Neuromancer | ✅ |
| 50 | fantasy under 15 | Fantasy, ≤ 15 | ✅ |
| 51 | books by Andy Weir | only Andy Weir | ✅ |
| 52 | like Dune | all Science Fiction | ✅ |
| 53 | long epic fantasy | Fantasy > 450p | ✅ |
| 54 | bestseller | all sold ≥ 1000 | ✅ |
| 55 | history books | all History | ✅ |
| 56 | learn programming | all Technology | ✅ |
| 57 | romance under 10 | Romance ≤ 10 | ✅ |
| 58 | inspiring biography | all Biography | ✅ |
| 59 | classic novel | Classics or tag classic | ✅ |
| 60 | why notes present | non-empty why per pick | ✅ |

### Follow-ups (3)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 61 | cheaper < previous average | all < prior avg | ✅ |
| 62 | something else excludes shown | no overlap with prior | ✅ |
| 63 | same author keeps author | same author as prior | ✅ |

### Conversation (6)
| # | Case | Expected | Status |
|---|------|----------|--------|
| 64 | greeting | no picks, mentions librarian | ✅ |
| 65 | thanks | no picks | ✅ |
| 66 | shipping question | mentions “30” | ✅ |
| 67 | order tracking question | mentions “order” | ✅ |
| 68 | vague nonsense | still offers bestsellers | ✅ |
| 69 | candidates ≤ 12 real books | 0 < n ≤ 12 | ✅ |

## C. Gemini parse — `test/gemini_parse_test.dart` (9)

`MockClient`, no real network. Adaptive to `configured`; the online parse path is
exercised with a dummy `--dart-define=GEMINI_API_KEY=test_key`.

| # | Case | Expected | Status |
|---|------|----------|--------|
| 70 | Valid JSON parsed + ids validated | reply contains Dune, ids [1] | ✅ |
| 71 | Markdown-fenced JSON cleaned | ids [2] | ✅ |
| 72 | Malformed JSON | null | ✅ |
| 73 | Hallucinated ids dropped | [1,2] (999/12345 dropped) | ✅ |
| 74 | HTTP 429 | null, lastError contains 429 | ✅ |
| 75 | Timeout | null, lastError contains “Timed out” | ✅ |
| 76 | Prompt-injection action for non-candidate | only valid candidate action remains | ✅ |
| 77 | Empty reply | null | ✅ |
| 78 | No key | not configured, null, mentions GEMINI_API_KEY | ✅ |

## D. Widgets — `test/widget_test.dart` (6)

| # | Case | Expected | Status |
|---|------|----------|--------|
| 79 | Login empty fields | “Enter a valid email address.” + “Enter your password.” | ✅ |
| 80 | Login malformed email | email error shown | ✅ |
| 81 | BookCard grid @100% | no overflow, title present | ✅ |
| 82 | BookCard grid @200% | no RenderFlex overflow | ✅ |
| 83 | BookCard row @200% | no RenderFlex overflow | ✅ |
| 84 | StarRating input | tap 3rd star → 3 | ✅ |

## Notes on test design

- The seed is tuned so constraints are satisfiable: **Neuromancer** is the only sci-fi
  under 300 pages; **Pride & Prejudice** is the only Romance ≤ $10; there is **no Thriller
  ≤ $12** (so “cheap thriller” falls back to bestsellers rather than asserting a price).
- The login throttle is per-instance, so the throttle test’s deliberate failures don’t
  leak into later tests (each gets a fresh `Repo`).
- The 200% text-scale tests are a regression guard: they caught a real `BookCard` overflow
  during development, fixed by using a `Wrap` for the rating/price line and keeping cover
  artwork typography fixed relative to the cover.
