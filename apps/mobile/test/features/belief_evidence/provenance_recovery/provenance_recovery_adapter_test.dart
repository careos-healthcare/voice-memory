import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_adapter.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the test on any attempt to open a socket.
class _NoNetworkAllowed extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    fail('Provenance recovery opened an HTTP client.');
  }
}

/// In-memory [JournalStore] that records [first25Source] on each save.
class _InMemoryJournalStore extends JournalStore {
  _InMemoryJournalStore()
    : super(
        file: File(
          '${Directory.systemTemp.path}/provenance_recovery_unused.json',
        ),
      );

  final Map<String, JournalEntry> entries = {};
  final Map<String, String> first25Sources = {};

  @override
  Future<JournalEntry?> getById(String id) async => entries[id];

  @override
  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
    String captureKind = 'typed',
  }) async {
    entries[entry.id] = entry;
    first25Sources[entry.id] = first25Source;
  }
}

/// Per-path [CaptureRepository.postTranscribe] double. No network.
class _FakeCaptureRepository extends CaptureRepository {
  _FakeCaptureRepository()
    : super(api: _UnusedCaptureApi(), requestScope: NetworkRequestScope());

  final List<String> transcribedPaths = [];
  final Map<String, Future<ApiResult<String>> Function()> handlers = {};

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    transcribedPaths.add(audioFile.path);
    final handler = handlers[audioFile.path];
    if (handler == null) {
      fail('Unexpected postTranscribe for ${audioFile.path}');
    }
    return handler();
  }
}

class _UnusedCaptureApi implements CaptureApiClient {
  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postCaptureAttest');
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postAnalyzeRaw');
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postTranscribe');
  }

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postVaultRecovery');
  }
}

class _DummyAttest extends CaptureAttestService {
  _DummyAttest()
    : super(
        captureRepository: CaptureRepository(
          api: _UnusedCaptureApi(),
          requestScope: NetworkRequestScope(),
        ),
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'dummy-token';
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}

class _AlwaysAllowGuard extends ApiUsageGuard {
  @override
  ApiUsageCheckResult checkAttempt({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) => const ApiUsageCheckResult.allowed();
}

/// Consent is not under test — the adapter needs a gate that says yes.
class _AlwaysPermitGate extends RemoteProcessingConsentGate {
  _AlwaysPermitGate()
    : super(
        RemoteProcessingConsentStore(
          MobilePrefsStore(
            file: File(
              '${Directory.systemTemp.path}/provenance_recovery_unused_prefs.json',
            ),
          ),
        ),
      );

  @override
  Future<bool> isPurposePermittedNow(RemoteProcessingPurpose purpose) async =>
      true;
}

const _reflection = Reflection(
  mood: 'anxious',
  emotionalIntensity: 7,
  recurringThemes: ['work'],
  exactLanguagePattern: 'I always',
  concreteObservation: 'said hello world',
  repeatedSignal: 'hello',
);

void main() {
  late HttpOverrides? previousOverrides;
  late Directory tempDir;
  late _InMemoryJournalStore journal;
  late _FakeCaptureRepository capture;
  late ProvenanceRecoveryAdapter adapter;
  late File existingAudio;
  late File existingAudioB;

  setUp(() async {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _NoNetworkAllowed();

    tempDir = await Directory.systemTemp.createTemp('provenance_recovery_');
    existingAudio = File('${tempDir.path}/voice_a.m4a')..writeAsBytesSync([]);
    existingAudioB = File('${tempDir.path}/voice_b.m4a')..writeAsBytesSync([]);

    journal = _InMemoryJournalStore();
    capture = _FakeCaptureRepository();
    adapter = ProvenanceRecoveryAdapter(
      journalStore: journal,
      captureRepository: capture,
      attest: _DummyAttest(),
      usageGuard: _AlwaysAllowGuard(),
      consentGate: _AlwaysPermitGate(),
    );
  });

  tearDown(() async {
    HttpOverrides.global = previousOverrides;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  JournalEntry entry({
    required String id,
    required String transcript,
    TranscriptProvenance provenance = TranscriptProvenance.unknownLegacy,
    TranscriptStatus status = TranscriptStatus.finalTranscript,
    String? audioPath,
    Reflection reflection = _reflection,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 9, 11),
      transcript: transcript,
      durationSeconds: 12,
      reflection: reflection,
      localAudioPath: audioPath ?? existingAudio.path,
      transcriptStatus: status,
      transcriptProvenance: provenance,
    );
  }

  void expectUntouched(JournalEntry original) {
    final stored = journal.entries[original.id];
    expect(stored, isNotNull);
    expect(stored!.transcript, original.transcript);
    expect(stored.transcriptProvenance, original.transcriptProvenance);
    expect(stored.reflection, original.reflection);
    expect(stored.transcriptStatus, original.transcriptStatus);
    expect(stored, original);
    expect(journal.first25Sources.containsKey(original.id), isFalse);
  }

  test(
    'normalized whitespace and case match restamps provenance without rewriting text',
    () async {
      // Stored "Hello  world" vs transcribed "hello world" must MATCH.
      final original = entry(id: 'match', transcript: 'Hello  world');
      journal.entries[original.id] = original;
      capture.handlers[existingAudio.path] = () async =>
          const ApiSuccess('hello world');

      final outcome = await adapter.recover([original.id]);

      expect(outcome.requestedCount, 1);
      expect(outcome.recoveredCount, 1);
      expect(capture.transcribedPaths, [existingAudio.path]);

      final stored = journal.entries[original.id]!;
      expect(stored.transcript, 'Hello  world');
      expect(stored.reflection, original.reflection);
      expect(stored.transcriptProvenance, TranscriptProvenance.speechToText);
      expect(stored.transcriptStatus, original.transcriptStatus);
      expect(journal.first25Sources[original.id], 'provenance_recovery');
    },
  );

  test('mismatched transcript leaves the entry untouched', () async {
    // Stored "Hello world" vs transcribed "completely different" must NOT match.
    final original = entry(id: 'mismatch', transcript: 'Hello world');
    journal.entries[original.id] = original;
    capture.handlers[existingAudio.path] = () async =>
        const ApiSuccess('completely different');

    final outcome = await adapter.recover([original.id]);

    expect(outcome.requestedCount, 1);
    expect(outcome.recoveredCount, 0);
    expect(capture.transcribedPaths, [existingAudio.path]);
    expectUntouched(original);
  });

  test('userEdited is never sent for transcription', () async {
    final original = entry(
      id: 'edited',
      transcript: 'Hello  world',
      provenance: TranscriptProvenance.userEdited,
    );
    journal.entries[original.id] = original;
    capture.handlers[existingAudio.path] = () async =>
        const ApiSuccess('hello world');

    final outcome = await adapter.recover([original.id]);

    expect(outcome.requestedCount, 1);
    expect(outcome.recoveredCount, 0);
    expect(capture.transcribedPaths, isEmpty);
    expectUntouched(original);
  });

  test('already speechToText is never sent for transcription', () async {
    final original = entry(
      id: 'already',
      transcript: 'Hello  world',
      provenance: TranscriptProvenance.speechToText,
    );
    journal.entries[original.id] = original;
    capture.handlers[existingAudio.path] = () async =>
        const ApiSuccess('hello world');

    final outcome = await adapter.recover([original.id]);

    expect(outcome.requestedCount, 1);
    expect(outcome.recoveredCount, 0);
    expect(capture.transcribedPaths, isEmpty);
    expectUntouched(original);
  });

  test('missing audio file is skipped without crashing', () async {
    final missingPath = '${tempDir.path}/does-not-exist.m4a';
    expect(File(missingPath).existsSync(), isFalse);

    final original = entry(
      id: 'missing',
      transcript: 'Hello  world',
      audioPath: missingPath,
    );
    journal.entries[original.id] = original;

    final outcome = await adapter.recover([original.id]);

    expect(outcome.requestedCount, 1);
    expect(outcome.recoveredCount, 0);
    expect(capture.transcribedPaths, isEmpty);
    expectUntouched(original);
  });

  test('a failed transcription does not stop the rest of the batch', () async {
    final failing = entry(
      id: 'throws',
      transcript: 'Hello  world',
      audioPath: existingAudio.path,
    );
    final matching = entry(
      id: 'recovers',
      transcript: 'Hello  world',
      audioPath: existingAudioB.path,
    );
    journal.entries[failing.id] = failing;
    journal.entries[matching.id] = matching;

    capture.handlers[existingAudio.path] = () async {
      throw StateError('transcribe failed');
    };
    capture.handlers[existingAudioB.path] = () async =>
        const ApiSuccess('hello world');

    final outcome = await adapter.recover([failing.id, matching.id]);

    expect(outcome.requestedCount, 2);
    expect(outcome.recoveredCount, 1);
    expect(capture.transcribedPaths, [
      existingAudio.path,
      existingAudioB.path,
    ]);
    expectUntouched(failing);

    final recovered = journal.entries[matching.id]!;
    expect(recovered.transcript, 'Hello  world');
    expect(recovered.reflection, matching.reflection);
    expect(recovered.transcriptProvenance, TranscriptProvenance.speechToText);
    expect(journal.first25Sources[matching.id], 'provenance_recovery');
  });

  test('a mixed batch recovers only genuine matches', () async {
    final matching = entry(
      id: 'match',
      transcript: 'Hello  world',
      audioPath: existingAudio.path,
    );
    final mismatching = entry(
      id: 'mismatch',
      transcript: 'Hello world',
      audioPath: existingAudioB.path,
    );
    final edited = entry(
      id: 'edited',
      transcript: 'Hello  world',
      provenance: TranscriptProvenance.userEdited,
      audioPath: existingAudio.path,
    );
    journal.entries[matching.id] = matching;
    journal.entries[mismatching.id] = mismatching;
    journal.entries[edited.id] = edited;

    capture.handlers[existingAudio.path] = () async =>
        const ApiSuccess('hello world');
    capture.handlers[existingAudioB.path] = () async =>
        const ApiSuccess('completely different');

    final ids = [matching.id, mismatching.id, edited.id];
    final outcome = await adapter.recover(ids);

    expect(outcome.requestedCount, ids.length);
    expect(outcome.recoveredCount, 1);
    expect(capture.transcribedPaths, [
      existingAudio.path,
      existingAudioB.path,
    ]);

    final recovered = journal.entries[matching.id]!;
    expect(recovered.transcript, 'Hello  world');
    expect(recovered.reflection, matching.reflection);
    expect(recovered.transcriptProvenance, TranscriptProvenance.speechToText);
    expect(journal.first25Sources[matching.id], 'provenance_recovery');

    expectUntouched(mismatching);
    expectUntouched(edited);
  });
}
