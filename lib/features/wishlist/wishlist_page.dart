import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// The reading list (wishlist).
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});
  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    final books = state.user == null ? <Book>[] : await state.repo.wishlist(state.user!.id);
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _moveToCart(Book b) async {
    final state = AppStateScope.read(context);
    try {
      await state.addToCart(b.id);
      await state.repo.toggleWishlist(state.user!.id, b.id);
      state.wishIds.remove(b.id);
      await _load();
      if (!mounted) return;
      showToast(context, 'Moved “${b.title}” to your cart.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return FolioPage(
      title: 'Reading list',
      kicker: 'Saved books',
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : !state.loggedIn
              ? EmptyState(icon: Icons.favorite_border, title: 'Sign in to save books', message: 'Your reading list lives on your device.', action: FolioButton(label: 'Sign in', style: FolioButtonStyle.accent, onPressed: () => state.openLogin()))
              : _books.isEmpty
                  ? EmptyState(icon: Icons.favorite_border, title: 'Nothing saved yet', message: 'Tap the heart on any book to save it here.')
                  : Column(children: [
                      for (final b in _books)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: BookCard(book: b, variant: BookCardVariant.row, heroEnabled: false)),
                            const SizedBox(width: 8),
                            Column(children: [
                              FolioIconButton(icon: Icons.add_shopping_cart, label: 'Move to cart', onTap: () => _moveToCart(b)),
                              const SizedBox(height: 8),
                              FolioIconButton(icon: Icons.delete_outline, label: 'Remove', onTap: () async {
                                await state.toggleWishlist(b.id);
                                await _load();
                              }),
                            ]),
                          ]),
                        ),
                    ]),
    );
  }
}
