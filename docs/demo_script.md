# Shelf — Demo Video Script

A ~4-minute narrated walkthrough. Record on a device/emulator at 1080×1920 (or
1080×2340). Use the **demo** customer unless a step says otherwise. Speak calmly; let the
animations breathe.

> Setup before recording: `flutter run` (offline) on a device. Sign out first so you can
> show onboarding. Have the admin credentials ready in a note off-screen.

---

### 0:00–0:20 — Cold open & onboarding
**Show:** splash → three onboarding cards → Home.
**Say:** “This is Shelf — an editorial bookshop that runs entirely on your phone. Warm
paper, ink serif type, hand-drawn covers. No stock Material look.”
**Do:** swipe the three cards, tap **Enter Shelf**.

### 0:20–0:45 — Home & browse
**Show:** featured book, genre chips, new arrivals, bestsellers shelf.
**Say:** “Forty-six real books across twelve genres. Browse by genre, or switch between
grid, list and a shelf of spines.”
**Do:** tap **Browse**, type “dune”, show suggestions, switch the three views, open a
filter (genre + price), apply.

### 0:45–1:15 — Book details & reviews
**Show:** parallax cover, badges, histogram, reviews, similar, sticky buy bar.
**Say:** “Every book has a 3D cover, a rating histogram and reader reviews. You can write
your own — one per book, editable.”
**Do:** open **Dune**, scroll to reviews, tap **Write a review**, give 5 stars, submit.
Tap the heart to save it.

### 1:15–1:50 — The AI Librarian (the headline)
**Show:** centre tab, OFFLINE chip, suggested prompts.
**Say:** “Meet the librarian. It works with no internet using an on-device engine, and
goes online with Gemini when a key is set. Watch.”
**Do:** tap **“Something cozy under $12”** → cards appear. Type **“short sci-fi”** →
Neuromancer. Type **“cheaper”** → follow-up works. Point at the **OFFLINE MODE** chip.
**Say:** “It only ever recommends real books from the store, and any action asks me to
confirm first.” Tap an **Add to cart** action → show the confirmation dialog → confirm.

### 1:50–2:20 — Cart, coupon & checkout
**Show:** cart receipt, STUDENT10, 3-step checkout, ORDER PLACED stamp.
**Say:** “The cart is a paper receipt. Shipping is free over thirty dollars, and
STUDENT10 takes ten percent off. Checkout is three steps — address, payment, review.
Payments are simulated; we only keep the last four digits.”
**Do:** open **Cart**, apply **STUDENT10**, **Checkout**, step through, **Place order**,
show the stamp.

### 2:20–2:50 — Orders & tracking
**Show:** order timeline, invoice, cancel rule.
**Say:** “Every order has a live tracking timeline and an invoice. You can cancel before
it ships.”
**Do:** open the new order, scroll the timeline, tap the receipt icon for the invoice.
Open the seeded **Shipped** order to show a fuller timeline.

### 2:50–3:20 — Profile & admin
**Show:** library card with barcode; then sign in as admin → dashboard.
**Say:** “Your library card lives in your profile. Admins get a back office.”
**Do:** You → show library card. Sign out, sign in as **admin@bookstore.com / Admin@123**,
open **Admin back office**: dashboard chart, Books (edit one), Orders (advance one),
Reviews.

### 3:20–3:45 — Dark mode & accessibility
**Show:** night reading mode; large text.
**Say:** “A warm night-reading theme, and the layout stays clean at two-hundred-percent
text size.”
**Do:** Settings → toggle **Night reading mode**; (optional) show device large-text setting.

### 3:45–4:00 — Close
**Show:** Home in dark mode.
**Say:** “Shelf — local-first, private, and genuinely helpful offline. Built with Flutter,
SQLite and an optional Gemini layer, verified by eighty-four automated tests.”

---

## Recording tips
- Keep the Gemini key **off-screen**; never show `--dart-define` values.
- If online mode is desired, pre-configure the key before recording and show the
  **ONLINE · GEMINI** chip; otherwise the offline demo is fully representative.
- Capture stills for `docs/screenshots/` at each bold **Show** moment (see that folder’s
  README).
