import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

enum _View { grid, list, shelf }

/// Browse / search the catalogue with sorts, filters and three views.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, this.genreId, this.authorId, this.presetTitle, this.embedded = false});
  final int? genreId;
  final int? authorId;
  final String? presetTitle;
  final bool embedded;
  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Book> _books = [];
  List<GenreInfo> _genres = [];
  List<String> _suggestions = [];
  String _sort = 'popular';
  _View _view = _View.grid;
  int? _genreId;
  double? _maxPrice;
  bool _inStock = false;
  bool _loading = true;

  static const _sorts = {
    'popular': 'Most popular',
    'price_asc': 'Price: low to high',
    'price_desc': 'Price: high to low',
    'release': 'Newest first',
    'rating': 'Top rated',
  };

  @override
  void initState() {
    super.initState();
    _genreId = widget.genreId;
    _loadGenres();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    final genres = await AppStateScope.read(context).repo.genres();
    if (!mounted) return;
    setState(() => _genres = genres);
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final repo = AppStateScope.read(context).repo;
    final books = await repo.books(
      q: _search.text.trim().isEmpty ? null : _search.text.trim(),
      sort: _sort,
      genreId: _genreId,
      authorId: widget.authorId,
      maxPrice: _maxPrice,
      inStockOnly: _inStock,
    );
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final repo = AppStateScope.read(context).repo;
      final s = await repo.suggest(v);
      if (!mounted) return;
      setState(() => _suggestions = s);
      _run();
    });
  }

  Future<void> _filters() async {
    final f = context.f;
    await showFolioSheet(context, child: StatefulBuilder(builder: (context, setSheet) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Filters', style: FolioText.h2(context)),
        const SizedBox(height: 16),
        Text('GENRE', style: FolioText.label(context)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FolioChip(label: 'All', selected: _genreId == null, onTap: () => setSheet(() => _genreId = null)),
          ..._genres.map((g) => FolioChip(label: g.name, selected: _genreId == g.id, onTap: () => setSheet(() => _genreId = g.id))),
        ]),
        const SizedBox(height: 20),
        Text('MAX PRICE: ${_maxPrice == null ? 'Any' : money(_maxPrice!)}', style: FolioText.label(context)),
        Slider(value: _maxPrice ?? 40, min: 5, max: 40, divisions: 7, activeColor: f.accent, label: _maxPrice == null ? 'Any' : money(_maxPrice!), onChanged: (v) => setSheet(() => _maxPrice = v >= 40 ? null : v)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: f.accent,
          title: Text('In stock only', style: FolioText.body(context)),
          value: _inStock,
          onChanged: (v) => setSheet(() => _inStock = v),
        ),
        const SizedBox(height: 16),
        FolioButton(label: 'Apply filters', style: FolioButtonStyle.accent, expand: true, onPressed: () {
          Navigator.of(context).pop();
          _run();
        }),
      ]);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final title = widget.presetTitle ?? 'Browse';
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search.
      TextField(
        controller: _search,
        onChanged: _onSearch,
        style: FolioText.body(context),
        cursorColor: f.accent,
        decoration: InputDecoration(
          hintText: 'Search titles, authors, genres…',
          hintStyle: FolioText.italic(context).copyWith(color: f.faint),
          prefixIcon: Icon(Icons.search, color: f.muted),
          suffixIcon: _search.text.isEmpty ? null : IconButton(icon: Icon(Icons.close, color: f.muted, size: 18), onPressed: () {
            _search.clear();
            setState(() => _suggestions = []);
            _run();
          }),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: f.rule), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: f.accent), borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ..._suggestions.take(6).map((s) => FolioChip(label: s, onTap: () {
              _search.text = s;
              setState(() => _suggestions = []);
              _run();
            })),
          ]),
        ),
      const SizedBox(height: 14),
      // Controls.
      Row(children: [
        Expanded(
          child: Tappable(
            onTap: _filters,
            semanticLabel: 'Filters',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [Icon(Icons.tune, size: 18, color: f.ink), const SizedBox(width: 6), Text('Filters', style: FolioText.caption(context).copyWith(color: f.ink))]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _sortMenu(context)),
        const SizedBox(width: 8),
        _viewToggle(context),
      ]),
      const SizedBox(height: 16),
      Text('${_books.length} ${_books.length == 1 ? 'book' : 'books'}', style: FolioText.caption(context)),
      const SizedBox(height: 12),
      if (_loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: ThinkingDots()))
      else if (_books.isEmpty)
        EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different search or clear your filters.', action: FolioButton(label: 'Clear filters', style: FolioButtonStyle.outline, onPressed: () {
          setState(() { _genreId = null; _maxPrice = null; _inStock = false; _search.clear(); });
          _run();
        }))
      else
        _results(context),
    ]);

    if (widget.embedded) {
      return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: ContentWidth(child: body));
    }
    return FolioPage(title: title, kicker: 'Catalogue', body: body);
  }

  Widget _sortMenu(BuildContext context) {
    final f = context.f;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          isExpanded: true,
          icon: Icon(Icons.expand_more, size: 18, color: f.ink),
          dropdownColor: f.card,
          style: FolioText.caption(context).copyWith(color: f.ink),
          items: _sorts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _sort = v);
              _run();
            }
          },
        ),
      ),
    );
  }

  Widget _viewToggle(BuildContext context) {
    final f = context.f;
    Widget btn(_View v, IconData icon) => Tappable(
          onTap: () => setState(() => _view = v),
          semanticLabel: v.name,
          child: Container(
            width: 38,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _view == v ? f.ink : Colors.transparent, border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: _view == v ? f.paper : f.ink),
          ),
        );
    return Row(children: [btn(_View.grid, Icons.grid_view), const SizedBox(width: 4), btn(_View.list, Icons.view_list), const SizedBox(width: 4), btn(_View.shelf, Icons.shelves)]);
  }

  Widget _results(BuildContext context) {
    if (_view == _View.shelf) {
      return BookShelf(books: _books);
    }
    if (_view == _View.list) {
      return Column(children: [
        for (final b in _books) Padding(padding: const EdgeInsets.only(bottom: 16), child: BookCard(book: b, variant: BookCardVariant.row)),
      ]);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 560 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 24, childAspectRatio: 0.56),
        itemCount: _books.length,
        itemBuilder: (context, i) => BookCard(book: _books[i]),
      );
    });
  }
}
