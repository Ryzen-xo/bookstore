import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

/// Help & FAQ — 22 questions.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const _faqs = <(String, String)>[
    ('Is Shelf a real shop?', 'Shelf is a demonstration project. The catalogue, accounts and orders are real working features, but payments are simulated and no books are actually shipped.'),
    ('Do I need an account to browse?', 'No. You can browse, search and ask the librarian as a guest. You only need an account to save a reading list, add to cart and place orders.'),
    ('How do I create an account?', 'Tap You → Sign in → Create an account, or use the demo accounts listed on the sign-in screen.'),
    ('What are the demo logins?', 'Customer: demo@bookstore.com / Demo@1234. Admin: admin@bookstore.com / Admin@123. Three more shoppers use Password@123.'),
    ('Is the Google / Facebook sign-in real?', 'No. Social sign-in is a labelled demo that creates a local demo account. No real Google or Facebook account is contacted.'),
    ('How does the AI librarian work?', 'It recommends real books from the catalogue. With a Gemini key it uses Google’s model; without one it uses an on-device engine. It always works offline.'),
    ('Does the AI send my personal data?', 'No. Only your message, anonymous book metadata and your latest order’s id/status/tracking are sent. Never your name, email, address or card details.'),
    ('Can the AI add books without asking?', 'No. Any add-to-cart or save action requires an explicit confirmation tap from you.'),
    ('Why does the AI sometimes say “offline mode”?', 'Either no Gemini key is configured, or the network/quota failed. The offline engine then answers so you always get a recommendation.'),
    ('How is my password stored?', 'As a salted SHA-256 hash on your device. Plain-text passwords are never stored.'),
    ('I forgot my password. What do I do?', 'Use “Forgot password”. A one-time code appears on screen (valid 30 minutes, single use) that you can use to set a new password.'),
    ('Where is my data stored?', 'Entirely on your device in a SQLite database. There is no cloud sync in this version.'),
    ('How much is shipping?', 'Shipping is \$2.99 on orders under \$30 and free on orders of \$30 or more.'),
    ('Is there a discount code?', 'Yes — use STUDENT10 at checkout for 10% off your order.'),
    ('Can I cancel an order?', 'Yes, while it is Placed or Processing. Once Shipped it can no longer be cancelled. Cancelling restores stock.'),
    ('How do I track my order?', 'Open You → My Orders → an order to see its live tracking timeline and tracking number.'),
    ('Can I get an invoice?', 'Yes. Open an order and tap the receipt icon to view a printable-style invoice.'),
    ('Are real card numbers stored?', 'Never. We store only the card brand, last 4 digits and expiry. The full number and CVV are not kept.'),
    ('Can I write reviews?', 'Yes. Sign in, open a book and tap “Write a review”. One review per book, editable, up to 600 characters.'),
    ('What is the reading list?', 'Your wishlist. Tap the heart on any book to save it, then move it to your cart when ready.'),
    ('Does Shelf work in dark mode?', 'Yes. Enable “Night reading mode” in Settings for a warm dark theme.'),
    ('Who built Shelf?', 'Shelf is an Aptech eProject built with Flutter, SQLite and an optional Gemini AI layer, with a custom “Folio” editorial design.'),
  ];

  @override
  Widget build(BuildContext context) {
    return FolioPage(
      title: 'Help & FAQ',
      kicker: 'Support',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Answers to the questions we hear most.', style: FolioText.italic(context)),
        const SizedBox(height: 16),
        for (final faq in _faqs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: context.f.card, border: Border.all(color: context.f.rule), borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              iconColor: context.f.accent,
              collapsedIconColor: context.f.muted,
              shape: const Border(),
              title: Text(faq.$1, style: FolioText.title(context)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(faq.$2, style: FolioText.bodySmall(context)))],
            ),
          ),
      ]),
    );
  }
}
