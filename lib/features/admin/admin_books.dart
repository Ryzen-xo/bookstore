import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Admin: list, add, edit, delete books.
class AdminBooksPage extends StatefulWidget {
  const AdminBooksPage({super.key});
  @override
  State<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends State<AdminBooksPage> {
  List<Book> _books = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final books = await AppStateScope.read(context).repo.books(q: _search.text.trim().isEmpty ? null : _search.text.trim(), sort: 'title');
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _delete(Book b) async {
    final ok = await confirmDialog(context, title: 'Delete “${b.title}”?', message: 'Books that appear in past orders cannot be deleted.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    try {
      await AppStateScope.read(context).repo.deleteBook(b.id);
      await _load();
      if (!mounted) return;
      showToast(context, 'Book deleted.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'Books',
      kicker: 'Admin',
      floating: FloatingActionButton.extended(backgroundColor: f.accent, foregroundColor: Colors.white, onPressed: () => pushPage(context, const AdminBookFormPage()).then((v) { if (v == true) _load(); }), icon: const Icon(Icons.add), label: const Text('Add book')),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _search,
          onChanged: (_) => _load(),
          style: FolioText.body(context),
          cursorColor: f.accent,
          decoration: InputDecoration(hintText: 'Search books…', prefixIcon: Icon(Icons.search, color: f.muted), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: f.rule), borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: f.accent), borderRadius: BorderRadius.circular(12))),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: ThinkingDots()))
        else
          ..._books.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PaperCard(
                  child: Row(children: [
                    CoverArt(color: b.color(), title: b.title, author: b.author, width: 42),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.title, style: FolioText.title(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${b.author} · ${money(b.price)} · stock ${b.stock}', style: FolioText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    IconButton(icon: Icon(Icons.edit_outlined, size: 19, color: f.muted), onPressed: () => pushPage(context, AdminBookFormPage(existing: b)).then((v) { if (v == true) _load(); })),
                    IconButton(icon: Icon(Icons.delete_outline, size: 19, color: f.danger), onPressed: () => _delete(b)),
                  ]),
                ),
              )),
        const SizedBox(height: 70),
      ]),
    );
  }
}

/// Add / edit a book.
class AdminBookFormPage extends StatefulWidget {
  const AdminBookFormPage({super.key, this.existing});
  final Book? existing;
  @override
  State<AdminBookFormPage> createState() => _AdminBookFormPageState();
}

class _AdminBookFormPageState extends State<AdminBookFormPage> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _author = TextEditingController(text: widget.existing?.author ?? '');
  late final _genre = TextEditingController(text: widget.existing?.genre ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(text: widget.existing?.price.toString() ?? '');
  late final _pages = TextEditingController(text: widget.existing?.pages.toString() ?? '');
  late final _published = TextEditingController(text: widget.existing?.published ?? '');
  late final _stock = TextEditingController(text: widget.existing?.stock.toString() ?? '10');
  late final _tags = TextEditingController(text: widget.existing?.tags ?? '');
  late String _color = widget.existing?.coverColor ?? '#B5732E';
  bool _busy = false;

  static const _swatches = ['#B5732E', '#2E5E8C', '#3E6B4A', '#7A2E3B', '#2B2B2B', '#C0563B'];

  @override
  void dispose() {
    for (final c in [_title, _author, _genre, _desc, _price, _pages, _published, _stock, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _author.text.trim().isEmpty || _genre.text.trim().isEmpty) {
      showToast(context, 'Title, author and genre are required.');
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      showToast(context, 'Enter a valid price.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppStateScope.read(context).repo.saveBook(
        id: widget.existing?.id,
        title: _title.text.trim(), author: _author.text.trim(), genre: _genre.text.trim(), description: _desc.text.trim(),
        price: price, pages: int.tryParse(_pages.text.trim()) ?? 0, published: _published.text.trim(),
        stock: int.tryParse(_stock.text.trim()) ?? 0, coverColor: _color, tags: _tags.text.trim(),
      );
      if (!mounted) return;
      showToast(context, 'Book saved.');
      Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: widget.existing == null ? 'Add book' : 'Edit book',
      kicker: 'Admin',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: CoverArt(color: parseHexColor(_color), title: _title.text.isEmpty ? 'Title' : _title.text, author: _author.text.isEmpty ? 'Author' : _author.text, width: 110)),
        const SizedBox(height: 16),
        Text('COVER COLOUR', style: FolioText.label(context)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          for (final s in _swatches)
            Tappable(
              onTap: () => setState(() => _color = s),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: parseHexColor(s), shape: BoxShape.circle, border: Border.all(color: _color == s ? f.ink : f.rule, width: _color == s ? 3 : 1))),
            ),
        ]),
        const SizedBox(height: 16),
        FolioField(controller: _title, label: 'Title'),
        const SizedBox(height: 14),
        FolioField(controller: _author, label: 'Author'),
        const SizedBox(height: 14),
        FolioField(controller: _genre, label: 'Genre', hint: 'e.g. Fantasy'),
        const SizedBox(height: 14),
        FolioField(controller: _desc, label: 'Description', maxLines: 4),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FolioField(controller: _price, label: 'Price', keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: FolioField(controller: _pages, label: 'Pages', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FolioField(controller: _published, label: 'Published', hint: '2021-05-04')),
          const SizedBox(width: 12),
          Expanded(child: FolioField(controller: _stock, label: 'Stock', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 14),
        FolioField(controller: _tags, label: 'Tags', hint: 'comma,separated,tags'),
        const SizedBox(height: 24),
        FolioButton(label: _busy ? 'Saving…' : 'Save book', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _save),
      ]),
    );
  }
}
