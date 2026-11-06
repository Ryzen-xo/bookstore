import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';
import 'seed.dart';

/// Current UTC timestamp in the sortable `YYYY-MM-DD HH:MM:SS` format.
String nowTs() {
  final d = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// Opens (and on first run, creates + seeds) the on-device database.
class AppDatabase {
  AppDatabase._();

  static const int version = 1;
  static const String fileName = 'shelf.db';

  /// [pathOverride] lets tests pass [inMemoryDatabasePath].
  static Future<Database> open({String? pathOverride}) async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), fileName);
    final db = await openDatabase(
      path,
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Split the schema into individual statements and run them.
        for (final stmt in kSchema.split(';')) {
          final s = stmt.trim();
          if (s.isNotEmpty) await db.execute(s);
        }
        await seedDatabase(db);
      },
    );
    // Ensure FK enforcement even for an already-open handle.
    await db.execute('PRAGMA foreign_keys = ON');
    return db;
  }
}
