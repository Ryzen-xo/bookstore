import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';

/// About the project.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'About Shelf',
      kicker: 'The project',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 80, height: 80, decoration: BoxDecoration(color: f.ink, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.menu_book_rounded, color: f.paper, size: 40)),
        ),
        const SizedBox(height: 16),
        Center(child: Text('Shelf', style: FolioText.display(context))),
        Center(child: Text('THE EDITORIAL BOOKSHOP · v1.0.0', style: FolioText.label(context))),
        const SizedBox(height: 24),
        Text('Shelf is a complete, local-first bookshop built as an Aptech eProject. It pairs a distinctive “Folio” editorial design — warm paper, ink serif type and hand-drawn 3D covers — with a working AI librarian that runs online and offline.', style: FolioText.body(context)),
        const SizedBox(height: 20),
        _section(context, 'Built with', 'Flutter & Dart · SQLite (sqflite) · Provider · an on-device TF-IDF engine plus an optional Google Gemini layer. No network images, no downloaded fonts, no paid services.'),
        _section(context, 'Private by design', 'Your library lives on your device. Passwords are salted and hashed, payments are simulated (last 4 only), and the AI never receives your personal data.'),
        _section(context, 'Honest scope', 'Payments and social sign-in are demos. There is no cloud sync. The AI can make mistakes; prices and stock always come from the local database.'),
        const SizedBox(height: 12),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CREDITS', style: FolioText.label(context)),
            const SizedBox(height: 8),
            Text('Design system: “Folio”\nArchitecture: layered, repository pattern\nAI: Gemini + offline fallback\nTesting: 84 automated tests', style: FolioText.bodySmall(context)),
          ]),
        ),
        const SizedBox(height: 20),
        Center(child: Text('Made with care for readers.', style: FolioText.italic(context))),
      ]),
    );
  }

  Widget _section(BuildContext context, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: FolioText.label(context)),
          const SizedBox(height: 6),
          Text(body, style: FolioText.bodySmall(context)),
        ]),
      );
}
