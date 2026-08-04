import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/private_storage_audit.dart';

void main() {
  test('known stores include journal and secure storage', () {
    final stores = PrivateStorageAudit.knownStores();
    expect(stores.map((s) => s.store), contains('JournalStore'));
    expect(stores.map((s) => s.store), contains('SecureStorageService'));
  });

  test('excludes encrypted journal and preferences from plaintext stores', () {
    final plaintext = PrivateStorageAudit.sensitivePlaintextStores();
    expect(plaintext.any((s) => s.store == 'JournalStore'), isFalse);
    expect(plaintext.any((s) => s.store == 'MobilePrefsStore'), isFalse);
    expect(plaintext.every((s) => !s.encrypted), isTrue);
  });

  test('catalogs every durable audio staging store honestly', () {
    final stores = PrivateStorageAudit.knownStores();
    final byName = {for (final store in stores) store.store: store};

    expect(byName['TranscriptionLedger']?.encrypted, isTrue);
    expect(byName['CaptureApiRetryQueue']?.encrypted, isTrue);
    expect(byName['EmergencyVaultStorage']?.encrypted, isFalse);
    expect(byName['EmergencyVaultStorage']?.sensitive, isTrue);
    expect(
      PrivateStorageAudit.sensitivePlaintextStores().map(
        (store) => store.store,
      ),
      contains('EmergencyVaultStorage'),
    );
  });

  test('documents plaintext model weights as non-user data', () {
    final model = PrivateStorageAudit.knownStores().singleWhere(
      (store) => store.store == 'OnDeviceModelWeights',
    );
    expect(model.encrypted, isFalse);
    expect(model.sensitive, isFalse);
    expect(model.notes, contains('contains no user or archive data'));
  });

  test(
    'retained recordings are encrypted and only active work is plaintext',
    () {
      final stores = PrivateStorageAudit.knownStores();
      final recordings = stores.singleWhere(
        (store) => store.store == 'VoiceRecordings',
      );
      final working = stores.singleWhere(
        (store) => store.store == 'ActiveCaptureWorkingFiles',
      );

      expect(recordings.encrypted, isTrue);
      expect(recordings.notes, contains('AES-256-GCM'));
      expect(working.encrypted, isFalse);
      expect(
        working.notes,
        contains('never referenced by new journal metadata'),
      );
    },
  );

  test('audit log prefix is stable', () {
    expect(PrivateStorageAudit.logPrefix, 'ARCHIVEME_SECURITY_AUDIT:');
  });
}
