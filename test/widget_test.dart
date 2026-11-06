import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shelf/core/theme/tokens.dart';
import 'package:shelf/core/widgets/common.dart';
import 'package:shelf/data/models.dart';
import 'package:shelf/features/auth/auth_page.dart';
import 'package:shelf/state/app_state.dart';

Book _book() => const Book(
      id: 1,
      title: 'The Long and Winding Road Through the Shire',
      author: 'A Very Prolific Author Name',
      authorId: 1,
      genreId: 1,
      genre: 'Fantasy',
      description: 'A cozy tale.',
      price: 12.99,
      pages: 320,
      published: '2020-01-01',
      stock: 7,
      sold: 1200,
      coverColor: '#3E6B4A',
      tags: 'cozy,classic',
      createdAt: '2026-01-01 00:00:00',
      avgRating: 4.5,
      ratingCount: 12,
    );

/// For full pages that already contain their own Scaffold (e.g. AuthPage).
Widget _wrapPage(Widget page, {double textScale = 1.0}) {
  return ChangeNotifierProvider<AppState>.value(
    value: AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildFolioTheme(Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: page,
        ),
      ),
    ),
  );
}

/// For individual widgets that need a Material/Scaffold ancestor.
Widget _wrapWidget(Widget child, {double textScale = 1.0}) {
  return ChangeNotifierProvider<AppState>.value(
    value: AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildFolioTheme(Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(backgroundColor: context.f.paper, body: SafeArea(child: child)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('login form shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(_wrapPage(const AuthPage()));
    await tester.pump();

    // Tap the primary "Sign in" button with empty fields.
    await tester.tap(find.text('Sign in').first, warnIfMissed: false);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('login form rejects a malformed email', (tester) async {
    await tester.pumpWidget(_wrapPage(const AuthPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in').first, warnIfMissed: false);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('BookCard renders at 100% text scale without overflow', (tester) async {
    await tester.pumpWidget(_wrapWidget(
      SingleChildScrollView(child: Center(child: SizedBox(width: 180, child: BookCard(book: _book())))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    // The title appears on the cover and on the card — at least one is present.
    expect(find.text('The Long and Winding Road Through the Shire'), findsWidgets);
  });

  testWidgets('BookCard renders at 200% text scale without overflow', (tester) async {
    await tester.pumpWidget(_wrapWidget(
      SingleChildScrollView(child: Center(child: SizedBox(width: 200, child: BookCard(book: _book())))),
      textScale: 2.0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // No RenderFlex overflow or other layout exception should be thrown.
    expect(tester.takeException(), isNull);
  });

  testWidgets('BookCard row variant renders at 200% text scale without overflow', (tester) async {
    await tester.pumpWidget(_wrapWidget(
      SingleChildScrollView(child: SizedBox(width: 360, child: BookCard(book: _book(), variant: BookCardVariant.row))),
      textScale: 2.0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('StarRating displays and accepts input', (tester) async {
    int? changed;
    await tester.pumpWidget(_wrapWidget(
      Center(child: StarRating(value: 0, size: 32, onChanged: (v) => changed = v)),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(2), warnIfMissed: false);
    await tester.pump();
    expect(changed, 3);
  });
}
