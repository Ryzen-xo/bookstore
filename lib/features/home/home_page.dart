import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../browse/browse_page.dart';
import '../wishlist/wishlist_page.dart';

/// The magazine-style front page.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> _new = [];
  List<Book> _best = [];
  List<GenreInfo> _genres = [];
  Book? _featured;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppStateScope.read(context).repo;
    final fresh = await repo.newArrivals(limit: 6);
    final best = await repo.bestsellers(limit: 6);
    final genres = await repo.genres();
    if (!mounted) return;
    setState(() {
      _new = fresh;
      _best = best;
      _genres = genres;
      _featured = fresh.isNotEmpty ? fresh.first : (best.isNotEmpty ? best.first : null);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final state = AppStateScope.of(context);
    final body = _loading
        ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              // Masthead.
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SHELF · ${_season()}', style: FolioText.label(context)),
                  const SizedBox(height: 2),
                  Text(state.loggedIn ? 'Hello, ${state.user!.name.split(' ').first}' : 'The editorial bookshop', style: FolioText.h1(context)),
                ])),
                FolioIconButton(icon: Icons.favorite_border, label: 'Reading list', onTap: () => pushPage(context, const WishlistPage())),
              ]),
              const SizedBox(height: 20),
              // Featured.
              if (_featured != null) _featuredCard(context, _featured!),
              const SizedBox(height: 24),
              // Ask the librarian.
              Tappable(
                onTap: () => state.openLibrarian(),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: f.ink, borderRadius: BorderRadius.circular(FolioSpace.radius)),
                  child: Row(children: [
                    Icon(Icons.auto_awesome, color: f.paper, size: 28),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Not sure what to read?', style: FolioText.title(context).copyWith(color: f.paper)),
                      const SizedBox(height: 2),
                      Text('Ask the librarian — works offline', style: FolioText.caption(context).copyWith(color: f.paper.withValues(alpha: 0.7))),
                    ])),
                    Icon(Icons.arrow_forward, color: f.paper, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              // Genres.
              const FolioHeader(label: 'Browse', title: 'By genre'),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in _genres)
                  FolioChip(label: '${g.name} · ${g.count}', onTap: () => pushPage(context, BrowsePage(genreId: g.id, presetTitle: g.name))),
              ]),
              const SizedBox(height: 28),
              // New arrivals.
              FolioHeader(label: 'Just landed', title: 'New arrivals', trailing: TextButton(onPressed: () => pushPage(context, const BrowsePage(presetTitle: 'New arrivals')), child: Text('See all', style: TextStyle(color: f.accent)))),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _new.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => SizedBox(width: 155, child: BookCard(book: _new[i])),
                ),
              ),
              const SizedBox(height: 28),
              // Bestsellers shelf.
              const FolioHeader(label: 'Reader favourites', title: 'Bestsellers'),
              const SizedBox(height: 16),
              BookShelf(books: _best),
              // Recently viewed.
              if (state.recentlyViewed.isNotEmpty) ...[
                const SizedBox(height: 28),
                const FolioHeader(label: 'Your history', title: 'Recently viewed'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 290,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.recentlyViewed.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) => SizedBox(width: 150, child: BookCard(book: state.recentlyViewed[i], heroEnabled: false)),
                  ),
                ),
              ],
            ],
          );

    if (widget.embedded) return ContentWidth(child: body);
    return FolioPage(body: body, scrollable: false);
  }

  Widget _featuredCard(BuildContext context, Book book) {
    final f = context.f;
    final state = AppStateScope.read(context);
    return Tappable(
      onTap: () => state.openBook(context, book),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: f.card,
          borderRadius: BorderRadius.circular(FolioSpace.radius),
          border: Border.all(color: f.rule),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CoverArt(color: book.color(), title: book.title, author: book.author, width: 96),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StampBadge('New this week'),
            const SizedBox(height: 10),
            Text(book.title, style: FolioText.h3(context), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(book.author, style: FolioText.italic(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(book.description, style: FolioText.bodySmall(context).copyWith(color: f.muted), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Text(money(book.price), style: FolioText.title(context).copyWith(color: f.accent)),
          ])),
        ]),
      ),
    );
  }

  String _season() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) return 'SPRING';
    if (m >= 6 && m <= 8) return 'SUMMER';
    if (m >= 9 && m <= 11) return 'AUTUMN';
    return 'WINTER';
  }
}
