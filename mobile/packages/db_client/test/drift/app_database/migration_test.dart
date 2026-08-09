// dart format width=80
// ignore_for_file: unused_local_variable
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('v2 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();
    });

    test('migrates v1 schema to v2', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();
    });

    test('backfills follower timestamps for rows carrying counts', () async {
      // A v1 row has counts but no follower timestamp. Leaving it NULL after
      // the upgrade would make every reader fall back to cached_at, which
      // unrelated profile-stat writes keep bumping — so the staleness clock
      // would restart forever and an already-wrong count could never be
      // replaced.
      final writtenAt = DateTime(2026, 8, 8, 22);
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, follower_count, following_count, cached_at) '
        'VALUES (?, ?, ?, ?)',
        [
          'withcounts',
          98,
          20,
          writtenAt.millisecondsSinceEpoch ~/ 1000,
        ],
      );
      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics (pubkey, video_count, cached_at) '
        'VALUES (?, ?, ?)',
        ['nocounts', 5, writtenAt.millisecondsSinceEpoch ~/ 1000],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);

      final rows = await db
          .customSelect(
            'SELECT pubkey, follower_counts_updated_at, cached_at '
            'FROM profile_statistics ORDER BY pubkey',
          )
          .get();
      final byPubkey = {
        for (final row in rows) row.read<String>('pubkey'): row,
      };

      expect(
        byPubkey['withcounts']!.read<int?>('follower_counts_updated_at'),
        equals(byPubkey['withcounts']!.read<int>('cached_at')),
      );
      // The row that never held counts gets no follower clock, so startup
      // cleanup sweeps it on the ordinary 5-minute stats rule rather than
      // letting the cached_at fallback buy it the long follower window.
      expect(byPubkey.containsKey('nocounts'), isFalse);

      await db.close();
    });
  });
}
