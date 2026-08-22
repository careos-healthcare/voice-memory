import 'package:archiveme_mobile/security/private_storage_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known stores include journal and secure storage', () {
    final stores = PrivateStorageAudit.knownStores();
    expect(stores.map((s) => s.store), contains('JournalStore'));
    expect(stores.map((s) => s.store), contains('SecureStorageService'));
  });

  test('flags sensitive plaintext backends excluding encrypted journal', () {
    final plaintext = PrivateStorageAudit.sensitivePlaintextStores();
    expect(plaintext.any((s) => s.store == 'JournalStore'), isFalse);
    expect(plaintext.any((s) => s.store == 'MobilePrefsStore'), isTrue);
    expect(plaintext.every((s) => !s.encrypted), isTrue);
  });

  test('audit log prefix is stable', () {
    expect(PrivateStorageAudit.logPrefix, 'ARCHIVEME_SECURITY_AUDIT:');
  });
}