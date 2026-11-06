import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../state/app_state.dart';
import '../onboarding/onboarding_page.dart';
import '../shell/shell_page.dart';

/// Animated brand splash that waits for the database, then routes onward.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateScope.of(context).addListener(_maybeGo);
      _maybeGo();
    });
  }

  void _maybeGo() {
    if (!mounted || _navigated) return;
    final state = AppStateScope.read(context);
    if (!state.initialized) return;
    _navigated = true;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final next = state.onboardingSeen ? const ShellPage() : const OnboardingPage();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Scaffold(
      backgroundColor: f.paper,
      body: PaperBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = Curves.easeOut.transform(_c.value);
              return Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: f.ink, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.menu_book_rounded, color: f.paper, size: 44),
                    ),
                    const SizedBox(height: 20),
                    Text('Shelf', style: FolioText.display(context)),
                    const SizedBox(height: 6),
                    Text('THE EDITORIAL BOOKSHOP', style: FolioText.label(context)),
                    const SizedBox(height: 32),
                    const ThinkingDots(),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
