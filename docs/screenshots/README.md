# Screenshots

**Status: NOT captured in this environment.** This build was verified with static
analysis, an 84-test automated suite and a Dart-kernel compile, but there is **no
emulator or physical device** available here, so no real screenshots were taken. This
folder is a placeholder with instructions for capturing them on your machine.

Do not fabricate screenshots. Capture the real app using one of the methods below.

## What to capture (suggested filenames)

| File | Screen |
|------|--------|
| `01_onboarding.png` | Onboarding card |
| `02_home.png` | Home (featured + genres + bestsellers) |
| `03_browse_grid.png` | Browse, grid view |
| `04_browse_shelf.png` | Browse, shelf view |
| `05_book_details.png` | Book page (cover + histogram) |
| `06_review_sheet.png` | Write-a-review sheet |
| `07_librarian_offline.png` | Chat with OFFLINE MODE chip + cards |
| `08_librarian_online.png` | Chat with ONLINE · GEMINI chip (key set) |
| `09_cart.png` | Cart receipt with STUDENT10 |
| `10_checkout.png` | Checkout step 3 (review) |
| `11_order_success.png` | ORDER PLACED stamp |
| `12_order_tracking.png` | Order timeline |
| `13_invoice.png` | Invoice |
| `14_profile_card.png` | Library card with barcode |
| `15_admin_dashboard.png` | Admin dashboard + chart |
| `16_admin_books.png` | Admin books list |
| `17_dark_home.png` | Home in night-reading mode |
| `18_large_text.png` | BookCard at 200% text scale |

## Method 1 — emulator / device (recommended)

```bash
flutter run                 # on a connected device or emulator
```
Then use the device screenshot shortcut, or:
```bash
# Android
adb exec-out screencap -p > docs/screenshots/02_home.png
# iOS simulator
xcrun simctl io booted screenshot docs/screenshots/02_home.png
```

## Method 2 — integration-test screenshots

Add an `integration_test/` that pumps each page and captures screenshots, or use the
`screenshots` package with `flutter drive`. (Not added here to keep dependencies minimal.)

## Method 3 — golden images (widget-level)

For widget-level stills (e.g. BookCard at 200% text), add a golden test and run
`flutter test --update-goldens`. This renders real pixels without a device.

## Notes
- Capture at a phone resolution (e.g. 1080×1920) for consistency.
- Never include the Gemini key, a real card number, or personal data in a screenshot.
- The demo customer (`demo@bookstore.com`) has seeded orders/wishlist for richer shots.
