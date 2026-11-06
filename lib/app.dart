import 'package:flutter/material.dart';

import 'core/theme/tokens.dart';
import 'features/splash/splash_page.dart';
import 'state/app_state.dart';

/// Root widget: a themed MaterialApp driven by [AppState].
class ShelfApp extends StatelessWidget {
  const ShelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return MaterialApp(
      title: 'Shelf',
      debugShowCheckedModeBanner: false,
      navigatorKey: state.navigatorKey,
      themeMode: state.themeMode,
      theme: buildFolioTheme(Brightness.light),
      darkTheme: buildFolioTheme(Brightness.dark),
      home: const SplashPage(),
      builder: (context, child) {
        // Clamp text scale so the editorial layout survives up to 200%.
        final mq = MediaQuery.of(context);
        final scale = mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 2.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
