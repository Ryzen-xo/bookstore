import 'dart:math';

import '../../data/models.dart';

/// Parsed natural-language constraints for a recommendation request.
class QueryConstraints {
  QueryConstraints({
    this.maxPrice,
    this.minPrice,
    this.maxPages,
    this.minPages,
    this.genre,
    this.tags = const [],
    this.author,
    this.likeTitle,
    this.bestseller = false,
    this.fresh = false,
    this.classic = false,
    this.inStock = false,
    this.cheaper = false,
    this.shorter = false,
    this.excludeShown = false,
    this.sameAuthor = false,
  });

  double? maxPrice;
  double? minPrice;
  int? maxPages;
  int? minPages;
  String? genre;
  List<String> tags;
  String? author;
  String? likeTitle;
  bool bestseller;
  bool fresh;
  bool classic;
  bool inStock;
  bool cheaper;
  bool shorter;
  bool excludeShown;
  bool sameAuthor;

  QueryConstraints copy() => QueryConstraints(
        maxPrice: maxPrice, minPrice: minPrice, maxPages: maxPages, minPages: minPages,
        genre: genre, tags: List.of(tags), author: author, likeTitle: likeTitle,
        bestseller: bestseller, fresh: fresh, classic: classic, inStock: inStock,
      );

  bool get hasAny =>
      maxPrice != null || minPrice != null || maxPages != null || minPages != null ||
      genre != null || tags.isNotEmpty || author != null || likeTitle != null ||
      bestseller || fresh || classic || inStock;
}

/// The result of an offline turn.
class OfflineReply {
  OfflineReply({required this.text, required this.books, required this.whyById});
  final String text;
  final List<Book> books;
  final Map<int, String> whyById;
}

/// A fully on-device recommendation engine: weighted TF-IDF + hard constraints
/// + simple conversation state. No network, no PII. Always available.
class OfflineEngine {
  OfflineEngine(List<Book> books) {
    setBooks(books);
  }

  List<Book> _books = [];
  final Map<int, Map<String, double>> _vectors = {};
  final Map<String, double> _idf = {};
  double _maxSold = 1;

  // Conversation state.
  QueryConstraints? _last;
  List<Book> _lastBooks = [];
  final Set<int> _shown = {};

  static const _stop = {
    'a', 'an', 'the', 'something', 'some', 'book', 'books', 'read', 'me', 'i', 'want',
    'looking', 'for', 'please', 'give', 'show', 'find', 'recommend', 'recommendation',
    'to', 'of', 'and', 'or', 'with', 'under', 'over', 'below', 'above', 'less', 'than',
    'more', 'dollars', 'dollar', 'pages', 'page', 'by', 'like', 'similar', 'new', 'cheap',
    'short', 'long', 'is', 'are', 'my', 'your', 'that', 'this', 'it', 'in', 'on', 'at',
    'good', 'great', 'nice', 'best', 'top', 'any', 'can', 'you', 'suggest',
  };

  void setBooks(List<Book> books) {
    _books = books;
    _vectors.clear();
    _idf.clear();
    _maxSold = books.fold<int>(1, (m, b) => max(m, b.sold)).toDouble();
    final df = <String, int>{};
    for (final b in books) {
      final tf = _termFreq(b);
      _vectors[b.id] = tf;
      for (final t in tf.keys) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = books.length;
    df.forEach((t, count) {
      _idf[t] = log((n + 1) / (count + 1)) + 1;
    });
  }

  void reset() {
    _last = null;
    _lastBooks = [];
    _shown.clear();
  }

  List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && t.length > 1 && !_stop.contains(t))
      .toList();

  Map<String, double> _termFreq(Book b) {
    final tf = <String, double>{};
    void add(String text, double weight) {
      for (final t in _tokens(text)) {
        tf[t] = (tf[t] ?? 0) + weight;
      }
    }
    add(b.title, 3);
    add('${b.author} ${b.genre} ${b.tags}', 2);
    add(b.description, 1);
    return tf;
  }

  double _cosine(Map<String, double> query, Map<String, double> doc) {
    var dot = 0.0, qn = 0.0, dn = 0.0;
    query.forEach((t, w) {
      final idf = _idf[t] ?? 0;
      final qw = w * idf;
      qn += qw * qw;
      final dw = (doc[t] ?? 0) * idf;
      dot += qw * dw;
    });
    doc.forEach((t, w) {
      final dw = w * (_idf[t] ?? 0);
      dn += dw * dw;
    });
    if (qn == 0 || dn == 0) return 0;
    return dot / (sqrt(qn) * sqrt(dn));
  }

  // ---------------- parsing ----------------
  QueryConstraints parse(String text) {
    final t = text.toLowerCase();
    final c = QueryConstraints();

    // Price.
    final under = RegExp(r'(?:under|below|less than|max|up to|cheaper than)\s*\$?\s*(\d+(?:\.\d+)?)').firstMatch(t);
    if (under != null) c.maxPrice = double.parse(under.group(1)!);
    final over = RegExp(r'(?:over|above|more than|at least)\s*\$?\s*(\d+(?:\.\d+)?)').firstMatch(t);
    if (over != null && !t.contains('pages')) c.minPrice = double.parse(over.group(1)!);
    if (t.contains('cheap') || t.contains('budget') || t.contains('affordable')) c.maxPrice ??= 12;

    // Pages.
    final underPages = RegExp(r'(?:under|below|less than)\s*(\d+)\s*pages').firstMatch(t);
    if (underPages != null) c.maxPages = int.parse(underPages.group(1)!);
    final overPages = RegExp(r'(?:over|above|more than)\s*(\d+)\s*pages').firstMatch(t);
    if (overPages != null) c.minPages = int.parse(overPages.group(1)!);
    if (RegExp(r'\bshort\b|\bquick\b|\bnovella\b').hasMatch(t)) c.maxPages ??= 300;
    if (RegExp(r'\blong\b|\bepic\b|\bdoorstop\b').hasMatch(t)) c.minPages ??= 450;

    // Genre (order matters: sci-fi before science).
    if (RegExp(r'sci[\s-]?fi|science fiction').hasMatch(t)) {
      c.genre = 'Science Fiction';
    } else if (t.contains('fantasy')) {
      c.genre = 'Fantasy';
    } else if (t.contains('thriller')) {
      c.genre = 'Thriller';
    } else if (t.contains('mystery') || t.contains('whodunit') || t.contains('detective')) {
      c.genre = 'Mystery';
    } else if (t.contains('romance') || t.contains('love story')) {
      c.genre = 'Romance';
    } else if (t.contains('history') || t.contains('historical')) {
      c.genre = 'History';
    } else if (RegExp(r'programming|coding|\btech\b|technology|software|computer').hasMatch(t)) {
      c.genre = 'Technology';
    } else if (RegExp(r'self[\s-]?help|productivity|habits').hasMatch(t)) {
      c.genre = 'Self-Help';
    } else if (t.contains('biography') || t.contains('memoir') || t.contains('life story')) {
      c.genre = 'Biography';
    } else if (RegExp(r'\bscience\b|physics|cosmos|biology').hasMatch(t)) {
      c.genre = 'Science';
    } else if (t.contains('fiction')) {
      c.genre = 'Fiction';
    }

    // Mood → tags.
    final tags = <String>[];
    if (t.contains('cozy') || t.contains('cosy') || t.contains('comfort')) tags.add('cozy');
    if (t.contains('funny') || t.contains('humor') || t.contains('humour') || t.contains('comedy')) tags.add('funny');
    if (t.contains('dark') || t.contains('twisted') || t.contains('gritty')) tags.add('dark');
    if (t.contains('inspiring') || t.contains('uplifting') || t.contains('motivational')) tags.add('inspiring');
    if (t.contains('sad') || t.contains('emotional') || t.contains('tearjerker')) tags.add('emotional');
    if (t.contains('space') || t.contains('galaxy')) tags.add('space');
    c.tags = tags;

    // Author.
    final by = RegExp(r'(?:by|from)\s+([a-z][a-z.\s]+?)(?:\s+(?:under|over|below|that|which|with|please|$)|$)').firstMatch(t);
    if (by != null) c.author = by.group(1)!.trim();

    // Like a title.
    final like = RegExp(r'(?:like|similar to|in the vein of)\s+([a-z0-9][a-z0-9\s]+?)(?:\s+(?:under|over|but|please|$)|$)').firstMatch(t);
    if (like != null && !t.contains('would like')) c.likeTitle = like.group(1)!.trim();

    // Flags.
    if (t.contains('bestseller') || t.contains('best seller') || t.contains('popular')) c.bestseller = true;
    if (RegExp(r'\bnew\b|new arrival|just released|recent').hasMatch(t)) c.fresh = true;
    if (t.contains('classic')) c.classic = true;
    if (t.contains('in stock') || t.contains('available')) c.inStock = true;

    // Follow-up intents.
    if (RegExp(r'\bcheaper\b|less expensive|lower price').hasMatch(t)) c.cheaper = true;
    if (RegExp(r'\bshorter\b').hasMatch(t)) c.shorter = true;
    if (RegExp(r'something else|another|different|other options|more options').hasMatch(t)) c.excludeShown = true;
    if (RegExp(r'same author|more by').hasMatch(t)) c.sameAuthor = true;

    return c;
  }

  bool _passes(Book b, QueryConstraints c) {
    if (c.genre != null && b.genre != c.genre) return false;
    if (c.maxPrice != null && b.price > c.maxPrice!) return false;
    if (c.minPrice != null && b.price < c.minPrice!) return false;
    if (c.maxPages != null && b.pages >= c.maxPages!) return false;
    if (c.minPages != null && b.pages <= c.minPages!) return false;
    if (c.author != null && !b.author.toLowerCase().contains(c.author!)) return false;
    if (c.bestseller && b.sold < 1000) return false;
    if (c.inStock && !b.inStock) return false;
    if (c.classic && !(b.genre == 'Classics' || b.tagList.contains('classic'))) return false;
    if (c.fresh) {
      final d = DateTime.tryParse(b.createdAt);
      if (d == null || DateTime.now().toUtc().difference(d).inDays > 40) return false;
    }
    if (c.tags.isNotEmpty) {
      final bt = b.tagList;
      if (!c.tags.every((tag) => bt.contains(tag))) return false;
    }
    return true;
  }

  double _score(Book b, List<String> queryTokens) {
    final ratingPart = 0.15 * (b.avgRating / 5.0);
    final popPart = 0.10 * (b.sold / _maxSold);
    if (queryTokens.isEmpty) {
      return 0.6 * (b.avgRating / 5.0) + 0.4 * (b.sold / _maxSold);
    }
    final q = <String, double>{};
    for (final t in queryTokens) {
      q[t] = (q[t] ?? 0) + 1;
    }
    final cos = _cosine(q, _vectors[b.id] ?? {});
    return cos + ratingPart + popPart;
  }

  List<Book> _rank(List<Book> pool, String text, {double boost = 0}) {
    final tokens = _tokens(text);
    final scored = pool.map((b) => MapEntry(b, _score(b, tokens) + boost)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Top candidate books to hand to Gemini (real ids only).
  List<Book> candidates(String text, {int limit = 12}) {
    final c = parse(text);
    var pool = _books.where((b) => _passes(b, c)).toList();
    if (pool.isEmpty) pool = List.of(_books);
    final ranked = _rank(pool, text, boost: c.hasAny ? 0.5 : 0);
    return ranked.take(limit).toList();
  }

  OfflineReply respond(String text) {
    final t = text.toLowerCase().trim();

    // Canned conversational replies.
    if (RegExp(r'^(hi|hello|hey|salam|assalam|good morning|good evening)\b').hasMatch(t)) {
      return OfflineReply(
        text: 'Hello! I’m your Shelf librarian. Tell me what you’re in the mood for — a genre, a budget, a mood, or a book you loved — and I’ll find your next read.',
        books: const [], whyById: const {},
      );
    }
    if (RegExp(r'thank|thanks|shukriya').hasMatch(t)) {
      return OfflineReply(text: 'You’re very welcome! Happy reading — come back any time for more recommendations.', books: const [], whyById: const {});
    }
    if (t.contains('shipping') || t.contains('delivery cost') || t.contains('deliver charge')) {
      return OfflineReply(text: 'Shipping is \$2.99 under \$30, and free on orders of \$30 or more. Most orders arrive in 3–5 working days.', books: const [], whyById: const {});
    }
    if (t.contains('return') || t.contains('refund')) {
      return OfflineReply(text: 'You can return any book within 14 days of delivery for a full refund, as long as it’s in good condition.', books: const [], whyById: const {});
    }
    if (t.contains('coupon') || t.contains('discount code') || t.contains('promo')) {
      return OfflineReply(text: 'Use code STUDENT10 at checkout for 10% off your order. It works on any book in the store.', books: const [], whyById: const {});
    }
    if ((t.contains('order') || t.contains('track')) && (t.contains('where') || t.contains('status') || t.contains('track'))) {
      return OfflineReply(text: 'You can follow every order under Profile → My Orders, where each one has a live tracking timeline and a tracking number. If you tell me the order number I can help you read its status.', books: const [], whyById: const {});
    }

    var c = parse(text);

    // Follow-ups reuse the previous constraints.
    final isFollowUp = c.cheaper || c.shorter || c.excludeShown || c.sameAuthor;
    if (isFollowUp && _last != null) {
      final base = _last!.copy();
      if (c.cheaper && _lastBooks.isNotEmpty) {
        final avg = _lastBooks.map((b) => b.price).reduce((a, b) => a + b) / _lastBooks.length;
        base.maxPrice = double.parse((avg - 0.01).toStringAsFixed(2));
      }
      if (c.shorter && _lastBooks.isNotEmpty) {
        final avgPages = _lastBooks.map((b) => b.pages).reduce((a, b) => a + b) ~/ _lastBooks.length;
        base.maxPages = avgPages;
      }
      if (c.sameAuthor && _lastBooks.isNotEmpty) {
        base.author = _lastBooks.first.author.toLowerCase();
      }
      base.excludeShown = c.excludeShown;
      c = base;
    }

    // "like X" → adopt that book's genre and tags.
    if (c.likeTitle != null) {
      final match = _books.where((b) => b.title.toLowerCase().contains(c.likeTitle!)).toList();
      if (match.isNotEmpty) {
        final ref = match.first;
        c.genre = ref.genre;
        c.tags = ref.tagList.take(2).toList();
      }
    }

    var pool = _books.where((b) => _passes(b, c)).toList();
    // Only "something else" hides already-shown books; "cheaper"/"shorter"/
    // "same author" refine the same pool and may re-show titles.
    if (c.excludeShown) {
      pool = pool.where((b) => !_shown.contains(b.id)).toList();
    }

    // Relax tags first if nothing matches.
    if (pool.isEmpty && c.tags.isNotEmpty) {
      final relaxed = c.copy()..tags = [];
      pool = _books.where((b) => _passes(b, relaxed)).toList();
      c = relaxed;
    }

    // Fallback: bestsellers + a clarifying question.
    if (pool.isEmpty) {
      final fallback = _rank(List.of(_books), '', boost: 0).take(3).toList();
      _remember(c, fallback);
      return OfflineReply(
        text: 'I couldn’t find an exact match, so here are three reader favourites. Tell me a genre, a budget or a mood and I’ll narrow it down.',
        books: fallback,
        whyById: {for (final b in fallback) b.id: 'A reader favourite with ${b.sold} copies sold.'},
      );
    }

    final ranked = _rank(pool, text);
    final picks = ranked.take(4).toList();
    _remember(c, picks);

    final why = <int, String>{};
    for (final b in picks) {
      why[b.id] = _why(b, c);
    }
    return OfflineReply(text: _intro(c, picks.length), books: picks, whyById: why);
  }

  void _remember(QueryConstraints c, List<Book> picks) {
    _last = c;
    _lastBooks = picks;
    _shown.addAll(picks.map((b) => b.id));
  }

  String _intro(QueryConstraints c, int n) {
    final bits = <String>[];
    if (c.genre != null) bits.add(c.genre!.toLowerCase());
    if (c.tags.isNotEmpty) bits.add(c.tags.join(', '));
    if (c.maxPrice != null) bits.add('under \$${c.maxPrice!.toStringAsFixed(0)}');
    if (c.maxPages != null) bits.add('a quick read');
    if (c.minPages != null) bits.add('a long, immersive read');
    if (c.author != null) bits.add('by ${c.author}');
    if (c.bestseller) bits.add('bestselling');
    if (c.classic) bits.add('classic');
    if (c.fresh) bits.add('new');
    final desc = bits.isEmpty ? 'a few' : bits.join(' · ');
    return 'Here are $n picks for $desc. Tap a card for details, or ask me to refine.';
  }

  String _why(Book b, QueryConstraints c) {
    final reasons = <String>[];
    if (c.genre != null && b.genre == c.genre) reasons.add(b.genre);
    if (c.maxPrice != null) reasons.add('${money(b.price)} fits your budget');
    if (c.maxPages != null) reasons.add('only ${b.pages} pages');
    if (c.minPages != null) reasons.add('${b.pages} pages to sink into');
    if (c.author != null) reasons.add('by ${b.author}');
    if (b.avgRating > 0) reasons.add('rated ${b.avgRating.toStringAsFixed(1)}★');
    if (reasons.isEmpty) reasons.add('${b.sold} readers loved it');
    return reasons.take(3).join(' · ');
  }
}
