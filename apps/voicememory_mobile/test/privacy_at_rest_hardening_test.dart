import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/security/private_storage_audit.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: 'You sounded tired.',
  repeatedSignal: '',
);

JournalEntry _entry({
  required String id,
  String transcript = 'Private reflection text',
  String? localAudioPath,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 6, 1),
    transcript: transcript,
    durationSeconds: 12,
    reflection: _reflection(),
    syncStatus: SyncStatus.localOnly,
    localAudioPath: localAudioPath,
  );
}

void main() {
  late Directory tempDir;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vm_privacy_at_rest_');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
  });

  group('PrivateDataEncryptionKeyStore', () {
    test('stores key only in secure key store abstraction', () async {
      final keyBytes = await keyStore.ensureKey();
      expect(keyBytes.length, SecurePrivateDataEncryptionKeyStore.keyByteLength);

      final roundTrip = await keyStore.readKeyBytes();
      expect(roundTrip, keyBytes);

      await keyStore.deleteKey();
      expect(await keyStore.readKeyBytes(), isNull);
    });
  });

  group('EncryptedJsonFileStore', () {
    test('does not write plaintext private text to disk', () async {
      final encryptedFile = File('${tempDir.path}/private.enc');
      final store = EncryptedJsonFileStore(file: encryptedFile, keyStore: keyStore);
      const secret = 'Private reflection text must not appear on disk';

      await store.writeJson([
        {'transcript': secret},
      ]);

      final raw = await encryptedFile.readAsString();
      expect(raw, isNot(contains(secret)));
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          encryptedFile,
          secret,
        ),
        isTrue,
      );
    });

    test('round-trips JSON payloads', () async {
      final encryptedFile = File('${tempDir.path}/roundtrip.enc');
      final store = EncryptedJsonFileStore(file: encryptedFile, keyStore: keyStore);
      final payload = [
        {'id': 'a', 'transcript': 'Saved moment'},
      ];

      await store.writeJson(payload);
      final decoded = await store.readJson();
      expect(decoded, payload);
    });
  });

  group('JournalStore encryption migration', () {
    test('migrates plaintext journal and removes private transcript from legacy file',
        () async {
      const secret = 'Secret transcript after migration';
      final legacyPath = '${tempDir.path}/journal_entries.json';
      final legacyFile = File(legacyPath);
      await legacyFile.writeAsString(
        jsonEncode([
          _entry(id: 'm1', transcript: secret).toJson(),
        ]),
      );

      final store = await JournalStore.open(
        legacyPath,
        keyStore: keyStore,
      );

      final loaded = await store.loadAll();
      expect(loaded.single.transcript, secret);

      final encryptedFile = File(JournalStore.encryptedPathFor(legacyPath));
      expect(await encryptedFile.exists(), isTrue);
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          encryptedFile,
          secret,
        ),
        isTrue,
      );
      expect(legacyFile.existsSync(), isFalse);
    });

    test('new journal writes encrypted file only', () async {
      final legacyPath = '${tempDir.path}/fresh_journal.json';
      final store = await JournalStore.open(
        legacyPath,
        keyStore: keyStore,
      );
      await store.save(_entry(id: 'n1'));

      final legacyFile = File(legacyPath);
      final encryptedFile = File(JournalStore.encryptedPathFor(legacyPath));
      expect(legacyFile.existsSync(), isFalse);
      expect(encryptedFile.existsSync(), isTrue);
    });
  });

  group('PrivateDataService cleanup', () {
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late PrivateDataService service;

    setUp(() async {
      journal = await JournalStore.open(
        '${tempDir.path}/entries.json',
        keyStore: keyStore,
      );
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      service = PrivateDataService(
        journalStore: journal,
        prefs: prefs,
        tempDirProvider: () async => tempDir,
      );
    });

    test('deleteEntrySecurely removes local audio file path', () async {
      final audioFile = File('${tempDir.path}/recording.m4a');
      await audioFile.writeAsString('fake audio bytes');
      await journal.save(_entry(id: 'e1', localAudioPath: audioFile.path));

      final result = await service.deleteEntrySecurely('e1');
      expect(result.deleted, isTrue);
      expect(result.audioFileRemoved, isTrue);
      expect(audioFile.existsSync(), isFalse);
    });

    test('wipe clears journal drafts temp audio and insight caches', () async {
      final tempRecording = File('${tempDir.path}/vm_rec_test.m4a');
      await tempRecording.writeAsString('temp');
      await journal.save(
        _entry(
          id: 'e2',
          transcript: '[draft] offline capture',
          localAudioPath: tempRecording.path,
        ),
      );
      await prefs.writeMap('archiveCollections', {'packs': ['a']});
      await prefs.writeMap('archiveFacts', {'facts': ['x']});

      await service.wipeAllLocalArchive(
        confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
      );

      expect(await journal.loadAll(), isEmpty);
      expect(tempRecording.existsSync(), isFalse);
      expect(await prefs.readMap('archiveCollections'), isEmpty);
      expect(await prefs.readMap('archiveFacts'), isEmpty);
    });

    test('export remains sanitized', () async {
      await journal.save(
        _entry(
          id: 'secret-id',
          localAudioPath: '/tmp/secret.m4a',
        ),
      );

      final payload = await service.buildSanitizedExport();
      final json = payload.toJson();
      expect(json, contains('"app": "ArchiveMe"'));
      expect(json, contains('Private reflection text'));
      expect(json, isNot(contains('secret-id')));
      expect(json, isNot(contains('/tmp/secret.m4a')));
      expect(json, isNot(contains('syncStatus')));
    });
  });

  group('Privacy copy hardening', () {
    test('canonical promises stay honest', () {
      expect(PrivacyCopyPolicy.privateByDefault, 'Private by default');
      expect(PrivacyCopyPolicy.lockArchiveMe, 'Protect this archive');
      expect(PrivacyCopyPolicy.deleteLocalArchive, 'Delete local archive');
      expect(
        PrivacyCopyPolicy.transcriptionAnalysisWhenUsed,
        contains('transcription or analysis'),
      );
    });

    test('does not claim everything stays on device', () {
      for (final path in PrivacyCopyPolicy.consumerPrivacySources) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(
          source.contains('everything stays on device'),
          isFalse,
          reason: path,
        );
      }
    });

    test('does not claim fully encrypted archive', () {
      for (final path in PrivacyCopyPolicy.consumerPrivacySources) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(
          source.contains('fully encrypted archive'),
          isFalse,
          reason: path,
        );
        expect(
          source.contains('all journal data is encrypted'),
          isFalse,
          reason: path,
        );
      }
    });

    test('rejects banned security superlatives in policy guard', () {
      for (final bad in const [
        '100% secure',
        'military grade',
        'unhackable',
        'anonymous archive',
        'impossible to access',
        'nothing ever leaves your device',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(bad),
          isNotEmpty,
          reason: bad,
        );
      }
    });

    for (final path in PrivacyCopyPolicy.consumerPrivacySources) {
      test('$path has no unsafe privacy promises', () {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
        final source = File(path).readAsStringSync();
        final violations = PrivacyCopyPolicy.scanFile(path, source);
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    }
  });

  group('PrivateStorageAudit', () {
    test('journal is encrypted in audit registry', () {
      final journal = PrivateStorageAudit.knownStores().firstWhere(
        (s) => s.store == 'JournalStore',
      );
      expect(journal.encrypted, isTrue);
    });

    test('prefs remain plaintext in audit registry', () {
      final prefs = PrivateStorageAudit.knownStores().firstWhere(
        (s) => s.store == 'MobilePrefsStore',
      );
      expect(prefs.encrypted, isFalse);
    });
  });
}
