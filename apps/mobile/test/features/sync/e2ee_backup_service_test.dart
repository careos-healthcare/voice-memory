import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/sync/e2ee_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the database is encrypted before it is uploaded', () async {
    final plaintext = Uint8List.fromList(utf8.encode('SECRET_JOURNAL_ROW'));
    Uint8List? uploaded;
    final service = E2eeBackupService(iterations: 2000);

    final blob = await service.backup(
      databaseBytes: plaintext,
      passphrase: 'correct horse battery',
      upload: (sealed) async {
        uploaded = Uint8List.fromList(sealed.wireBytes);
      },
    );

    expect(uploaded, isNotNull);
    expect(_contains(uploaded!, plaintext), isFalse);
    expect(_contains(blob.ciphertext, plaintext), isFalse);
    expect(blob.mac, isNotEmpty);
    final opened = await service.restore(
      blob: blob,
      passphrase: 'correct horse battery',
    );
    expect(opened, plaintext);
  });

  test('a blank passphrase never starts an upload', () async {
    var uploaded = false;
    final service = E2eeBackupService(iterations: 2000);

    await expectLater(
      service.backup(
        databaseBytes: Uint8List.fromList([1, 2, 3]),
        passphrase: '   ',
        upload: (sealed) async {
          uploaded = true;
        },
      ),
      throwsArgumentError,
    );
    expect(uploaded, isFalse);
  });

  test('the wrong passphrase cannot open the backup', () async {
    final service = E2eeBackupService(iterations: 2000);
    final blob = await service.protect(
      databaseBytes: Uint8List.fromList(utf8.encode('SECRET_JOURNAL_ROW')),
      passphrase: 'correct horse battery',
    );

    expect(
      service.restore(blob: blob, passphrase: 'another secret phrase'),
      throwsA(isA<E2eeBackupException>()),
    );
  });
}

bool _contains(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
