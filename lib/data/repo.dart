import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';
import 'security.dart';

/// The ONLY place SQL lives. Every query is parameterised; widgets never touch
/// the database. Returns typed models and throws friendly [AppError]s.
class Repo {
  Repo(this.db);
  final Database db;

  // ---- login throttling (per email, 5 attempts / 30s) ----
  // Per-instance so a fresh Repo (e.g. each test, or a new app session) starts
  // clean; within one app session the same Repo persists and throttles.
  final Map<String, List<DateTime>> _failures = {};

  static const String _bookSelect = '''
    SELECT b.*, a.name AS author, g.name AS genre,
      COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.book_id = b.id), 0) AS avg_rating,
      (SELECT COUNT(*) FROM reviews r WHERE r.book_id = b.id) AS rating_count
    FROM books b
    JOIN authors a ON a.id = b.author_id
    JOIN genres g ON g.id = b.genre_id
  ''';

  static const String _orderSelect = '''
    SELECT o.*, (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
    FROM orders o
  ''';

  // ============================ AUTH ============================
  Future<AppUser> login(String email, String password) async {
    final key = email.trim().toLowerCase();
    final now = DateTime.now();
    final list = _failures.putIfAbsent(key, () => []);
    list.removeWhere((t) => now.difference(t).inSeconds > 30);
    if (list.length >= 5) {
      throw const AppError('Too many attempts. Please wait a moment and try again.');
    }
    final rows = await db.query('users', where: 'email = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) {
      list.add(now);
      throw const AppError('Email or password is incorrect.');
    }
    final row = rows.first;
    if ((row['is_active'] as num?)?.toInt() == 0) {
      throw const AppError('This account has been deactivated. Contact support.');
    }
    if (!PasswordHasher.verify(password, row['password_hash'] as String)) {
      list.add(now);
      throw const AppError('Email or password is incorrect.');
    }
    list.clear();
    return AppUser.fromMap(row);
  }

  Future<AppUser> register({required String name, required String email, required String password}) async {
    final n = name.trim();
    final e = email.trim().toLowerCase();
    if (n.isEmpty) throw const AppError('Please enter your name.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      throw const AppError('Enter a valid email address.');
    }
    final weak = PasswordHasher.checkStrength(password);
    if (weak != null) throw AppError(weak);
    final exists = await db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    if (exists.isNotEmpty) throw const AppError('An account with that email already exists.');
    final id = await db.insert('users', {
      'name': n, 'email': e, 'password_hash': PasswordHasher.hash(password),
      'provider': 'email', 'is_admin': 0, 'is_active': 1, 'phone': '', 'created_at': nowTs(),
    });
    return (await userById(id))!;
  }

  Future<AppUser> socialLogin(String provider) async {
    final e = 'demo.$provider@shelf.app';
    final rows = await db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    if (rows.isNotEmpty) return AppUser.fromMap(rows.first);
    final id = await db.insert('users', {
      'name': 'Demo ${provider[0].toUpperCase()}${provider.substring(1)} User',
      'email': e, 'password_hash': PasswordHasher.hash('demo-${DateTime.now().millisecondsSinceEpoch}'),
      'provider': provider, 'is_admin': 0, 'is_active': 1, 'phone': '', 'created_at': nowTs(),
    });
    return (await userById(id))!;
  }

  Future<AppUser?> userById(int id) async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<String> createResetToken(String email) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()], limit: 1);
    if (rows.isEmpty) throw const AppError('No account found with that email.');
    final token = PasswordHasher.resetCode();
    final expires = DateTime.now().toUtc().add(const Duration(minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    final exp = '${expires.year}-${two(expires.month)}-${two(expires.day)} ${two(expires.hour)}:${two(expires.minute)}:${two(expires.second)}';
    await db.insert('password_resets', {
      'user_id': rows.first['id'], 'token': token, 'expires_at': exp, 'used': 0, 'created_at': nowTs(),
    });
    return token;
  }

  Future<void> resetPassword(String token, String newPassword) async {
    final rows = await db.query('password_resets', where: 'token = ?', whereArgs: [token.trim().toUpperCase()], limit: 1);
    if (rows.isEmpty) throw const AppError('That reset code is not valid.');
    final row = rows.first;
    if ((row['used'] as num).toInt() == 1) throw const AppError('That reset code has already been used.');
    final expires = DateTime.tryParse(row['expires_at'] as String);
    if (expires == null || DateTime.now().toUtc().isAfter(expires)) {
      throw const AppError('That reset code has expired. Request a new one.');
    }
    final weak = PasswordHasher.checkStrength(newPassword);
    if (weak != null) throw AppError(weak);
    await db.update('users', {'password_hash': PasswordHasher.hash(newPassword)}, where: 'id = ?', whereArgs: [row['user_id']]);
    await db.update('password_resets', {'used': 1}, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<void> changePassword(int userId, String oldPassword, String newPassword) async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) throw const AppError('Account not found.');
    if (!PasswordHasher.verify(oldPassword, rows.first['password_hash'] as String)) {
      throw const AppError('Your current password is incorrect.');
    }
    final weak = PasswordHasher.checkStrength(newPassword);
    if (weak != null) throw AppError(weak);
    await db.update('users', {'password_hash': PasswordHasher.hash(newPassword)}, where: 'id = ?', whereArgs: [userId]);
  }

  // ============================ CATALOG ============================
  Future<List<Book>> allBooks() async {
    final rows = await db.rawQuery('$_bookSelect ORDER BY b.title COLLATE NOCASE');
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> bookById(int id) async {
    final rows = await db.rawQuery('$_bookSelect WHERE b.id = ?', [id]);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  Future<List<Book>> books({
    String? q,
    String sort = 'popular',
    double? maxPrice,
    double? minPrice,
    int? genreId,
    int? authorId,
    bool inStockOnly = false,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (q != null && q.trim().isNotEmpty) {
      where.add('(b.title LIKE ? OR a.name LIKE ? OR g.name LIKE ?)');
      final like = '%${q.trim()}%';
      args.addAll([like, like, like]);
    }
    if (maxPrice != null) {
      where.add('b.price <= ?');
      args.add(maxPrice);
    }
    if (minPrice != null) {
      where.add('b.price >= ?');
      args.add(minPrice);
    }
    if (genreId != null) {
      where.add('b.genre_id = ?');
      args.add(genreId);
    }
    if (authorId != null) {
      where.add('b.author_id = ?');
      args.add(authorId);
    }
    if (inStockOnly) where.add('b.stock > 0');
    final order = switch (sort) {
      'price_asc' => 'b.price ASC',
      'price_desc' => 'b.price DESC',
      'release' => 'b.created_at DESC',
      'rating' => 'avg_rating DESC, rating_count DESC',
      'title' => 'b.title COLLATE NOCASE ASC',
      _ => 'b.sold DESC',
    };
    final sql = '$_bookSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY $order ${limit != null ? 'LIMIT $limit' : ''}';
    final rows = await db.rawQuery(sql, args);
    return rows.map(Book.fromMap).toList();
  }

  Future<List<Book>> newArrivals({int limit = 8}) async {
    final rows = await db.rawQuery('$_bookSelect ORDER BY b.created_at DESC LIMIT ?', [limit]);
    return rows.map(Book.fromMap).toList();
  }

  Future<List<Book>> bestsellers({int limit = 8}) async {
    final rows = await db.rawQuery('$_bookSelect ORDER BY b.sold DESC LIMIT ?', [limit]);
    return rows.map(Book.fromMap).toList();
  }

  Future<List<String>> suggest(String q) async {
    final t = q.trim();
    if (t.length < 2) return [];
    final like = '%$t%';
    final titles = await db.rawQuery('SELECT DISTINCT title FROM books WHERE title LIKE ? LIMIT 6', [like]);
    final authors = await db.rawQuery('SELECT DISTINCT name FROM authors WHERE name LIKE ? LIMIT 4', [like]);
    return [
      ...titles.map((r) => r['title'] as String),
      ...authors.map((r) => r['name'] as String),
    ];
  }

  Future<List<GenreInfo>> genres() async {
    final rows = await db.rawQuery('''
      SELECT g.id, g.name, COUNT(b.id) AS count
      FROM genres g LEFT JOIN books b ON b.genre_id = g.id
      GROUP BY g.id ORDER BY g.name COLLATE NOCASE
    ''');
    return rows.map((r) => GenreInfo(id: (r['id'] as num).toInt(), name: r['name'] as String, count: (r['count'] as num).toInt())).toList();
  }

  Future<List<AuthorInfo>> authors() async {
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, COUNT(b.id) AS count
      FROM authors a LEFT JOIN books b ON b.author_id = a.id
      GROUP BY a.id ORDER BY a.name COLLATE NOCASE
    ''');
    return rows.map((r) => AuthorInfo(id: (r['id'] as num).toInt(), name: r['name'] as String, count: (r['count'] as num).toInt())).toList();
  }

  Future<List<Book>> similar(Book book, {int limit = 6}) async {
    final rows = await db.rawQuery(
      '$_bookSelect WHERE b.genre_id = ? AND b.id != ? ORDER BY ABS(b.price - ?) ASC, b.sold DESC LIMIT ?',
      [book.genreId, book.id, book.price, limit],
    );
    return rows.map(Book.fromMap).toList();
  }

  // ============================ CART ============================
  Future<int> cartCount(int userId) async {
    final r = await db.rawQuery('SELECT COALESCE(SUM(qty), 0) AS n FROM cart_items WHERE user_id = ?', [userId]);
    return (r.first['n'] as num).toInt();
  }

  Future<List<CartLine>> cart(int userId) async {
    final rows = await db.rawQuery('''
      SELECT b.*, a.name AS author, g.name AS genre, c.qty AS qty,
        COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.book_id = b.id), 0) AS avg_rating,
        (SELECT COUNT(*) FROM reviews r WHERE r.book_id = b.id) AS rating_count
      FROM cart_items c
      JOIN books b ON b.id = c.book_id
      JOIN authors a ON a.id = b.author_id
      JOIN genres g ON g.id = b.genre_id
      WHERE c.user_id = ?
      ORDER BY c.id ASC
    ''', [userId]);
    return rows.map((r) => CartLine(book: Book.fromMap(r), qty: (r['qty'] as num).toInt())).toList();
  }

  Future<void> addToCart(int userId, int bookId, {int qty = 1}) async {
    final book = await bookById(bookId);
    if (book == null) throw const AppError('Book not found.');
    if (book.stock <= 0) throw const AppError('This title is out of stock.');
    final existing = await db.query('cart_items', where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId], limit: 1);
    final current = existing.isEmpty ? 0 : (existing.first['qty'] as num).toInt();
    if (current + qty > book.stock) {
      throw AppError('Only ${book.stock} copies are available.');
    }
    if (existing.isEmpty) {
      await db.insert('cart_items', {'user_id': userId, 'book_id': bookId, 'qty': qty});
    } else {
      await db.update('cart_items', {'qty': current + qty}, where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<void> setCartQty(int userId, int bookId, int qty) async {
    if (qty <= 0) {
      await removeFromCart(userId, bookId);
      return;
    }
    final book = await bookById(bookId);
    if (book == null) throw const AppError('Book not found.');
    if (qty > book.stock) throw AppError('Only ${book.stock} copies are available.');
    await db.update('cart_items', {'qty': qty}, where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId]);
  }

  Future<void> removeFromCart(int userId, int bookId) async {
    await db.delete('cart_items', where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId]);
  }

  Future<void> clearCart(int userId) async {
    await db.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ============================ ORDERS ============================
  Future<int> placeOrder({
    required int userId,
    required String shipName,
    required Address address,
    required String paymentLabel,
    String coupon = '',
  }) async {
    return db.transaction<int>((txn) async {
      final lines = await txn.rawQuery('''
        SELECT c.qty, b.id AS book_id, b.title, b.price, b.stock
        FROM cart_items c JOIN books b ON b.id = c.book_id
        WHERE c.user_id = ?
      ''', [userId]);
      if (lines.isEmpty) throw const AppError('Your cart is empty.');
      var subtotal = 0.0;
      for (final l in lines) {
        final qty = (l['qty'] as num).toInt();
        final stock = (l['stock'] as num).toInt();
        if (qty > stock) {
          throw AppError('Not enough stock for “${l['title']}”. Only $stock left.');
        }
        subtotal += (l['price'] as num).toDouble() * qty;
      }
      final total = Pricing.total(subtotal, coupon);
      final orderId = await txn.insert('orders', {
        'user_id': userId, 'status': 'Placed', 'total': total,
        'ship_name': shipName, 'ship_line1': address.line1, 'ship_city': address.city,
        'payment': paymentLabel, 'tracking_no': '', 'created_at': nowTs(),
      });
      final tracking = 'TRK-${90000 + orderId}-PK';
      await txn.update('orders', {'tracking_no': tracking}, where: 'id = ?', whereArgs: [orderId]);
      for (final l in lines) {
        final qty = (l['qty'] as num).toInt();
        await txn.insert('order_items', {
          'order_id': orderId, 'book_id': l['book_id'], 'title': l['title'],
          'unit_price': (l['price'] as num).toDouble(), 'qty': qty,
        });
        await txn.rawUpdate('UPDATE books SET stock = stock - ?, sold = sold + ? WHERE id = ?', [qty, qty, l['book_id']]);
      }
      await txn.insert('order_events', {
        'order_id': orderId, 'status': 'Placed', 'note': 'Order received and payment confirmed.', 'at': nowTs(),
      });
      await txn.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
      return orderId;
    });
  }

  Future<List<OrderSummary>> orders(int userId) async {
    final rows = await db.rawQuery('$_orderSelect WHERE o.user_id = ? ORDER BY o.created_at DESC', [userId]);
    return rows.map(OrderSummary.fromMap).toList();
  }

  Future<List<OrderSummary>> allOrders() async {
    final rows = await db.rawQuery('$_orderSelect ORDER BY o.created_at DESC');
    return rows.map(OrderSummary.fromMap).toList();
  }

  Future<OrderDetail?> orderDetail(int orderId) async {
    final orows = await db.rawQuery('$_orderSelect WHERE o.id = ?', [orderId]);
    if (orows.isEmpty) return null;
    final order = OrderSummary.fromMap(orows.first);
    final items = (await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId])).map(OrderItem.fromMap).toList();
    final events = (await db.query('order_events', where: 'order_id = ?', whereArgs: [orderId], orderBy: 'at ASC, id ASC')).map(OrderEvent.fromMap).toList();
    return OrderDetail(
      order: order, items: items, events: events,
      shipName: orows.first['ship_name'] as String, shipLine1: orows.first['ship_line1'] as String,
      shipCity: orows.first['ship_city'] as String, payment: orows.first['payment'] as String,
    );
  }

  Future<void> _restoreStock(dynamic executor, int orderId) async {
    final items = await executor.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    for (final it in items) {
      await executor.rawUpdate('UPDATE books SET stock = stock + ? WHERE id = ?', [it['qty'], it['book_id']]);
    }
  }

  Future<void> cancelOrder(int userId, int orderId) async {
    final rows = await db.query('orders', where: 'id = ? AND user_id = ?', whereArgs: [orderId, userId], limit: 1);
    if (rows.isEmpty) throw const AppError('Order not found.');
    final status = rows.first['status'] as String;
    if (status != 'Placed' && status != 'Processing') {
      throw const AppError('This order can no longer be cancelled.');
    }
    await db.transaction((txn) async {
      await _restoreStock(txn, orderId);
      await txn.update('orders', {'status': 'Cancelled'}, where: 'id = ?', whereArgs: [orderId]);
      await txn.insert('order_events', {'order_id': orderId, 'status': 'Cancelled', 'note': 'Cancelled by customer.', 'at': nowTs()});
    });
  }

  Future<void> setOrderStatus(int orderId, String status) async {
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (rows.isEmpty) throw const AppError('Order not found.');
    final previous = rows.first['status'] as String;
    await db.transaction((txn) async {
      if (status == 'Cancelled' && previous != 'Cancelled' && previous != 'Delivered') {
        await _restoreStock(txn, orderId);
      }
      await txn.update('orders', {'status': status}, where: 'id = ?', whereArgs: [orderId]);
      await txn.insert('order_events', {'order_id': orderId, 'status': status, 'note': 'Status updated to $status.', 'at': nowTs()});
    });
  }

  Future<void> advanceOrder(int orderId) async {
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (rows.isEmpty) throw const AppError('Order not found.');
    final current = rows.first['status'] as String;
    final idx = kOrderFlow.indexOf(current);
    if (idx < 0 || idx >= kOrderFlow.length - 1) throw const AppError('This order cannot be advanced.');
    await setOrderStatus(orderId, kOrderFlow[idx + 1]);
  }

  Future<AdminStats> adminStats() async {
    Future<int> count(String table) async => (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n'] as int;
    final books = await count('books');
    final users = await count('users');
    final orders = await count('orders');
    final rev = await db.rawQuery("SELECT COALESCE(SUM(total), 0) AS n FROM orders WHERE status != 'Cancelled'");
    final low = await db.rawQuery('SELECT COUNT(*) AS n FROM books WHERE stock < 10');
    final pending = await db.rawQuery("SELECT COUNT(*) AS n FROM orders WHERE status IN ('Placed', 'Processing')");
    final sales = await db.rawQuery('''
      SELECT substr(created_at, 1, 10) AS day, SUM(total) AS total
      FROM orders WHERE status != 'Cancelled'
      GROUP BY day ORDER BY day DESC LIMIT 7
    ''');
    final top = await db.rawQuery('''
      SELECT title, SUM(qty) AS n FROM order_items GROUP BY title ORDER BY n DESC LIMIT 5
    ''');
    return AdminStats(
      books: books, users: users, orders: orders,
      revenue: (rev.first['n'] as num).toDouble(),
      lowStock: (low.first['n'] as num).toInt(),
      pendingOrders: (pending.first['n'] as num).toInt(),
      salesByDay: sales.map((r) => MapEntry(r['day'] as String, (r['total'] as num).toDouble())).toList(),
      topBooks: top.map((r) => MapEntry(r['title'] as String, (r['n'] as num).toInt())).toList(),
    );
  }

  // ============================ REVIEWS ============================
  Future<void> saveReview(int userId, int bookId, int rating, String body) async {
    if (rating < 1 || rating > 5) throw const AppError('Choose a rating from 1 to 5 stars.');
    if (body.length > 600) throw const AppError('Reviews are limited to 600 characters.');
    final existing = await db.query('reviews', where: 'book_id = ? AND user_id = ?', whereArgs: [bookId, userId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('reviews', {'book_id': bookId, 'user_id': userId, 'rating': rating, 'body': body.trim(), 'created_at': nowTs()});
    } else {
      await db.update('reviews', {'rating': rating, 'body': body.trim(), 'created_at': nowTs()}, where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<List<Review>> reviews(int bookId, int? currentUserId) async {
    final rows = await db.rawQuery('''
      SELECT r.*, u.name AS user_name,
        (SELECT COUNT(*) FROM review_likes l WHERE l.review_id = r.id) AS likes,
        ${currentUserId != null ? '(SELECT COUNT(*) FROM review_likes l WHERE l.review_id = r.id AND l.user_id = ?)' : '0'} AS liked_by_me
      FROM reviews r JOIN users u ON u.id = r.user_id
      WHERE r.book_id = ?
      ORDER BY r.created_at DESC
    ''', [if (currentUserId != null) currentUserId, bookId]);
    return rows.map(Review.fromMap).toList();
  }

  Future<bool> toggleLike(int reviewId, int userId) async {
    final existing = await db.query('review_likes', where: 'review_id = ? AND user_id = ?', whereArgs: [reviewId, userId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('review_likes', {'review_id': reviewId, 'user_id': userId});
      return true;
    }
    await db.delete('review_likes', where: 'id = ?', whereArgs: [existing.first['id']]);
    return false;
  }

  Future<List<int>> ratingHistogram(int bookId) async {
    final rows = await db.rawQuery('SELECT rating, COUNT(*) AS n FROM reviews WHERE book_id = ? GROUP BY rating', [bookId]);
    final hist = List<int>.filled(5, 0);
    for (final r in rows) {
      final rating = (r['rating'] as num).toInt();
      if (rating >= 1 && rating <= 5) hist[rating - 1] = (r['n'] as num).toInt();
    }
    return hist;
  }

  Future<void> deleteReview(int reviewId) async {
    await db.delete('reviews', where: 'id = ?', whereArgs: [reviewId]);
  }

  /// Aggregate helper used by the book page pull-quote.
  static Map<String, dynamic> summarizeReviews(List<Review> reviews) {
    if (reviews.isEmpty) return {'count': 0, 'avg': 0.0};
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return {'count': reviews.length, 'avg': avg};
  }

  // ============================ WISHLIST ============================
  Future<bool> toggleWishlist(int userId, int bookId) async {
    final existing = await db.query('wishlist_items', where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('wishlist_items', {'user_id': userId, 'book_id': bookId});
      return true;
    }
    await db.delete('wishlist_items', where: 'id = ?', whereArgs: [existing.first['id']]);
    return false;
  }

  Future<Set<int>> wishlistIds(int userId) async {
    final rows = await db.query('wishlist_items', columns: ['book_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => (r['book_id'] as num).toInt()).toSet();
  }

  Future<List<Book>> wishlist(int userId) async {
    final rows = await db.rawQuery('''
      $_bookSelect JOIN wishlist_items w ON w.book_id = b.id
      WHERE w.user_id = ? ORDER BY w.id DESC
    ''', [userId]);
    return rows.map(Book.fromMap).toList();
  }

  // ============================ ADDRESSES / PAYMENTS ============================
  Future<List<Address>> addresses(int userId) async {
    final rows = await db.query('addresses', where: 'user_id = ?', whereArgs: [userId], orderBy: 'is_default DESC, id ASC');
    return rows.map(Address.fromMap).toList();
  }

  Future<void> saveAddress(int userId, Address a, {int? id}) async {
    final map = {
      'user_id': userId, 'label': a.label, 'full_name': a.fullName, 'line1': a.line1,
      'city': a.city, 'region': a.region, 'postal_code': a.postalCode, 'country': a.country,
      'phone': a.phone, 'is_default': a.isDefault ? 1 : 0,
    };
    if (a.isDefault) {
      await db.update('addresses', {'is_default': 0}, where: 'user_id = ?', whereArgs: [userId]);
    }
    if (id == null) {
      await db.insert('addresses', map);
    } else {
      await db.update('addresses', map, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteAddress(int id) async => db.delete('addresses', where: 'id = ?', whereArgs: [id]);

  Future<List<PaymentMethod>> paymentMethods(int userId) async {
    final rows = await db.query('payment_methods', where: 'user_id = ?', whereArgs: [userId], orderBy: 'is_default DESC, id ASC');
    return rows.map(PaymentMethod.fromMap).toList();
  }

  /// Stores brand + last4 + expiry ONLY. Never a full PAN or CVV.
  Future<void> savePaymentMethod(int userId, {required String brand, required String last4, required int expMonth, required int expYear, bool isDefault = false, int? id}) async {
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) throw const AppError('Enter the last 4 digits of the card.');
    final map = {'user_id': userId, 'brand': brand, 'last4': last4, 'exp_month': expMonth, 'exp_year': expYear, 'is_default': isDefault ? 1 : 0};
    if (isDefault) {
      await db.update('payment_methods', {'is_default': 0}, where: 'user_id = ?', whereArgs: [userId]);
    }
    if (id == null) {
      await db.insert('payment_methods', map);
    } else {
      await db.update('payment_methods', map, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deletePaymentMethod(int id) async => db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);

  // ============================ ADMIN ============================
  Future<List<AppUser>> users() async {
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> setUserActive(int userId, bool active) async {
    await db.update('users', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> setUserAdmin(int userId, bool admin) async {
    await db.update('users', {'is_admin': admin ? 1 : 0}, where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> saveBook({
    int? id,
    required String title,
    required String author,
    required String genre,
    required String description,
    required double price,
    required int pages,
    required String published,
    required int stock,
    required String coverColor,
    required String tags,
  }) async {
    Future<int> lookup(String table, String name) async {
      final rows = await db.query(table, where: 'name = ?', whereArgs: [name.trim()], limit: 1);
      if (rows.isNotEmpty) return (rows.first['id'] as num).toInt();
      return db.insert(table, {'name': name.trim()});
    }

    final authorId = await lookup('authors', author);
    final genreId = await lookup('genres', genre);
    final map = {
      'title': title.trim(), 'author_id': authorId, 'genre_id': genreId, 'description': description,
      'price': price, 'pages': pages, 'published': published, 'stock': stock,
      'cover_color': coverColor, 'tags': tags,
    };
    if (id == null) {
      return db.insert('books', {...map, 'sold': 0, 'created_at': nowTs()});
    }
    await db.update('books', map, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteBook(int bookId) async {
    try {
      await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    } on DatabaseException catch (e) {
      if (e.toString().toUpperCase().contains('FOREIGN KEY')) {
        throw const AppError('This book appears in past orders and cannot be deleted. Set its stock to 0 instead.');
      }
      throw AppError('Could not delete this book. ${e.toString()}');
    }
  }
}
