import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'security.dart';

/// Deterministic seed: 46 real books, 12 genres, 5 users, reviews and a fully
/// populated demo customer. `Random(2026)` keeps stock/reviews reproducible.
Future<void> seedDatabase(Database db) async {
  final rnd = Random(2026);
  final now = DateTime.now().toUtc();
  String ts(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  String daysAgo(int n) => ts(now.subtract(Duration(days: n)));

  const genres = [
    'Science Fiction', 'Fantasy', 'Thriller', 'Mystery', 'Romance', 'History',
    'Science', 'Self-Help', 'Technology', 'Classics', 'Fiction', 'Biography',
  ];
  final genreId = <String, int>{};
  for (final g in genres) {
    genreId[g] = await db.insert('genres', {'name': g});
  }

  final authorId = <String, int>{};
  Future<int> author(String name) async {
    if (authorId.containsKey(name)) return authorId[name]!;
    final id = await db.insert('authors', {'name': name});
    authorId[name] = id;
    return id;
  }

  // title, author, genre, price, pages, published, sold, color, tags, blurb
  final books = <List<dynamic>>[
    ['Dune', 'Frank Herbert', 'Science Fiction', 18.99, 688, '1965-08-01', 1800, '#B5732E', 'epic,space,classic,desert', 'A desert planet, a noble house, and the spice that powers an empire.'],
    ['Project Hail Mary', 'Andy Weir', 'Science Fiction', 16.99, 496, '2021-05-04', 2100, '#2E5E8C', 'space,funny,science,adventure', 'A lone astronaut wakes with no memory and must save humanity.'],
    ['The Martian', 'Andy Weir', 'Science Fiction', 14.99, 384, '2011-09-27', 1500, '#C0563B', 'space,funny,science,survival', 'Stranded on Mars, an astronaut botanizes his way home.'],
    ['Neuromancer', 'William Gibson', 'Science Fiction', 12.49, 271, '1984-07-01', 900, '#2B2B2B', 'cyberpunk,classic,dark,noir', 'A washed-up hacker is hired for one last impossible job.'],
    ['The Hobbit', 'J.R.R. Tolkien', 'Fantasy', 11.99, 310, '1937-09-21', 2200, '#3E6B4A', 'cozy,classic,adventure,quest', 'A comfortable hobbit is swept into a quest for dragon gold.'],
    ['The Name of the Wind', 'Patrick Rothfuss', 'Fantasy', 15.99, 662, '2007-03-27', 1300, '#7A2E3B', 'epic,magic,coming-of-age', 'The legend of Kvothe, told in his own words.'],
    ['A Game of Thrones', 'George R.R. Martin', 'Fantasy', 17.99, 694, '1996-08-01', 1900, '#2B2B2B', 'epic,dark,politics,dragons', 'Noble families scheme for the Iron Throne as winter comes.'],
    ['The Way of Kings', 'Brandon Sanderson', 'Fantasy', 19.99, 1007, '2010-08-31', 1100, '#2E5E8C', 'epic,magic,war,stormlight', 'On a storm-scoured world, ancient powers begin to wake.'],
    ["Harry Potter and the Sorcerer's Stone", 'J.K. Rowling', 'Fantasy', 10.99, 309, '1997-06-26', 2600, '#7A2E3B', 'magic,cozy,coming-of-age,classic', 'An orphan discovers he is a wizard on his eleventh birthday.'],
    ['Gone Girl', 'Gillian Flynn', 'Thriller', 13.99, 415, '2012-05-24', 1700, '#2B2B2B', 'dark,twisted,psychological,marriage', 'A wife vanishes and her husband becomes the prime suspect.'],
    ['The Girl with the Dragon Tattoo', 'Stieg Larsson', 'Thriller', 14.49, 465, '2005-08-01', 1400, '#2B2B2B', 'dark,noir,mystery,investigation', 'A journalist and a hacker untangle a decades-old disappearance.'],
    ['The Silent Patient', 'Alex Michaelides', 'Thriller', 13.49, 325, '2019-02-05', 1600, '#7A2E3B', 'dark,twisted,psychological', 'A famous painter shoots her husband, then never speaks again.'],
    ['The Da Vinci Code', 'Dan Brown', 'Thriller', 12.99, 489, '2003-03-18', 2000, '#B5732E', 'mystery,conspiracy,fast-paced', 'A symbologist races through Paris chasing a religious secret.'],
    ['Murder on the Orient Express', 'Agatha Christie', 'Mystery', 8.99, 274, '1934-01-01', 1200, '#3E6B4A', 'classic,cozy,whodunit,puzzle', 'Poirot solves a murder aboard a snowbound luxury train.'],
    ['And Then There Were None', 'Agatha Christie', 'Mystery', 9.49, 272, '1939-11-06', 1500, '#2B2B2B', 'classic,dark,whodunit,suspense', 'Ten strangers die one by one on an isolated island.'],
    ['The ABC Murders', 'Agatha Christie', 'Mystery', 9.99, 256, '1936-01-06', 800, '#B5732E', 'classic,whodunit,puzzle', 'A serial killer taunts Poirot with an alphabetical pattern.'],
    ['Pride and Prejudice', 'Jane Austen', 'Romance', 7.99, 432, '1813-01-28', 1900, '#7A2E3B', 'classic,cozy,romance,witty', 'Elizabeth Bennet spar with the proud Mr. Darcy.'],
    ['The Notebook', 'Nicholas Sparks', 'Romance', 10.49, 214, '1996-10-01', 1100, '#C0563B', 'romance,emotional,classic', 'A love story read aloud from a worn notebook.'],
    ['Beach Read', 'Emily Henry', 'Romance', 12.99, 361, '2020-05-19', 950, '#B5732E', 'funny,romance,cozy,summer', 'Two rival writers swap genres for a summer by the lake.'],
    ['It Ends with Us', 'Colleen Hoover', 'Romance', 13.99, 384, '2016-08-02', 2300, '#7A2E3B', 'romance,emotional,contemporary', 'A florist confronts love, loss and hard choices.'],
    ['Sapiens', 'Yuval Noah Harari', 'History', 18.49, 443, '2011-01-01', 2400, '#B5732E', 'history,science,big-ideas', 'A brief history of humankind, from foragers to algorithms.'],
    ['The Silk Roads', 'Peter Frankopan', 'History', 19.99, 636, '2015-08-27', 700, '#3E6B4A', 'history,epic,world', 'A new history of the world told through its trade routes.'],
    ['Guns, Germs, and Steel', 'Jared Diamond', 'History', 17.49, 480, '1997-03-01', 900, '#2E5E8C', 'history,science,big-ideas', 'Why some societies conquered others, explained by geography.'],
    ['A Brief History of Time', 'Stephen Hawking', 'Science', 14.99, 212, '1988-04-01', 1300, '#2B2B2B', 'science,space,classic,physics', 'From the Big Bang to black holes, in plain language.'],
    ['Cosmos', 'Carl Sagan', 'Science', 15.99, 396, '1980-10-01', 1000, '#2E5E8C', 'science,space,classic,wonder', 'A poetic tour of the universe and our place in it.'],
    ['The Selfish Gene', 'Richard Dawkins', 'Science', 13.99, 360, '1976-01-01', 650, '#3E6B4A', 'science,evolution,big-ideas', 'A gene-centered view of evolution and behaviour.'],
    ['Astrophysics for People in a Hurry', 'Neil deGrasse Tyson', 'Science', 11.99, 224, '2017-05-02', 1250, '#2B2B2B', 'science,space,funny,short', 'The cosmos, distilled into bite-sized chapters.'],
    ['Atomic Habits', 'James Clear', 'Self-Help', 16.99, 320, '2018-10-16', 2500, '#B5732E', 'habits,productivity,bestseller', 'Tiny changes, remarkable results, one percent at a time.'],
    ['The 7 Habits of Highly Effective People', 'Stephen Covey', 'Self-Help', 14.99, 381, '1989-08-15', 1400, '#3E6B4A', 'habits,productivity,classic', 'Principles for personal and professional effectiveness.'],
    ['How to Win Friends and Influence People', 'Dale Carnegie', 'Self-Help', 11.99, 288, '1936-10-01', 1600, '#B5732E', 'classic,people,communication', 'Timeless advice on winning people over.'],
    ['The Subtle Art of Not Giving a F*ck', 'Mark Manson', 'Self-Help', 13.99, 224, '2016-09-13', 1800, '#C0563B', 'funny,irreverent,philosophy', 'A counterintuitive approach to living a good life.'],
    ['Clean Code', 'Robert C. Martin', 'Technology', 39.99, 464, '2008-08-01', 1600, '#2B2B2B', 'programming,craft,bestseller', 'A handbook of agile software craftsmanship.'],
    ['The Pragmatic Programmer', 'Andrew Hunt', 'Technology', 34.99, 352, '1999-10-20', 1200, '#2E5E8C', 'programming,craft,classic', 'Your journey to mastery, from journeyman to master.'],
    ['Eloquent JavaScript', 'Marijn Haverbeke', 'Technology', 24.99, 472, '2011-12-01', 850, '#B5732E', 'programming,javascript,web', 'A modern introduction to programming with JavaScript.'],
    ['Designing Data-Intensive Applications', 'Martin Kleppmann', 'Technology', 39.99, 616, '2017-03-16', 950, '#3E6B4A', 'programming,databases,systems', 'The big ideas behind reliable, scalable systems.'],
    ['1984', 'George Orwell', 'Classics', 7.49, 328, '1949-06-08', 2100, '#2B2B2B', 'classic,dark,dystopia,politics', 'Big Brother is watching in a totalitarian future.'],
    ['Animal Farm', 'George Orwell', 'Classics', 6.99, 112, '1945-08-17', 1700, '#3E6B4A', 'classic,politics,satire,short', 'A farmyard revolution curdles into tyranny.'],
    ['The Great Gatsby', 'F. Scott Fitzgerald', 'Classics', 7.99, 180, '1925-04-10', 1500, '#B5732E', 'classic,jazz-age,short,tragic', 'The green light at the end of a doomed dream.'],
    ['Crime and Punishment', 'Fyodor Dostoevsky', 'Classics', 9.99, 671, '1866-01-01', 900, '#7A2E3B', 'classic,dark,psychological,philosophy', 'A student commits a murder and unravels under guilt.'],
    ['The Midnight Library', 'Matt Haig', 'Fiction', 13.99, 304, '2020-08-13', 1900, '#2E5E8C', 'cozy,philosophy,hope,contemporary', 'Between life and death, a library of possible lives.'],
    ['The Alchemist', 'Paulo Coelho', 'Fiction', 9.99, 208, '1988-01-01', 2200, '#B5732E', 'cozy,inspiring,fable,quest', 'A shepherd follows his dream across the desert.'],
    ['The Kite Runner', 'Khaled Hosseini', 'Fiction', 12.99, 371, '2003-05-29', 1600, '#C0563B', 'emotional,friendship,redemption', 'A boy seeks redemption across decades and continents.'],
    ['Life of Pi', 'Yann Martel', 'Fiction', 11.99, 319, '2001-09-11', 1300, '#2E5E8C', 'adventure,philosophy,survival', 'A boy survives the Pacific on a lifeboat with a tiger.'],
    ['Steve Jobs', 'Walter Isaacson', 'Biography', 18.99, 656, '2011-10-24', 1400, '#2B2B2B', 'biography,tech,inspiring', 'The exclusive biography of Apple’s co-founder.'],
    ['Becoming', 'Michelle Obama', 'Biography', 16.99, 448, '2018-11-13', 1800, '#7A2E3B', 'biography,inspiring,memoir', 'The intimate memoir of the former First Lady.'],
    ['Educated', 'Tara Westover', 'Biography', 14.99, 334, '2018-02-20', 1500, '#3E6B4A', 'biography,inspiring,memoir', 'A girl leaves a survivalist family to earn a PhD.'],
  ];

  // The three newest titles (within 35 days); everything else is older.
  const newest = {'Project Hail Mary': 3, 'The Midnight Library': 12, 'Beach Read': 25};
  final bookIds = <String, int>{};
  for (final b in books) {
    final title = b[0] as String;
    final created = newest.containsKey(title) ? daysAgo(newest[title]!) : daysAgo(45 + rnd.nextInt(500));
    final id = await db.insert('books', {
      'title': title,
      'author_id': await author(b[1] as String),
      'genre_id': genreId[b[2]]!,
      'description': b[9],
      'price': b[3],
      'pages': b[4],
      'published': b[5],
      'stock': 8 + rnd.nextInt(33),
      'sold': b[6],
      'cover_color': b[7],
      'tags': b[8],
      'created_at': created,
    });
    bookIds[title] = id;
  }

  // Users.
  final users = <List<dynamic>>[
    ['Admin', 'admin@bookstore.com', 'Admin@123', 1],
    ['Ayesha Khan', 'ayesha@example.com', 'Password@123', 0],
    ['Ali Raza', 'ali@example.com', 'Password@123', 0],
    ['Sara Ahmed', 'sara@example.com', 'Password@123', 0],
    ['Demo Reader', 'demo@bookstore.com', 'Demo@1234', 0],
  ];
  final userIds = <int>[];
  for (final u in users) {
    userIds.add(await db.insert('users', {
      'name': u[0],
      'email': u[1],
      'password_hash': PasswordHasher.hash(u[2] as String),
      'provider': 'email',
      'is_admin': u[3],
      'is_active': 1,
      'phone': '',
      'created_at': daysAgo(200 + rnd.nextInt(200)),
    }));
  }
  final demoId = userIds[4];

  // Reviews: 1–3 per book from shoppers (ids 2–5).
  const snippets = [
    'Could not put it down — stayed up far too late.',
    'Beautifully written and deeply moving.',
    'A new favourite. I keep recommending it.',
    'Slow start, but the payoff is worth it.',
    'Exactly what I needed this month.',
    'The characters feel completely real.',
    'Smart, surprising and satisfying.',
    'I have already bought a copy for a friend.',
    'Not quite for me, but I can see the appeal.',
    'A masterclass in storytelling.',
  ];
  for (final entry in bookIds.entries) {
    final count = 1 + rnd.nextInt(3);
    final reviewers = <int>{2, 3, 4, 5}.toList()..shuffle(rnd);
    for (var i = 0; i < count; i++) {
      final uid = userIds[reviewers[i] - 1];
      final rating = rnd.nextInt(10) < 7 ? 5 : 4;
      await db.insert('reviews', {
        'book_id': entry.value,
        'user_id': uid,
        'rating': rating,
        'body': snippets[rnd.nextInt(snippets.length)],
        'created_at': daysAgo(5 + rnd.nextInt(120)),
      });
    }
  }

  // A few review likes.
  final allReviews = await db.query('reviews', columns: ['id']);
  for (final r in allReviews) {
    if (rnd.nextInt(3) == 0) {
      final uid = userIds[1 + rnd.nextInt(4)];
      try {
        await db.insert('review_likes', {'review_id': r['id'], 'user_id': uid});
      } catch (_) {/* unique clash is fine */}
    }
  }

  // Demo customer: address, card, wishlist, two orders.
  await db.insert('addresses', {
    'user_id': demoId, 'label': 'Home', 'full_name': 'Demo Reader',
    'line1': '12 Marine Drive, Block 4', 'city': 'Karachi', 'region': 'Sindh',
    'postal_code': '75600', 'country': 'Pakistan', 'phone': '+92 300 1234567', 'is_default': 1,
  });
  await db.insert('payment_methods', {
    'user_id': demoId, 'brand': 'Visa', 'last4': '4242', 'exp_month': 12, 'exp_year': 2029, 'is_default': 1,
  });
  for (final bid in [4, 20, 41]) {
    await db.insert('wishlist_items', {'user_id': demoId, 'book_id': bid});
  }

  Future<void> seedOrder({
    required String status,
    required int days,
    required String tracking,
    required List<List<dynamic>> items,
  }) async {
    final subtotal = items.fold<double>(0, (s, it) => s + (it[1] as double) * (it[2] as int));
    final total = subtotal >= 30 ? subtotal : subtotal + 2.99;
    final oid = await db.insert('orders', {
      'user_id': demoId, 'status': status, 'total': double.parse(total.toStringAsFixed(2)),
      'ship_name': 'Demo Reader', 'ship_line1': '12 Marine Drive, Block 4', 'ship_city': 'Karachi',
      'payment': 'Visa •••• 4242', 'tracking_no': tracking, 'created_at': daysAgo(days),
    });
    for (final it in items) {
      await db.insert('order_items', {
        'order_id': oid, 'book_id': bookIds[it[0]]!, 'title': it[0], 'unit_price': it[1], 'qty': it[2],
      });
    }
    // Build the event timeline up to the current status.
    const flow = ['Placed', 'Processing', 'Shipped', 'Out for delivery', 'Delivered'];
    final upto = flow.indexOf(status);
    for (var i = 0; i <= upto; i++) {
      await db.insert('order_events', {
        'order_id': oid, 'status': flow[i], 'note': _eventNote(flow[i]),
        'at': daysAgo(days - i),
      });
    }
  }

  await seedOrder(status: 'Delivered', days: 21, tracking: 'TRK-90311-PK', items: [
    ['Dune', 18.99, 1], ['Atomic Habits', 16.99, 1],
  ]);
  await seedOrder(status: 'Shipped', days: 2, tracking: 'TRK-90455-PK', items: [
    ['Project Hail Mary', 16.99, 1], ['Gone Girl', 13.99, 1],
  ]);
}

String _eventNote(String status) {
  switch (status) {
    case 'Placed':
      return 'Order received and payment confirmed.';
    case 'Processing':
      return 'Picking and packing your books.';
    case 'Shipped':
      return 'Handed to the courier.';
    case 'Out for delivery':
      return 'On the van for delivery today.';
    case 'Delivered':
      return 'Delivered. Enjoy your reading!';
    default:
      return '';
  }
}
