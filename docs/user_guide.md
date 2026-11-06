# Shelf — User Guide

Welcome to **Shelf**, an editorial bookshop that lives on your phone. This guide walks
through everything you can do.

## 1. Getting started

1. Open the app. You’ll see a short animated splash, then three onboarding cards (you can
   **Skip**).
2. You land on the **Home** tab. You can browse and ask the librarian as a guest.
3. To save books, build a cart and place orders, **sign in** (You → Sign in).

### Demo accounts

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@bookstore.com` | `Admin@123` |
| Customer (with data) | `demo@bookstore.com` | `Demo@1234` |
| Shopper | `ayesha@example.com` | `Password@123` |
| Shopper | `ali@example.com` | `Password@123` |
| Shopper | `sara@example.com` | `Password@123` |

The **demo** customer already has a Karachi address, a Visa •••• 4242, three saved books,
a **Delivered** order and a **Shipped** order with tracking.

> Google and Facebook buttons are **demos** — they create a local demo account and do not
> contact Google or Facebook.

## 2. The five tabs

The bottom bar has five slots: **Home · Browse · Librarian · Cart · You**. The raised
centre button opens the AI Librarian.

## 3. Home

- A featured **New this week** book.
- An **Ask the librarian** banner.
- **By genre** chips.
- **New arrivals** carousel and a **Bestsellers** shelf of spines.
- **Recently viewed** once you’ve opened a few books.

## 4. Browse & search

- Type in the search box for live **suggestions** (titles and authors).
- **Filters**: genre, max price, in-stock only.
- **Sort**: most popular, price low→high, price high→low, newest, top rated.
- **Views**: grid, list, or a **shelf** of book spines.
- Tap any card to open the book.

## 5. Book details

- A 3D cover with a parallax header.
- Badges (genre, bestseller, low stock), rating, pages, year and availability.
- **About this book**, a rating **histogram**, and reader **reviews**.
- **Write a review** (sign in required): 1–5 stars and up to 600 characters; one per book,
  editable. **Like** reviews you agree with.
- **Similar books** and a sticky **Add to cart** bar. Tap the heart to save to your list.

## 6. Reading list (wishlist)

Tap the heart on any book to save it. Open it from Home or You. **Move to cart** when
you’re ready, or remove it.

## 7. Cart

- Adjust quantities with the steppers (stock-aware) or remove a line.
- Apply coupon **STUDENT10** for 10% off.
- The receipt shows subtotal, discount, shipping and total.
- **Shipping**: $2.99 under $30, **free at $30+**.
- Tap **Checkout**.

## 8. Checkout (3 steps)

1. **Address** — pick a saved address or add a new one.
2. **Payment** — pick a saved card or add one. *Simulated*: only brand, last 4 and expiry
   are stored; never the full number or CVV.
3. **Review** — confirm items and totals, then **Place order**.

You’ll see an **ORDER PLACED** stamp and can jump straight to tracking.

## 9. Orders & tracking

- **You → My orders** lists every order with status and tracking number.
- Open an order for a live **timeline** (Placed → Processing → Shipped → Out for delivery
  → Delivered).
- **Cancel** while Placed or Processing (stock is restored).
- Tap the receipt icon for an **invoice**.
- With **Demo tools** enabled (Settings), an **advance status** button appears for demos.

## 10. The AI Librarian

- Ask in plain language: *“something cozy under $12”*, *“short sci-fi”*, *“books like
  Dune”*, *“an inspiring biography”*.
- Follow up: *“cheaper”*, *“shorter”*, *“something else”*, *“same author”*.
- The chip shows **ONLINE · GEMINI** when a key is configured and the network works, or
  **OFFLINE MODE** when the on-device engine answers. It always works offline.
- Suggested actions (**Add to cart**, **Save to list**) always ask you to **confirm** first.
- Ask store questions too: shipping, returns, the coupon, or where your order is.
- **Clear** the conversation any time. No personal data is sent to the AI.

## 11. You (profile)

- Your **library card** with a barcode.
- Links to **orders**, **reading list**, **settings & security**, **FAQ** and **About**.
- **Admin back office** appears only for admin accounts.
- **Sign out**.

## 12. Settings & security

- **Night reading mode** (warm dark theme).
- **Change password** (requires your current password).
- Manage **addresses** and **payment methods**.
- **Demo tools** toggle.
- **Clear librarian chat history**.

## 13. Admin back office (admin only)

- **Dashboard**: revenue, orders, books, users, a 7-day sales chart and low-stock list.
- **Books**: add, edit, delete (books in past orders are protected).
- **Users**: activate/deactivate, grant/revoke admin.
- **Orders**: advance or set any status.
- **Reviews**: moderate (delete) reviews.

## 14. Accessibility

- The layout is safe up to **200% text scale**.
- Gentle motion that respects your device’s **reduce-motion** setting.
- High-contrast ink-on-paper type in both light and dark themes.

## 15. Troubleshooting

| Problem | Fix |
|---------|-----|
| “Too many attempts” on login | Wait ~30 seconds and try again. |
| Reset code invalid/expired | Request a new code; codes last 30 minutes and are single-use. |
| AI shows OFFLINE MODE | Expected without a key, or when offline/quota-limited. It still answers. |
| Can’t cancel an order | It has already shipped; cancellation is only before shipping. |
| Can’t delete a book (admin) | It appears in a past order; set stock to 0 instead. |
