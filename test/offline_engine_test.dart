import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/db.dart';
import 'package:shelf/data/models.dart';
import 'package:shelf/data/repo.dart';
import 'package:shelf/features/ai/offline_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late List<Book> books;
  late OfflineEngine engine;

  setUp(() async {
    final db = await AppDatabase.open(pathOverride: inMemoryDatabasePath);
    books = await Repo(db).allBooks();
    await db.close();
    engine = OfflineEngine(books);
  });

  group('constraint parsing', () {
    test('price cap: under 15', () {
      final c = engine.parse('something under 15 dollars');
      expect(c.maxPrice, 15);
    });
    test('cheap means at most 12', () {
      final c = engine.parse('a cheap read');
      expect(c.maxPrice, 12);
    });
    test('short means under 300 pages', () {
      final c = engine.parse('a short book');
      expect(c.maxPages, 300);
    });
    test('long means over 450 pages', () {
      final c = engine.parse('a long epic');
      expect(c.minPages, 450);
    });
    test('genre synonym: sci-fi', () {
      expect(engine.parse('some sci-fi').genre, 'Science Fiction');
      expect(engine.parse('scifi please').genre, 'Science Fiction');
      expect(engine.parse('science fiction').genre, 'Science Fiction');
    });
    test('genre synonym: programming / tech', () {
      expect(engine.parse('learn programming').genre, 'Technology');
      expect(engine.parse('a tech book').genre, 'Technology');
    });
    test('genre synonym: self help', () {
      expect(engine.parse('self help').genre, 'Self-Help');
    });
    test('mood maps to tags', () {
      expect(engine.parse('something cozy').tags, contains('cozy'));
      expect(engine.parse('a funny book').tags, contains('funny'));
      expect(engine.parse('something dark and twisted').tags, contains('dark'));
    });
    test('by author', () {
      expect(engine.parse('books by Andy Weir').author, 'andy weir');
    });
    test('like title', () {
      expect(engine.parse('something like Dune').likeTitle, 'dune');
    });
    test('bestseller / new / classic flags', () {
      expect(engine.parse('a bestseller').bestseller, isTrue);
      expect(engine.parse('something new').fresh, isTrue);
      expect(engine.parse('a classic').classic, isTrue);
    });
    test('follow-up intents', () {
      expect(engine.parse('cheaper').cheaper, isTrue);
      expect(engine.parse('shorter').shorter, isTrue);
      expect(engine.parse('something else').excludeShown, isTrue);
      expect(engine.parse('same author').sameAuthor, isTrue);
    });
  });

  group('results respect constraints', () {
    test('cozy under \$12 returns only cozy books priced <= 12', () {
      final r = engine.respond('Something cozy under \$12');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.price, lessThanOrEqualTo(12));
      }
    });

    test('short sci-fi returns only sci-fi under 300 pages', () {
      final r = engine.respond('short sci-fi');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.genre, 'Science Fiction');
        expect(b.pages, lessThan(300));
      }
      // Neuromancer (271 pages) is the short sci-fi in the seed.
      expect(r.books.any((b) => b.title == 'Neuromancer'), isTrue);
    });

    test('fantasy under 15 respects genre and price', () {
      final r = engine.respond('fantasy under 15');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.genre, 'Fantasy');
        expect(b.price, lessThanOrEqualTo(15));
      }
    });

    test('books by Andy Weir returns only Andy Weir', () {
      final r = engine.respond('books by Andy Weir');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.author, 'Andy Weir');
      }
    });

    test('like Dune returns science fiction', () {
      final r = engine.respond('something like Dune');
      expect(r.books, isNotEmpty);
      expect(r.books.every((b) => b.genre == 'Science Fiction'), isTrue);
    });

    test('long epic fantasy returns big fantasy books', () {
      final r = engine.respond('long epic fantasy');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.genre, 'Fantasy');
        expect(b.pages, greaterThan(450));
      }
    });

    test('bestseller returns high-sold books', () {
      final r = engine.respond('a bestseller');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.sold, greaterThanOrEqualTo(1000));
      }
    });

    test('history books returns history genre', () {
      final r = engine.respond('history books');
      expect(r.books, isNotEmpty);
      expect(r.books.every((b) => b.genre == 'History'), isTrue);
    });

    test('programming books returns technology genre', () {
      final r = engine.respond('books to learn programming');
      expect(r.books, isNotEmpty);
      expect(r.books.every((b) => b.genre == 'Technology'), isTrue);
    });

    test('romance under 10 respects genre and price', () {
      final r = engine.respond('romance under 10');
      expect(r.books, isNotEmpty);
      for (final b in r.books) {
        expect(b.genre, 'Romance');
        expect(b.price, lessThanOrEqualTo(10));
      }
    });

    test('inspiring biography returns biography genre', () {
      final r = engine.respond('an inspiring biography');
      expect(r.books, isNotEmpty);
      expect(r.books.every((b) => b.genre == 'Biography'), isTrue);
    });

    test('classic returns classics', () {
      final r = engine.respond('a classic novel');
      expect(r.books, isNotEmpty);
      expect(r.books.every((b) => b.genre == 'Classics' || b.tagList.contains('classic')), isTrue);
    });

    test('why notes are present for each pick', () {
      final r = engine.respond('short sci-fi under 15');
      for (final b in r.books) {
        expect(r.whyById[b.id], isNotNull);
        expect(r.whyById[b.id], isNotEmpty);
      }
    });
  });

  group('follow-ups', () {
    test('cheaper returns books cheaper than the previous average', () {
      final first = engine.respond('technology books');
      expect(first.books, isNotEmpty);
      final avg = first.books.map((b) => b.price).reduce((a, b) => a + b) / first.books.length;
      final second = engine.respond('cheaper');
      expect(second.books, isNotEmpty);
      for (final b in second.books) {
        expect(b.price, lessThan(avg));
      }
    });

    test('something else excludes already-shown books', () {
      final first = engine.respond('fantasy');
      final shownIds = first.books.map((b) => b.id).toSet();
      final second = engine.respond('something else');
      for (final b in second.books) {
        expect(shownIds.contains(b.id), isFalse);
      }
    });

    test('same author keeps the previous author', () {
      final first = engine.respond('books by Andy Weir');
      expect(first.books, isNotEmpty);
      final second = engine.respond('same author');
      for (final b in second.books) {
        expect(b.author, first.books.first.author);
      }
    });
  });

  group('conversation', () {
    test('greeting steers back to books with no picks', () {
      final r = engine.respond('hello');
      expect(r.books, isEmpty);
      expect(r.text.toLowerCase(), contains('librarian'));
    });
    test('thanks is acknowledged', () {
      final r = engine.respond('thank you');
      expect(r.books, isEmpty);
    });
    test('store question about shipping is answered', () {
      final r = engine.respond('how much is shipping?');
      expect(r.text, contains('30'));
    });
    test('order tracking question is answered', () {
      final r = engine.respond('where is my order?');
      expect(r.text.toLowerCase(), contains('order'));
    });
    test('vague unknown request still offers bestsellers', () {
      final r = engine.respond('xyzzy plugh nonsense');
      expect(r.books, isNotEmpty);
    });
    test('candidates returns up to 12 real books', () {
      final c = engine.candidates('something to read', limit: 12);
      expect(c.length, lessThanOrEqualTo(12));
      expect(c.length, greaterThan(0));
    });
  });
}
