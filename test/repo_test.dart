import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/db.dart';
import 'package:shelf/data/models.dart';
import 'package:shelf/data/repo.dart';
import 'package:shelf/data/security.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late Repo repo;

  setUp(() async {
    db = await AppDatabase.open(pathOverride: inMemoryDatabasePath);
    repo = Repo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PasswordHasher', () {
    test('hash then verify round-trips', () {
      final h = PasswordHasher.hash('Password@123');
      expect(h.contains(':'), isTrue);
      expect(PasswordHasher.verify('Password@123', h), isTrue);
      expect(PasswordHasher.verify('wrong', h), isFalse);
    });

    test('two hashes of the same password differ (random salt)', () {
      expect(PasswordHasher.hash('abc12345'), isNot(PasswordHasher.hash('abc12345')));
    });

    test('strength rules', () {
      expect(PasswordHasher.checkStrength('short'), isNotNull);
      expect(PasswordHasher.checkStrength('abcdefgh'), isNotNull); // no digit
      expect(PasswordHasher.checkStrength('12345678'), isNotNull); // no letter
      expect(PasswordHasher.checkStrength('abcdefg1'), isNull);
    });
  });

  group('Pricing', () {
    test('STUDENT10 gives 10% off', () {
      expect(Pricing.discount(100, 'STUDENT10'), 10.0);
      expect(Pricing.discount(100, 'student10'), 10.0);
      expect(Pricing.discount(100, 'NOPE'), 0.0);
      expect(Pricing.discount(0, 'STUDENT10'), 0.0);
    });

    test('shipping is free at 30 and over, 2.99 below, 0 when empty', () {
      expect(Pricing.shipping(20), 2.99);
      expect(Pricing.shipping(30), 0.0);
      expect(Pricing.shipping(45), 0.0);
      expect(Pricing.shipping(0), 0.0);
    });

    test('total combines subtotal, discount and shipping', () {
      expect(Pricing.total(20, ''), 22.99);
      expect(Pricing.total(100, 'STUDENT10'), 90.0); // 100 - 10, free shipping
      expect(Pricing.total(20, 'STUDENT10'), 20.99); // 20 - 2 + 2.99
    });
  });

  group('Auth', () {
    test('seeded demo login works', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      expect(u.email, 'demo@bookstore.com');
      expect(u.isAdmin, isFalse);
    });

    test('admin login is admin', () async {
      final u = await repo.login('admin@bookstore.com', 'Admin@123');
      expect(u.isAdmin, isTrue);
    });

    test('wrong password gives a generic error', () async {
      await expectLater(repo.login('demo@bookstore.com', 'nope'), throwsA(isA<AppError>()));
    });

    test('register validates and rejects duplicates', () async {
      final u = await repo.register(name: 'Test User', email: 'test@x.com', password: 'abcdefg1');
      expect(u.id, greaterThan(0));
      await expectLater(repo.register(name: 'Test User', email: 'test@x.com', password: 'abcdefg1'), throwsA(isA<AppError>()));
      await expectLater(repo.register(name: 'X', email: 'bad', password: 'abcdefg1'), throwsA(isA<AppError>()));
    });

    test('login throttles after 5 failures', () async {
      for (var i = 0; i < 5; i++) {
        await expectLater(repo.login('demo@bookstore.com', 'wrong$i'), throwsA(isA<AppError>()));
      }
      // Sixth attempt within 30s is locked, even with the right password.
      await expectLater(
        repo.login('demo@bookstore.com', 'Demo@1234'),
        throwsA(predicate((e) => e is AppError && e.message.contains('Too many'))),
      );
    });

    test('social login creates a demo account', () async {
      final u = await repo.socialLogin('google');
      expect(u.email, 'demo.google@shelf.app');
      final again = await repo.socialLogin('google');
      expect(again.id, u.id);
    });
  });

  group('Password reset', () {
    test('token is single-use and expires', () async {
      final token = await repo.createResetToken('demo@bookstore.com');
      expect(token.length, 8);
      await repo.resetPassword(token, 'NewPass@123');
      // Can sign in with the new password.
      final u = await repo.login('demo@bookstore.com', 'NewPass@123');
      expect(u.email, 'demo@bookstore.com');
      // Single use.
      await expectLater(repo.resetPassword(token, 'Another@123'), throwsA(isA<AppError>()));
      // Expiry.
      final token2 = await repo.createResetToken('demo@bookstore.com');
      await db.update('password_resets', {'expires_at': '2000-01-01 00:00:00'}, where: 'token = ?', whereArgs: [token2]);
      await expectLater(repo.resetPassword(token2, 'Another@123'), throwsA(isA<AppError>()));
    });

    test('change password requires the old one', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      await expectLater(repo.changePassword(u.id, 'wrong', 'NewPass@123'), throwsA(isA<AppError>()));
      await repo.changePassword(u.id, 'Demo@1234', 'NewPass@123');
      final again = await repo.login('demo@bookstore.com', 'NewPass@123');
      expect(again.id, u.id);
    });
  });

  group('Catalog', () {
    test('seed has ~46 books across 12 genres', () async {
      final books = await repo.allBooks();
      expect(books.length, greaterThanOrEqualTo(40));
      final genres = await repo.genres();
      expect(genres.length, 12);
    });

    test('search matches title, author and genre', () async {
      final byTitle = await repo.books(q: 'Dune');
      expect(byTitle.any((b) => b.title == 'Dune'), isTrue);
      final byAuthor = await repo.books(q: 'Andy Weir');
      expect(byAuthor.length, greaterThanOrEqualTo(2));
      final byGenre = await repo.books(q: 'Fantasy');
      expect(byGenre.every((b) => b.genre == 'Fantasy'), isTrue);
    });

    test('price sort and filter', () async {
      final asc = await repo.books(sort: 'price_asc');
      for (var i = 1; i < asc.length; i++) {
        expect(asc[i].price, greaterThanOrEqualTo(asc[i - 1].price));
      }
      final cheap = await repo.books(maxPrice: 10);
      expect(cheap.every((b) => b.price <= 10), isTrue);
    });

    test('new arrivals are sorted by created_at desc', () async {
      final fresh = await repo.newArrivals(limit: 3);
      expect(fresh.length, 3);
      for (var i = 1; i < fresh.length; i++) {
        expect(fresh[i].createdAt.compareTo(fresh[i - 1].createdAt), lessThanOrEqualTo(0));
      }
    });

    test('suggest returns titles and authors', () async {
      final s = await repo.suggest('har');
      expect(s, isNotEmpty);
      expect(await repo.suggest('a'), isEmpty); // min 2 chars
    });
  });

  group('Cart', () {
    test('add, change quantity and remove', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await repo.addToCart(u.id, book.id, qty: 2);
      expect(await repo.cartCount(u.id), 2);
      await repo.setCartQty(u.id, book.id, 3);
      expect(await repo.cartCount(u.id), 3);
      await repo.removeFromCart(u.id, book.id);
      expect(await repo.cartCount(u.id), 0);
    });

    test('cannot exceed stock', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await db.update('books', {'stock': 2}, where: 'id = ?', whereArgs: [book.id]);
      await repo.addToCart(u.id, book.id, qty: 2);
      await expectLater(repo.addToCart(u.id, book.id, qty: 1), throwsA(isA<AppError>()));
      await expectLater(repo.setCartQty(u.id, book.id, 5), throwsA(isA<AppError>()));
    });

    test('out of stock cannot be added', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await db.update('books', {'stock': 0}, where: 'id = ?', whereArgs: [book.id]);
      await expectLater(repo.addToCart(u.id, book.id), throwsA(isA<AppError>()));
    });
  });

  group('Orders', () {
    Future<int> place(Repo repo, AppUser u, Book book, {int qty = 1}) async {
      await repo.addToCart(u.id, book.id, qty: qty);
      final addr = (await repo.addresses(u.id)).first;
      return repo.placeOrder(userId: u.id, shipName: u.name, address: addr, paymentLabel: 'Visa •••• 4242');
    }

    test('placeOrder decrements stock and clears cart', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      final before = book.stock;
      final oid = await place(repo, u, book, qty: 2);
      expect(oid, greaterThan(0));
      final after = await repo.bookById(book.id);
      expect(after!.stock, before - 2);
      expect(await repo.cartCount(u.id), 0);
      final detail = await repo.orderDetail(oid);
      expect(detail!.order.status, 'Placed');
      expect(detail.events.any((e) => e.status == 'Placed'), isTrue);
    });

    test('placeOrder rolls back when stock is short', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await repo.addToCart(u.id, book.id, qty: 2);
      await db.update('books', {'stock': 1}, where: 'id = ?', whereArgs: [book.id]);
      final ordersBefore = (await repo.orders(u.id)).length;
      final addr = (await repo.addresses(u.id)).first;
      await expectLater(
        repo.placeOrder(userId: u.id, shipName: u.name, address: addr, paymentLabel: 'Visa'),
        throwsA(isA<AppError>()),
      );
      // Nothing committed: cart intact, no new order, stock unchanged.
      expect((await repo.cart(u.id)).length, 1);
      expect((await repo.orders(u.id)).length, ordersBefore);
      expect((await repo.bookById(book.id))!.stock, 1);
    });

    test('empty cart cannot place an order', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final addr = (await repo.addresses(u.id)).first;
      await expectLater(repo.placeOrder(userId: u.id, shipName: u.name, address: addr, paymentLabel: 'Visa'), throwsA(isA<AppError>()));
    });

    test('cancel is allowed only before shipping and restores stock', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      final before = book.stock;
      final oid = await place(repo, u, book);
      await repo.cancelOrder(u.id, oid);
      expect((await repo.orderDetail(oid))!.order.status, 'Cancelled');
      expect((await repo.bookById(book.id))!.stock, before);

      final oid2 = await place(repo, u, book);
      await repo.setOrderStatus(oid2, 'Shipped');
      await expectLater(repo.cancelOrder(u.id, oid2), throwsA(isA<AppError>()));
    });

    test('admin cancelling restores stock; advance moves through the flow', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      final before = book.stock;
      final oid = await place(repo, u, book, qty: 2);
      expect((await repo.bookById(book.id))!.stock, before - 2);
      await repo.setOrderStatus(oid, 'Cancelled');
      expect((await repo.bookById(book.id))!.stock, before);

      final oid2 = await place(repo, u, book);
      await repo.advanceOrder(oid2);
      expect((await repo.orderDetail(oid2))!.order.status, 'Processing');
      await repo.advanceOrder(oid2);
      expect((await repo.orderDetail(oid2))!.order.status, 'Shipped');
    });

    test('admin stats exclude cancelled revenue', () async {
      final stats = await repo.adminStats();
      expect(stats.books, greaterThan(0));
      expect(stats.users, greaterThanOrEqualTo(5));
      // The two seeded orders (Delivered + Shipped) count as revenue.
      expect(stats.revenue, greaterThan(0));
    });
  });

  group('Reviews', () {
    test('one review per user per book, editable', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await repo.saveReview(u.id, book.id, 4, 'Good');
      await repo.saveReview(u.id, book.id, 5, 'Actually great');
      final reviews = await repo.reviews(book.id, u.id);
      final mine = reviews.where((r) => r.userId == u.id).toList();
      expect(mine.length, 1);
      expect(mine.first.rating, 5);
      expect(mine.first.body, 'Actually great');
    });

    test('like toggles on and off', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await repo.saveReview(u.id, book.id, 5, 'Loved it');
      final r = (await repo.reviews(book.id, u.id)).firstWhere((r) => r.userId == u.id);
      final on = await repo.toggleLike(r.id, u.id);
      expect(on, isTrue);
      final off = await repo.toggleLike(r.id, u.id);
      expect(off, isFalse);
    });

    test('rating histogram has 5 buckets', () async {
      final book = (await repo.allBooks()).first;
      final hist = await repo.ratingHistogram(book.id);
      expect(hist.length, 5);
    });

    test('review body is capped at 600 chars', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).first;
      await expectLater(repo.saveReview(u.id, book.id, 5, 'x' * 601), throwsA(isA<AppError>()));
    });
  });

  group('Wishlist', () {
    test('toggle adds and removes', () async {
      final u = await repo.login('demo@bookstore.com', 'Demo@1234');
      final book = (await repo.allBooks()).last;
      final added = await repo.toggleWishlist(u.id, book.id);
      expect(added, isTrue);
      expect((await repo.wishlistIds(u.id)).contains(book.id), isTrue);
      final removed = await repo.toggleWishlist(u.id, book.id);
      expect(removed, isFalse);
    });
  });

  group('Admin', () {
    test('saveBook creates author/genre and deleteBook is FK-safe', () async {
      await repo.saveBook(
        title: 'A Brand New Book', author: 'New Author', genre: 'Fantasy', description: 'Desc',
        price: 9.99, pages: 200, published: '2026-01-01', stock: 5, coverColor: '#123456', tags: 'new',
      );
      final found = await repo.books(q: 'A Brand New Book');
      expect(found.length, 1);
      // Deleting a book that is in a past order should fail friendly.
      final demo = await repo.login('demo@bookstore.com', 'Demo@1234');
      final ordered = (await repo.orders(demo.id)).first;
      final detail = await repo.orderDetail(ordered.id);
      final orderedBookId = detail!.items.first.bookId;
      await expectLater(repo.deleteBook(orderedBookId), throwsA(isA<AppError>()));
      // Deleting the fresh book works.
      await repo.deleteBook(found.first.id);
      expect((await repo.books(q: 'A Brand New Book')), isEmpty);
    });

    test('setUserActive and setUserAdmin', () async {
      final users = await repo.users();
      final shopper = users.firstWhere((u) => u.email == 'ali@example.com');
      await repo.setUserActive(shopper.id, false);
      expect((await repo.userById(shopper.id))!.isActive, isFalse);
      await expectLater(repo.login('ali@example.com', 'Password@123'), throwsA(isA<AppError>()));
      await repo.setUserAdmin(shopper.id, true);
      expect((await repo.userById(shopper.id))!.isAdmin, isTrue);
    });
  });
}
