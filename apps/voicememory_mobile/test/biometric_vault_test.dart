import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/privacy/biometric_lock_overlay.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_job.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_job_database.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_ledger.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_audio_file_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_storage_engine.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';

void main() {
  test('vault persists a 256-bit key and clears its session on lock', () async {
    final store = MemoryBiometricVaultSecureStore();
    final service = BiometricVaultService(
      store: store,
      authenticator: _Authenticator(true),
    );
    await service.initialize();

    expect(await service.enable(), isTrue);
    final first = service.requireKeyBytes();
    expect(first, hasLength(32));
    expect(service.keyMaterialLoaded, isTrue);

    service.lock();
    expect(service.keyMaterialLoaded, isFalse);
    expect(service.requireKeyBytes, throwsStateError);

    expect(await service.unlock(), isTrue);
    expect(service.requireKeyBytes(), first);
    service.dispose();
  });

  test(
    'authenticated restore key replacement updates RAM and rolls back',
    () async {
      final store = MemoryBiometricVaultSecureStore();
      final authenticator = _Authenticator(true);
      final service = BiometricVaultService(
        store: store,
        authenticator: authenticator,
      );
      await service.initialize();
      await service.enable();
      final original = service.requireKeyBytes();
      final restored = Uint8List.fromList(List<int>.filled(32, 17));

      final transaction = await service.replaceMasterKeyForRestore(restored);
      expect(transaction, isNotNull);
      expect(service.requireKeyBytes(), everyElement(17));

      await service.rollbackMasterKeyReplacement(transaction!);
      expect(service.requireKeyBytes(), original);
      expect(
        () => service.rollbackMasterKeyReplacement(transaction),
        throwsStateError,
      );
      service.dispose();
    },
  );

  test(
    'vault auto-lock policy honors immediate and delayed settings',
    () async {
      var now = DateTime.utc(2026, 7, 27);
      final service = BiometricVaultService(
        store: MemoryBiometricVaultSecureStore(),
        authenticator: _Authenticator(true),
        clock: () => now,
      );
      await service.initialize();
      await service.enable();
      await service.setAutoLock(VaultAutoLock.oneMinute);

      service.onAppBackgrounded();
      expect(service.isUnlocked, isTrue);
      now = now.add(const Duration(seconds: 30));
      expect(await service.onAppResumed(), isTrue);
      expect(service.isUnlocked, isTrue);

      service.onAppBackgrounded();
      now = now.add(const Duration(minutes: 2));
      expect(await service.onAppResumed(), isTrue);
      expect(service.isUnlocked, isTrue);
      expect(_Authenticator.calls, greaterThanOrEqualTo(2));
      service.dispose();
    },
  );

  test(
    'encrypted storage authenticates roundtrips and rejects wrong keys',
    () async {
      final engine = EncryptedStorageEngine();
      final key = List<int>.generate(32, (index) => index);
      final wrongKey = List<int>.generate(32, (index) => 255 - index);
      final plaintext = utf8.encode('private transcript and graph vector');

      final envelope = await engine.encrypt(plaintext, keyBytes: key);
      expect(envelope.toString(), isNot(contains('private transcript')));
      expect(
        utf8.decode(await engine.decrypt(envelope, keyBytes: key)),
        'private transcript and graph vector',
      );
      await expectLater(
        engine.decrypt(envelope, keyBytes: wrongKey),
        throwsA(isA<EncryptedStorageException>()),
      );
    },
  );

  test('SQLite sensitive fields are opaque and authenticated', () {
    final key = List<int>.generate(32, (index) => index);
    final codec = EncryptedSqliteTextCodec(() => Uint8List.fromList(key));
    final encrypted = codec.encode('/private/audio.m4a');

    expect(encrypted, startsWith('vault:v1:'));
    expect(encrypted, isNot(contains('/private/audio.m4a')));
    expect(codec.decode(encrypted), '/private/audio.m4a');
    expect(
      () => EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 7)),
      ).decode(encrypted),
      throwsStateError,
    );
  });

  test(
    'transcription SQLite persists paths and transcripts encrypted',
    () async {
      final root = await Directory.systemTemp.createTemp('vault-sqlite-');
      addTearDown(() => root.delete(recursive: true));
      final databaseFile = File('${root.path}/queue.sqlite3');
      final codec = EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.generate(32, (index) => index)),
      );
      final database = TranscriptionJobDatabase.open(
        databasePath: databaseFile.path,
        textCodec: codec,
      );
      final now = DateTime.utc(2026, 7, 27);
      database.insertJob(
        TranscriptionJob(
          id: 'job-1',
          entryId: 'entry-1',
          audioPath: '/private/audio-sensitive.m4a',
          sourceFileName: 'audio-sensitive.m4a',
          durationSeconds: 12,
          status: TranscriptionJobStatus.completed,
          createdAt: now,
          updatedAt: now,
          attemptCount: 1,
          transcript: 'a uniquely private spoken transcript',
          completedAt: now,
        ),
      );

      expect(
        database.getJob('job-1')?.transcript,
        contains('uniquely private'),
      );
      await database.close();
      final raw = latin1.decode(await databaseFile.readAsBytes());
      expect(raw, isNot(contains('audio-sensitive')));
      expect(raw, isNot(contains('uniquely private')));
    },
  );

  test(
    'transcription ledger seals queued audio and removes plaintext',
    () async {
      final root = await Directory.systemTemp.createTemp('vault-audio-');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/capture.m4a');
      await source.writeAsBytes(utf8.encode('uniquely-private-audio-bytes'));
      final key = List<int>.generate(32, (index) => index);
      final audioStore = EncryptedAudioFileStore(
        keyProvider: () => Uint8List.fromList(key),
      );
      final ledger = await TranscriptionLedger.open(
        directory: Directory('${root.path}/queue'),
        idFactory: () => 'encrypted-job',
        encryptedAudioStore: audioStore,
      );

      final job = await ledger.enqueue(source);
      expect(await source.exists(), isFalse);
      expect(
        await File(job.audioPath).readAsString(),
        isNot(contains('uniquely-private-audio-bytes')),
      );
      final recovered = await audioStore.withDecryptedFile(
        File(job.audioPath),
        (file) => file.readAsString(),
      );
      expect(recovered, 'uniquely-private-audio-bytes');
      await ledger.close();
    },
  );

  testWidgets('privacy overlay covers content as soon as app is inactive', (
    tester,
  ) async {
    final service = BiometricVaultService(
      store: MemoryBiometricVaultSecureStore(),
      authenticator: _Authenticator(true),
    );
    await service.initialize();
    await service.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricLockOverlay(
          service: service,
          child: const Text('Sensitive memory graph'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 160));

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('biometric-lock-overlay')),
    );
    expect(opacity.opacity, 1);
    expect(find.text('Archive hidden'), findsOneWidget);
    expect(service.keyMaterialLoaded, isFalse);
    service.dispose();
  });
}

class _Authenticator implements VaultDeviceAuthenticator {
  _Authenticator(this.result);

  static int calls = 0;
  final bool result;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}
