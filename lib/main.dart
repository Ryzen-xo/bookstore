import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/tokens.dart';
import 'state/app_state.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Global error handlers: log in debug, show a friendly screen in release.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
    ErrorWidget.builder = (details) => const _FriendlyError();

    final state = AppState();
    runApp(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const ShelfApp(),
      ),
    );
    // Open the DB / seed after the first frame so the splash can animate.
    unawaited(state.init());
  }, (error, stack) {
    if (kDebugMode) debugPrint('[Uncaught] $error\n$stack');
  });
}

/// A calm, on-brand fallback if a widget throws during build.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError();
  @override
  Widget build(BuildContext context) {
    // Use the light tokens directly so this works even if the theme is missing.
    const c = FolioColors.light;
    return Material(
      color: c.paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Shelf', style: TextStyle(fontFamily: 'serif', fontFamilyFallback: kSerifFallback, fontSize: 40, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 12),
              Text(
                'Something went wrong on this page. Please go back and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
