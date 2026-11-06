import 'package:flutter/material.dart';

import 'core/theme/tokens.dart';
import 'core/widgets/folio_widgets.dart';
import 'features/ai/gemini_service.dart';

/// A standalone gallery to verify the Folio look and the Gemini connection
/// before the rest of the app. Run with:
///   flutter run -t lib/main_gallery.dart --dart-define=GEMINI_API_KEY=your_key
void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});
  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  ThemeMode _mode = ThemeMode.light;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf · Gallery',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: buildFolioTheme(Brightness.light),
      darkTheme: buildFolioTheme(Brightness.dark),
      home: GalleryPage(onToggleTheme: () => setState(() => _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light)),
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _service = GeminiService();
  final _ask = TextEditingController();
  String _answer = '';
  bool _busy = false;
  int _navIndex = 0;

  static const _samples = [
    ('#B5732E', 'Dune', 'Frank Herbert'),
    ('#2E5E8C', 'Project Hail Mary', 'Andy Weir'),
    ('#3E6B4A', 'The Hobbit', 'J.R.R. Tolkien'),
    ('#7A2E3B', 'Harry Potter', 'J.K. Rowling'),
    ('#2B2B2B', 'Gone Girl', 'Gillian Flynn'),
  ];

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  Future<void> _askLibrarian() async {
    if (_ask.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _answer = '';
    });
    final candidates = [
      for (var i = 0; i < _samples.length; i++)
        {'id': i + 1, 'title': _samples[i].$2, 'author': _samples[i].$3, 'genre': 'Fiction', 'price': 12.99, 'pages': 320, 'rating': 4.5, 'inStock': true, 'tags': 'classic', 'blurb': 'A beloved book.'}
    ];
    final reply = await _service.ask(history: const [], userText: _ask.text, candidates: candidates, storeFacts: 'Shipping 3-5 days. Coupon STUDENT10.');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answer = reply?.reply ?? 'Offline fallback: I can recommend ${_samples[0].$2} and ${_samples[2].$2}. (${_service.lastError ?? "no key"})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Scaffold(
      backgroundColor: f.paper,
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                Expanded(child: RevealText('Folio gallery', style: FolioText.h1(context))),
                FolioIconButtonGallery(icon: Icons.dark_mode_outlined, onTap: widget.onToggleTheme),
              ]),
              const SizedBox(height: 8),
              Text('Warm paper · ink serif · one vermilion accent', style: FolioText.italic(context)),
              const SizedBox(height: 24),
              const FolioHeader(label: 'Covers', title: '3D hardcovers'),
              const SizedBox(height: 16),
              CoverCarousel(
                height: 280,
                itemCount: _samples.length,
                itemBuilder: (ctx, i) => CoverArt(color: _color(_samples[i].$1), title: _samples[i].$2, author: _samples[i].$3, width: 140),
              ),
              const SizedBox(height: 24),
              const FolioHeader(label: 'Badges', title: 'Stamps'),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: const [
                StampBadge('New'),
                StampBadge('Bestseller'),
                StampBadge('Only 3 left'),
                StampBadge('Delivered'),
              ]),
              const SizedBox(height: 24),
              const FolioHeader(label: 'Buttons', title: 'Three styles'),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FolioButton(label: 'Ink', onPressed: () {}),
                FolioButton(label: 'Accent', style: FolioButtonStyle.accent, onPressed: () {}),
                FolioButton(label: 'Outline', style: FolioButtonStyle.outline, onPressed: () {}),
              ]),
              const SizedBox(height: 24),
              const FolioHeader(label: 'AI', title: 'Ask the Librarian'),
              const SizedBox(height: 12),
              Text(_service.configured ? 'Gemini is configured.' : 'No key set — the fallback will answer. Pass --dart-define=GEMINI_API_KEY=… to go online.', style: FolioText.caption(context)),
              const SizedBox(height: 12),
              TextField(
                controller: _ask,
                style: FolioText.body(context),
                cursorColor: f.accent,
                decoration: InputDecoration(
                  hintText: 'Something cozy under \$12',
                  hintStyle: FolioText.italic(context),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.accent)),
                ),
                onSubmitted: (_) => _askLibrarian(),
              ),
              const SizedBox(height: 12),
              FolioButton(label: _busy ? 'Thinking…' : 'Ask', style: FolioButtonStyle.accent, onPressed: _busy ? null : _askLibrarian),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: ThinkingDots()),
              if (_answer.isNotEmpty) ...[
                const SizedBox(height: 16),
                PaperCard(child: TypewriterText(_answer, style: FolioText.body(context))),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FolioNavBar(
        index: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          FolioNavItem(Icons.home_outlined, 'Home'),
          FolioNavItem(Icons.search, 'Browse'),
          FolioNavItem(Icons.auto_awesome, 'AI', center: true),
          FolioNavItem(Icons.shopping_bag_outlined, 'Cart', badge: 2),
          FolioNavItem(Icons.person_outline, 'You'),
        ],
      ),
    );
  }

  Color _color(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

class FolioIconButtonGallery extends StatelessWidget {
  const FolioIconButtonGallery({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      semanticLabel: 'Toggle theme',
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: context.f.rule), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: context.f.ink),
      ),
    );
  }
}
