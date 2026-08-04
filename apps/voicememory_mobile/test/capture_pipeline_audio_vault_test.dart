import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/on_device_transcription_engine.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcription_connectivity.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory workingDirectory;
  late AudioVaultService vault;
  late _CaptureApi api;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture_audio_vault_test_');
    vaultDirectory = Directory('${root.path}/vault');
    workingDirectory = Directory('${root.path}/working');
    vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => vaultDirectory,
      temporaryDirectory: () async => workingDirectory,
    );
    api = _CaptureApi();
  });

  tearDown(() async {
    ApiUsageGuard.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> recording([String name = 'capture.m4a']) async {
    final file = File('${root.path}/$name');
    final bytes = List<int>.generate(4096, (index) => index % 251)
      ..setRange(4, 8, 'ftyp'.codeUnits);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  CapturePipelineService pipeline(
    JournalStore journal,
    AudioVaultService vault,
  ) {
    return CapturePipelineService(
      api: api,
      attest: _FakeAttest(api),
      journalStore: journal,
      audioVault: vault,
      onDeviceTranscription: const _UnavailableLocalTranscription(),
      transcriptionConnectivity: const FixedTranscriptionConnectivity(true),
      usageGuard: ApiUsageGuard(
        cooldownBetweenRetries: Duration.zero,
        baseBackoff: Duration.zero,
      ),
    );
  }

  test(
    'successful capture persists vault ref before deleting plaintext',
    () async {
      final journal = JournalStore(
        file: File('${root.path}/journal.json'),
        ownerArchiveId: 'local',
      );
      final source = await recording();
      final original = await source.readAsBytes();

      final result = await pipeline(
        journal,
        vault,
      ).run(audioFile: source, durationSeconds: 12, entryId: 'entry-success');

      expect(result.localSaved, isTrue);
      expect(await source.exists(), isFalse);
      expect(result.entry.localAudioPath, isNull);
      expect(
        result.entry.localAudioVaultRef,
        startsWith(AudioVaultService.referencePrefix),
      );
      expect(
        await vault.readPlaintextBytes(result.entry.localAudioVaultRef!),
        original,
      );
      final rawJournal = await journal.file.readAsString();
      expect(rawJournal, contains('localAudioVaultRef'));
      expect(rawJournal, isNot(contains(source.path)));
    },
  );

  test(
    'existing encrypted capture is persisted as an opaque reference',
    () async {
      final journal = JournalStore(
        file: File('${root.path}/journal.json'),
        ownerArchiveId: 'local',
      );
      final source = await recording();
      final sealed = await vault.sealCapture('entry-existing-vault', source);
      await vault.secureDeletePlaintext(source);

      final result = await pipeline(journal, vault).run(
        audioFile: sealed.file,
        durationSeconds: 12,
        entryId: 'entry-existing-vault',
      );

      expect(result.entry.localAudioVaultRef, sealed.reference);
      expect(result.entry.localAudioPath, isNull);
      expect(await vault.exists(sealed.reference), isTrue);
      expect(await workingDirectory.list().isEmpty, isTrue);
    },
  );

  test('retry reuses the durable vault object without resealing', () async {
    final journal = JournalStore(
      file: File('${root.path}/journal.json'),
      ownerArchiveId: 'local',
    );
    final firstSource = await recording('first-attempt.m4a');
    final original = await firstSource.readAsBytes();
    final first = await pipeline(
      journal,
      vault,
    ).run(audioFile: firstSource, durationSeconds: 12, entryId: 'entry-retry');
    final retryWorking = await recording('retry-working.m4a');
    await retryWorking.writeAsBytes(original, flush: true);

    final retried = await pipeline(
      journal,
      vault,
    ).run(audioFile: retryWorking, durationSeconds: 12, entryId: 'entry-retry');

    expect(retried.entry.localAudioVaultRef, first.entry.localAudioVaultRef);
    expect(await retryWorking.exists(), isFalse);
    expect(
      await vaultDirectory
          .list()
          .where((entity) => entity.path.endsWith('.enc'))
          .length,
      1,
    );
  });

  test('seal failure preserves source and stores no vault reference', () async {
    final journal = JournalStore(
      file: File('${root.path}/journal.json'),
      ownerArchiveId: 'local',
    );
    final source = await recording();
    final failingVault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async =>
          throw const FileSystemException('vault unavailable'),
      temporaryDirectory: () async => workingDirectory,
    );

    await expectLater(
      pipeline(journal, failingVault).run(
        audioFile: source,
        durationSeconds: 12,
        entryId: 'entry-seal-failure',
      ),
      throwsA(anything),
    );

    expect(await source.exists(), isTrue);
    expect(await journal.loadAll(), isEmpty);
  });

  test(
    'journal write failure removes plaintext and preserves ciphertext',
    () async {
      final blocker = File('${root.path}/not-a-directory');
      await blocker.writeAsString('block');
      final journal = JournalStore(
        file: File('${blocker.path}/journal.json'),
        ownerArchiveId: 'local',
      );
      final source = await recording();

      await expectLater(
        pipeline(journal, vault).run(
          audioFile: source,
          durationSeconds: 12,
          entryId: 'entry-journal-failure',
        ),
        throwsA(anything),
      );

      expect(await source.exists(), isFalse);
      expect(await journal.loadAll(), isEmpty);
      if (await vaultDirectory.exists()) {
        expect(
          await vaultDirectory
              .list()
              .where((entity) => entity.path.endsWith('.enc'))
              .isEmpty,
          isFalse,
        );
      }
    },
  );
}

final class _CaptureApi extends VoiceCaptureApiClient {
  _CaptureApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    expect(await audioFile.exists(), isTrue);
    return 'I noticed that a quiet pause helped me choose carefully.';
  }

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 2,
      recurringThemes: ['pausing'],
      exactLanguagePattern: 'a quiet pause',
      concreteObservation: 'A quiet pause may have supported a careful choice.',
      repeatedSignal: '',
    );
  }
}

final class _FakeAttest extends CaptureAttestService {
  _FakeAttest(VoiceCaptureApiClient api)
    : super(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device-id';
}

final class _UnavailableLocalTranscription
    implements OnDeviceTranscriptionEngine {
  const _UnavailableLocalTranscription();

  @override
  Future<bool> isReady() async => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async =>
      throw const OnDeviceTranscriptionUnavailable('not_ready');
}
