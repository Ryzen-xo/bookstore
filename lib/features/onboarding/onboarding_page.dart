import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../state/app_state.dart';
import '../shell/shell_page.dart';

/// Three editorial onboarding cards.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (Icons.auto_stories_outlined, 'A shop that feels like paper', 'Warm pages, ink serif type and hand-drawn covers. Browse 46 real books across 12 genres.'),
    (Icons.auto_awesome, 'Meet your AI librarian', 'Ask for a mood, a budget or a book you loved. It works online with Gemini and always falls back to an on-device engine.'),
    (Icons.lock_outline, 'Private and offline-first', 'Your library lives on your device. Payments are simulated and we never send your personal data to the AI.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await AppStateScope.read(context).markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellPage()));
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Scaffold(
      backgroundColor: f.paper,
      body: PaperBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: Text('Skip', style: TextStyle(color: f.muted))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(color: f.accentSoft, shape: BoxShape.circle),
                        child: Icon(p.$1, size: 44, color: f.accent),
                      ),
                      const SizedBox(height: 32),
                      Text(p.$2, style: FolioText.h1(context), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Text(p.$3, style: FolioText.body(context).copyWith(color: f.muted), textAlign: TextAlign.center),
                    ]),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == _index ? f.accent : f.rule, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: FolioButton(
                label: _index == _pages.length - 1 ? 'Enter Shelf' : 'Next',
                style: FolioButtonStyle.accent,
                expand: true,
                onPressed: () {
                  if (_index == _pages.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
