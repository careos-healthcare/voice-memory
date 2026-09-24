import 'dart:io';

import 'package:archiveme_mobile/storage/sqlite/sqlcipher_cipher_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('empty cipher_version is refused for a release open', () {
    expect(
      () => SqlcipherCipherGuard.refuseIfUnlinked('', release: true),
      throwsA(isA<SqlcipherUnavailableException>()),
    );
    SqlcipherCipherGuard.refuseIfUnlinked('', release: false);
    SqlcipherCipherGuard.refuseIfUnlinked('4.10.0', release: true);
  });

  test('on-disk SQLCipher file is not readable by an unkeyed sqlite3 open', () {
    final dir = Directory.systemTemp.createTempSync('sqlcipher-unreadable');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final path = '${dir.path}/journal.db';
    const passphrase = 'integration-test-passphrase';

    final keyed = sqlite3.open(path);
    try {
      keyed.execute("PRAGMA key = '$passphrase'");
      final version = keyed.select('PRAGMA cipher_version');
      expect(version, isNotEmpty);
      final cipher = version.first.values.first?.toString().trim() ?? '';
      expect(cipher, isNotEmpty, reason: 'SQLCipher must be the linked sqlite3');
      keyed.execute('CREATE TABLE secret (note TEXT NOT NULL)');
      keyed.execute("INSERT INTO secret (note) VALUES ('private-journal')");
    } finally {
      keyed.dispose();
    }

    final header = File(path).readAsBytesSync().take(15).toList();
    expect(
      String.fromCharCodes(header),
      isNot('SQLite format 3'),
    );

    final plain = sqlite3.open(path);
    try {
      expect(
        () => plain.select('SELECT note FROM secret'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      plain.dispose();
    }
  });
}
