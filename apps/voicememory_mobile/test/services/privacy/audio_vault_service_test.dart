import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/services/privacy/sensitive_temporary_audio_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory temporaryDirectory;
  late InMemoryAudioVaultKeyStore keyStore;
  late AudioVaultService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('audio_vault_test_');
    vaultDirectory = Directory('${root.path}/vault');
    temporaryDirectory = Directory('${root.path}/temp');
    keyStore = InMemoryAudioVaultKeyStore();
    service = AudioVaultService(
      keyStore: keyStore,
      vaultDirectory: () async => vaultDirectory,
      temporaryDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('seals multiple chunks and deletes the plaintext source', () async {
    final clear = Uint8List.fromList(
      List<int>.generate(
        AudioVaultService.chunkBytes + 173,
        (index) => index % 251,
      ),
    );
    final source = File('${root.path}/vm_rec_1.m4a');
    await source.writeAsBytes(clear, flush: true);

    final encrypted = await service.sealRecording(source, vaultId: 'entry-1');

    expect(encrypted.path, endsWith('.m4a.enc'));
    expect(await source.exists(), isFalse);
    expect(
      await encrypted.readAsBytes(),
      isNot(contains(clear.sublist(0, 64))),
    );

    final restored = await service.readPlaintextBytes(encrypted.path);
    expect(restored, clear);
    restored.fillRange(0, restored.length, 0);
    clear.fillRange(0, clear.length, 0);
  });

  test('decrypted lease is deleted when the operation finishes', () async {
    final source = File('${root.path}/vm_rec_2.aac');
    await source.writeAsBytes(List<int>.generate(256, (index) => index));
    final encrypted = await service.sealRecording(source, vaultId: 'entry-2');
    String? leasePath;

    await service.withDecryptedFile(encrypted.path, (file) async {
      leasePath = file.path;
      expect(await file.exists(), isTrue);
      expect(await file.length(), 256);
    });

    expect(File(leasePath!).existsSync(), isFalse);
  });

  test('managed recovery seals locally without retaining plaintext', () async {
    final protected = Directory('${root.path}/protected');
    final temporaryStore = SensitiveTemporaryAudioStore(
      directory: () async => protected,
      legacyDirectories: const [],
    );
    final managedVault = AudioVaultService(
      keyStore: keyStore,
      vaultDirectory: () async => vaultDirectory,
      temporaryAudioStore: temporaryStore,
    );
    final source = await temporaryStore.create(
      ownerId: 'voice-capture',
      extension: 'wav',
    );
    await source.writeAsBytes([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
      ...List<int>.filled(1200, 1),
    ]);
    await temporaryStore.markRecoverable(
      file: source,
      ownerId: 'voice-capture',
    );
    String? committedReference;

    final result = await managedVault.recoverOrphanRecordings(
      commitRecovered: (_, reference) async {
        committedReference = reference;
      },
    );

    expect(result.recovered, hasLength(1));
    expect(committedReference, startsWith(AudioVaultService.referencePrefix));
    expect(await source.exists(), isFalse);
    expect(await managedVault.exists(committedReference!), isTrue);
  });

  test(
    'sealCapture returns an opaque reference and preserves source',
    () async {
      final source = File('${root.path}/vm_rec_transaction.m4a');
      final clear = List<int>.filled(256, 3)..setRange(4, 8, 'ftyp'.codeUnits);
      await source.writeAsBytes(clear, flush: true);

      final sealed = await service.sealCapture('entry-transaction', source);

      expect(sealed.reference, startsWith(AudioVaultService.referencePrefix));
      expect(sealed.reference, isNot(contains(root.path)));
      expect(await source.exists(), isTrue);
      expect(await service.readPlaintextBytes(sealed.reference), clear);
    },
  );

  test('simultaneous decrypt leases use different working files', () async {
    final source = File('${root.path}/vm_rec_concurrent.aac');
    await source.writeAsBytes(List<int>.generate(256, (index) => index));
    final encrypted = await service.sealRecording(
      source,
      vaultId: 'concurrent',
    );

    final first = await service.openDecryptedLease(encrypted.path);
    final second = await service.openDecryptedLease(encrypted.path);
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first.file.path, isNot(second.file.path));
    expect(await first.file.exists(), isTrue);
    expect(await second.file.exists(), isTrue);
  });

  test('tampering is rejected and leaves no plaintext lease', () async {
    final source = File('${root.path}/vm_rec_3.wav');
    await source.writeAsBytes(List<int>.filled(128, 7));
    final encrypted = await service.sealRecording(source, vaultId: 'entry-3');
    final bytes = await encrypted.readAsBytes();
    bytes[bytes.length - 17] ^= 0xff;
    await encrypted.writeAsBytes(bytes, flush: true);

    await expectLater(
      service.openDecryptedLease(encrypted.path),
      throwsA(anything),
    );
    if (temporaryDirectory.existsSync()) {
      expect(temporaryDirectory.listSync(), isEmpty);
    }
  });

  test(
    'fresh nonces produce different ciphertext for identical audio',
    () async {
      final first = File('${root.path}/first.aac');
      final second = File('${root.path}/second.aac');
      final clear = List<int>.filled(256, 11);
      await first.writeAsBytes(clear);
      await second.writeAsBytes(clear);

      final firstEncrypted = await service.sealRecording(
        first,
        vaultId: 'nonce-1',
      );
      final secondEncrypted = await service.sealRecording(
        second,
        vaultId: 'nonce-2',
      );

      expect(
        await firstEncrypted.readAsBytes(),
        isNot(await secondEncrypted.readAsBytes()),
      );
    },
  );

  test('truncated ciphertext is rejected', () async {
    final source = File('${root.path}/vm_rec_truncated.wav');
    await source.writeAsBytes(List<int>.filled(256, 12));
    final encrypted = await service.sealRecording(source, vaultId: 'truncated');
    final bytes = await encrypted.readAsBytes();
    await encrypted.writeAsBytes(bytes.sublist(0, bytes.length - 8));

    await expectLater(
      service.readPlaintextBytes(encrypted.path),
      throwsA(isA<AudioVaultException>()),
    );
  });

  test('missing key fails closed when encrypted files exist', () async {
    await vaultDirectory.create(recursive: true);
    await File('${vaultDirectory.path}/existing.m4a.enc').writeAsBytes([1]);
    final source = File('${root.path}/vm_rec_4.m4a');
    await source.writeAsBytes(List<int>.filled(64, 1));

    await expectLater(
      service.sealRecording(source, vaultId: 'entry-4'),
      throwsA(isA<AudioVaultKeyUnavailable>()),
    );
    expect(await source.exists(), isTrue);
  });

  test(
    'startup recovery seals valid orphans and purges invalid files',
    () async {
      await temporaryDirectory.create(recursive: true);
      final valid = File('${temporaryDirectory.path}/vm_rec_valid.m4a');
      final invalid = File('${temporaryDirectory.path}/vm_rec_invalid.m4a');
      final tooShort = File('${temporaryDirectory.path}/vm_rec_short.m4a');
      final staleLease = File(
        '${temporaryDirectory.path}/vm_audio_lease_stale.m4a',
      );
      final validM4a = List<int>.filled(1200, 0)
        ..setRange(4, 8, 'ftyp'.codeUnits);
      final shortM4a = List<int>.filled(128, 0)
        ..setRange(4, 8, 'ftyp'.codeUnits);
      await valid.writeAsBytes(validM4a);
      await invalid.writeAsBytes([1, 2, 3]);
      await tooShort.writeAsBytes(shortM4a);
      await staleLease.writeAsBytes(List<int>.filled(64, 4));

      final result = await service.recoverOrphanRecordings();

      expect(result.recovered, hasLength(1));
      expect(
        result.purged,
        containsAll([invalid.path, tooShort.path, staleLease.path]),
      );
      expect(await valid.exists(), isTrue);
      expect(await service.exists(result.recovered.single), isTrue);
      expect(await invalid.exists(), isFalse);
      expect(await staleLease.exists(), isFalse);
    },
  );

  test('journal migrator rewrites legacy plaintext references', () async {
    final journal = await JournalStore.open(
      '${root.path}/journal.json',
      ownerArchiveId: 'local',
      encryptAtRest: false,
    );
    final source = File('${root.path}/legacy.m4a');
    final validM4a = List<int>.filled(128, 0)..setRange(4, 8, 'ftyp'.codeUnits);
    await source.writeAsBytes(validM4a);
    await journal.save(
      JournalEntry(
        id: 'legacy-entry',
        createdAt: DateTime.utc(2026, 7, 29),
        transcript: 'Legacy',
        durationSeconds: 4,
        reflection: const Reflection(
          mood: 'calm',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
        localAudioPath: source.path,
      ),
    );

    await AudioVaultJournalMigrator(
      service,
    ).migrateAndRecover(journalStore: journal);

    final migrated = await journal.getById('legacy-entry');
    expect(migrated?.localAudioPath, isNull);
    expect(
      migrated?.localAudioVaultRef,
      startsWith(AudioVaultService.referencePrefix),
    );
    expect(await service.exists(migrated!.localAudioVaultRef!), isTrue);
    expect(source.existsSync(), isFalse);

    final reference = migrated.localAudioVaultRef;
    await AudioVaultJournalMigrator(
      service,
    ).migrateAndRecover(journalStore: journal);
    expect(
      (await journal.getById('legacy-entry'))?.localAudioVaultRef,
      reference,
    );
  });

  test(
    'journal migrator removes a duplicate legacy path only after save',
    () async {
      final journal = await JournalStore.open(
        '${root.path}/duplicate-journal.json',
        ownerArchiveId: 'local',
        encryptAtRest: false,
      );
      final capture = File('${root.path}/capture.m4a');
      final duplicate = File('${root.path}/duplicate.m4a');
      final validM4a = List<int>.filled(128, 0)
        ..setRange(4, 8, 'ftyp'.codeUnits);
      await capture.writeAsBytes(validM4a);
      await duplicate.writeAsBytes(validM4a);
      final sealed = await service.sealCapture('dual-entry', capture);
      await journal.save(
        JournalEntry(
          id: 'dual-entry',
          createdAt: DateTime.utc(2026, 7, 29),
          transcript: 'Dual legacy state',
          durationSeconds: 4,
          reflection: const Reflection(
            mood: 'calm',
            emotionalIntensity: 1,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
          localAudioPath: duplicate.path,
          localAudioVaultRef: sealed.reference,
        ),
      );

      await AudioVaultJournalMigrator(
        service,
      ).migrateAndRecover(journalStore: journal);

      final normalized = await journal.getById('dual-entry');
      expect(normalized?.localAudioPath, isNull);
      expect(normalized?.localAudioVaultRef, sealed.reference);
      expect(await duplicate.exists(), isFalse);
      expect(await service.exists(sealed.reference), isTrue);
      expect(await capture.exists(), isTrue);
    },
  );

  test('missing legacy audio remains explicit for later recovery', () async {
    final journal = await JournalStore.open(
      '${root.path}/missing-journal.json',
      ownerArchiveId: 'local',
      encryptAtRest: false,
    );
    const missing = '/missing/private/recording.m4a';
    await journal.save(
      JournalEntry(
        id: 'missing-entry',
        createdAt: DateTime.utc(2026, 7, 29),
        transcript: 'Legacy',
        durationSeconds: 4,
        reflection: const Reflection(
          mood: 'calm',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
        localAudioPath: missing,
      ),
    );

    await AudioVaultJournalMigrator(
      service,
    ).migrateAndRecover(journalStore: journal);

    final retained = await journal.getById('missing-entry');
    expect(retained?.localAudioPath, missing);
    expect(retained?.localAudioVaultRef, isNull);
  });

  test('startup migrator commits a valid orphan before deleting it', () async {
    final journal = await JournalStore.open(
      '${root.path}/orphan-journal.json',
      ownerArchiveId: 'local',
      encryptAtRest: false,
    );
    await temporaryDirectory.create(recursive: true);
    final orphan = File('${temporaryDirectory.path}/vm_rec_orphan.m4a');
    final bytes = List<int>.filled(1200, 0)..setRange(4, 8, 'ftyp'.codeUnits);
    await orphan.writeAsBytes(bytes, flush: true);

    await AudioVaultJournalMigrator(service).migrateAndRecover(
      journalStore: journal,
      temporaryDirectory: temporaryDirectory,
    );

    final recovered = (await journal.loadAll()).single;
    expect(recovered.id, startsWith('recovered-audio-'));
    expect(
      recovered.localAudioVaultRef,
      startsWith(AudioVaultService.referencePrefix),
    );
    expect(await service.exists(recovered.localAudioVaultRef!), isTrue);
    expect(await orphan.exists(), isFalse);
  });

  test('interrupted partials and working files are purged', () async {
    await vaultDirectory.create(recursive: true);
    await temporaryDirectory.create(recursive: true);
    final partial = File('${vaultDirectory.path}/abandoned.m4a.enc.partial');
    final working = File(
      '${temporaryDirectory.path}/vm_rec_abandoned.working.m4a',
    );
    final temporary = File('${temporaryDirectory.path}/vm_rec_abandoned.tmp');
    await partial.writeAsBytes([1, 2, 3]);
    await working.writeAsBytes([1, 2, 3]);
    await temporary.writeAsBytes([1, 2, 3]);

    await service.recoverInterruptedOperations();

    expect(await partial.exists(), isFalse);
    expect(await working.exists(), isFalse);
    expect(await temporary.exists(), isFalse);
  });
}
