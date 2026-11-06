import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../browse/browse_page.dart';
import 'review_sheet.dart';

/// Book details: parallax cover, stats, review histogram, reviews, similar
/// titles and a sticky buy bar.
class BookPage extends StatefulWidget {
  const BookPage({super.key, required this.bookId});
  final int bookId;
  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  Book? _book;
  List<Review> _reviews = [];
  List<int> _hist = List.filled(5, 0);
  List<Book> _similar = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    final book = await state.repo.bookById(widget.bookId);
    if (book == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final reviews = await state.repo.reviews(book.id, state.user?.id);
    final hist = await state.repo.ratingHistogram(book.id);
    final similar = await state.repo.similar(book);
    if (!mounted) return;
    state.rememberViewed(book);
    setState(() {
      _book = book;
      _reviews = reviews;
      _hist = hist;
      _similar = similar;
      _loading = false;
    });
  }

  Future<void> _addToCart() async {
    final state = AppStateScope.read(context);
    if (!requireLogin(context)) return;
    setState(() => _busy = true);
    try {
      await state.addToCart(_book!.id);
      if (!mounted) return;
      showToast(context, 'Added “${_book!.title}” to your cart.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeReview() async {
    final state = AppStateScope.read(context);
    if (!requireLogin(context)) return;
    final existing = _reviews.where((r) => r.userId == state.user!.id).firstOrNull;
    final saved = await showFolioSheet<bool>(context, child: ReviewSheet(book: _book!, existing: existing));
    if (saved == true) await _load();
  }

  Future<void> _like(Review r) async {
    final state = AppStateScope.read(context);
    if (!requireLogin(context)) return;
    await state.repo.toggleLike(r.id, state.user!.id);
    final reviews = await state.repo.reviews(_book!.id, state.user?.id);
    if (!mounted) return;
    setState(() => _reviews = reviews);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    if (_loading) {
      return const FolioPage(title: 'Book', body: Center(child: Padding(padding: EdgeInsets.all(40), child: ThinkingDots())));
    }
    final book = _book;
    if (book == null) {
      return FolioPage(title: 'Book', body: EmptyState(icon: Icons.menu_book_outlined, title: 'Not found', message: 'This title is no longer available.'));
    }
    final state = AppStateScope.of(context);
    final wished = state.wishIds.contains(book.id);
    final avg = book.avgRating;

    return Scaffold(
      backgroundColor: f.paper,
      bottomNavigationBar: _buyBar(context, book, wished),
      body: PaperBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: f.paper,
                pinned: true,
                expandedHeight: 340,
                leading: IconButton(icon: Icon(Icons.arrow_back, color: f.ink), onPressed: () => Navigator.of(context).maybePop()),
                actions: [
                  IconButton(
                    icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? f.accent : f.ink),
                    onPressed: () => state.toggleWishlist(book.id),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [book.color().withValues(alpha: 0.16), f.paper])),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: CoverArt(color: book.color(), title: book.title, author: book.author, width: 165, heroTag: 'cover-${book.id}'),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          StampBadge(book.genre, color: f.gold),
                          if (book.sold >= 1000) StampBadge('Bestseller'),
                          if (!book.inStock) StampBadge('Sold out', color: f.danger) else if (book.lowStock) StampBadge('Only ${book.stock} left', color: f.warning),
                        ]),
                        const SizedBox(height: 14),
                        Text(book.title, style: FolioText.h1(context)),
                        const SizedBox(height: 6),
                        Text('by ${book.author}', style: FolioText.italic(context)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          StarRating(value: avg, size: 18),
                          Text(avg > 0 ? '${avg.toStringAsFixed(1)} · ${book.ratingCount} reviews' : 'No reviews yet', style: FolioText.caption(context)),
                        ]),
                        const SizedBox(height: 20),
                        _stats(context, book),
                        const SizedBox(height: 20),
                        Text('ABOUT THIS BOOK', style: FolioText.label(context)),
                        const SizedBox(height: 8),
                        Text(book.description, style: FolioText.body(context)),
                        const SizedBox(height: 28),
                        FolioHeader(label: 'Reviews', title: 'What readers say', trailing: TextButton(onPressed: _writeReview, child: Text('Write a review', style: TextStyle(color: f.accent)))),
                        const SizedBox(height: 16),
                        if (_reviews.isNotEmpty) ...[
                          PaperCard(child: RatingBars(histogram: _hist)),
                          const SizedBox(height: 16),
                          ..._reviews.map((r) => _reviewTile(context, r)),
                        ] else
                          Text('Be the first to review this book.', style: FolioText.italic(context)),
                        if (_similar.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const FolioHeader(label: 'More like this', title: 'Similar books'),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 290,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _similar.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, i) => SizedBox(width: 150, child: BookCard(book: _similar[i], heroEnabled: false)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () => pushPage(context, BrowsePage(genreId: book.genreId, presetTitle: book.genre)),
                            child: Text('Browse all ${book.genre}', style: TextStyle(color: f.accent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats(BuildContext context, Book book) {
    Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: FolioText.label(context)),
            const SizedBox(height: 4),
            Text(value, style: FolioText.title(context)),
          ],
        );
    return PaperCard(
      child: Wrap(spacing: 28, runSpacing: 16, children: [
        stat('Pages', '${book.pages}'),
        stat('Published', book.published.length >= 4 ? book.published.substring(0, 4) : book.published),
        stat('Genre', book.genre),
        stat('Availability', book.inStock ? '${book.stock} in stock' : 'Out of stock'),
      ]),
    );
  }

  Widget _reviewTile(BuildContext context, Review r) {
    final f = context.f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.userName, style: FolioText.title(context))),
            StarRating(value: r.rating.toDouble(), size: 14),
          ]),
          const SizedBox(height: 8),
          Text(r.body, style: FolioText.bodySmall(context)),
          const SizedBox(height: 10),
          Row(children: [
            Text(niceDate(r.createdAt), style: FolioText.caption(context)),
            const Spacer(),
            Tappable(
              onTap: () => _like(r),
              semanticLabel: 'Like review',
              child: Row(children: [
                Icon(r.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: r.likedByMe ? f.accent : f.muted),
                const SizedBox(width: 4),
                Text('${r.likes}', style: FolioText.caption(context)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buyBar(BuildContext context, Book book, bool wished) {
    final f = context.f;
    return Container(
      decoration: BoxDecoration(color: f.card, border: Border(top: BorderSide(color: f.rule))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('PRICE', style: FolioText.label(context)),
              Text(money(book.price), style: FolioText.h3(context).copyWith(color: f.accent)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: FolioButton(
                label: _busy ? 'Adding…' : (book.inStock ? 'Add to cart' : 'Sold out'),
                icon: Icons.shopping_bag_outlined,
                style: FolioButtonStyle.accent,
                expand: true,
                onPressed: book.inStock && !_busy ? _addToCart : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
