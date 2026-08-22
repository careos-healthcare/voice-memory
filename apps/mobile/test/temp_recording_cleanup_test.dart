import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

final _verifiedAt = DateTime.utc(2026, 6);

VerifiedProof _fullVerifiedProof() {
  const statement = 'You check the numbers before deciding.';
  final evidence = [
    VerifiedEvidenceSnapshot(
      sourceEntryId: 'entry-full-1',
      archiveScope: 'archive-1',
      ownerScope: 'owner-1',
      transcriptRevision: 'rev-1',
      transcriptFingerprint: 'fingerprint-1',
      sourceDate: _verifiedAt,
      sourceType: ProofSourceType.userTyped,
      quote: 'checked the numbers first',
      startUtf16: 0,
      endUtf16: 25,
      role: ProofEvidenceRole.support,
      verifiedAt: _verifiedAt,
    ),
  ];
  return VerifiedProof(
    proofId: 'proof-full-1',
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 3,
      recurringThemes: [],
      exactLanguagePattern: 'checked the numbers first',
      concreteObservation: statement,
      repeatedSignal: '',
    ),
    claims: [
      VerifiedProofClaim(
        claimId: 'main',
        kind: ProofClaimKind.mainObservation,
        text: statement,
        evidence: evidence,
      ),
    ],
    confidenceBand: ProofConfidenceBand.medium,
    qualityReceipt: ProofQualityReceipt(
      proofType: ProofType.currentObservation,
      confidenceBand: ProofConfidenceBand.medium,
      frequency: ProofFrequency(
        distinctMoments: 1,
        windowStart: _verifiedAt,
        windowEnd: _verifiedAt,
      ),
      trend: ProofTrend.insufficientEvidence,
      strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
      supportingEvidence: evidence,
      counterexamples: const [],
      contradictions: const [],
      missingEvidence: const [],
      firstOccurrence: _verifiedAt,
      lastOccurrence: _verifiedAt,
      generatedAt: _verifiedAt,
    ),
    verifiedAt: _verifiedAt,
    sourceRevisionFingerprint: 'source-revision',
    proofFingerprint: 'proof-fingerprint-full-1',
    semanticFramingFingerprint: ProofFingerprints.semanticFraming(
      statement: statement,
      proofType: ProofType.currentObservation.name,
    ),
    wordingFingerprint: ProofFingerprints.wording(statement),
  );
}

Future<void> _touchModified(File file, DateTime modified) async {
  await file.writeAsString('audio');
  await file.setLastModified(modified);
}

void main() {
  late Directory tempDir;
  late JournalStore journal;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_temp_rec_cleanup_');
    journal = await JournalStore.open(
      '${tempDir.path}/journal.json',
      encryptAtRest: false,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TempRecordingCleanup.purgeStaleOnStartup', () {
    test('deletes stale unreferenced vm_rec temp files', () async {
      final stale = File('${tempDir.path}/vm_rec_stale.m4a');
      await _touchModified(
        stale,
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      await TempRecordingCleanup.purgeStaleOnStartup(
        journalStore: journal,
        tempDir: tempDir,
      );

      expect(stale.existsSync(), isFalse);
    });

    test('preserves vm_rec audio referenced by offline draft entries', () async {
      final draftAudio = File('${tempDir.path}/vm_rec_draft.m4a');
      await draftAudio.writeAsString('draft audio');
      await journal.save(
        JournalEntry(
          id: 'draft-1',
          createdAt: DateTime.utc(2026, 6, 15),
          transcript:
              '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
          durationSeconds: 12,
          reflection: _reflection(),
          syncStatus: SyncStatus.pendingUpload,
          localAudioPath: draftAudio.path,
        ),
      );

      final orphan = File('${tempDir.path}/vm_rec_orphan.m4a');
      await _touchModified(
        orphan,
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      await TempRecordingCleanup.purgeStaleOnStartup(
        journalStore: journal,
        tempDir: tempDir,
      );

      expect(draftAudio.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
    });
  });

  group('TempRecordingCleanup.releaseTempAudioIfSafe', () {
    test('removes temp audio after successful transcription save', () async {
      final audio = File('${tempDir.path}/vm_rec_success.m4a');
      await audio.writeAsString('spoken audio');
      final entry = JournalEntry(
        id: 'ok-1',
        createdAt: DateTime.utc(2026, 6, 15),
        transcript: 'I felt pressure before saying yes again today.',
        durationSeconds: 20,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audio.path,
      );
      await journal.save(entry);

      final released = await TempRecordingCleanup.releaseTempAudioIfSafe(
        entry,
        journal,
      );

      expect(audio.existsSync(), isFalse);
      expect(released.localAudioPath, isNull);
      final stored = await journal.getById('ok-1');
      expect(stored?.localAudioPath, isNull);
    });

    test(
      'audio cleanup is lossless: changes only localAudioPath, preserving '
      'biomarkers, parentHookId, wasGrounded, verifiedProof, ownerKey and '
      'sync metadata (P1 regression for the JournalEntry.copyWith rewrite)',
      () async {
        final audio = File('${tempDir.path}/vm_rec_lossless.m4a');
        await audio.writeAsString('spoken audio');
        final entry = JournalEntry(
          id: 'lossless-1',
          createdAt: DateTime.utc(2026, 6, 15),
          transcript: 'I felt pressure before saying yes again today.',
          durationSeconds: 20,
          reflection: _reflection(),
          syncStatus: SyncStatus.pendingUpload,
          localAudioPath: audio.path,
          treatAsNew: true,
          connectionApproved: true,
          keepExactDetails: true,
          keepSeparate: true,
          archiveThreadId: 'thread-9',
          archivePackId: 'pack-9',
          isPinned: true,
          pinnedAt: DateTime.utc(2026, 6, 16),
          isArchived: true,
          archivedAt: DateTime.utc(2026, 6, 17),
          entryAboutness: 'about_someone_else',
          memorySurfacing: 'reduced',
          preserveOriginal: true,
          captureContextTag: 'context-tag-9',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.5,
            cohesionDrift: 0.25,
            emotionalVolatility: 0.75,
          ),
          parentHookId: 'hook-9',
          wasGrounded: true,
          verifiedProof: _fullVerifiedProof(),
          ownerKey: 'owner-key-9',
        );

        // Give the entry real, non-default sync metadata (as if it had
        // already been edited a few times) so the test can prove the
        // audio-cleanup operation does not reset it.
        final withSyncHistory = entry.copyWith(
          updatedAt: DateTime.utc(2026, 6, 18),
          revision: 4,
          changeId: 'stable-change-id-9',
        );

        final beforeJson = withSyncHistory.toJson();
        await journal.save(withSyncHistory);

        final cleared = await TempRecordingCleanup.releaseTempAudioIfSafe(
          withSyncHistory,
          journal,
        );
        final afterJson = cleared.toJson();

        // Only `localAudioPath` may differ.
        expect(afterJson.containsKey('localAudioPath'), isFalse);
        final beforeWithoutAudio = Map<String, dynamic>.from(beforeJson)
          ..remove('localAudioPath');
        expect(afterJson, equals(beforeWithoutAudio));

        // Explicitly re-assert every field the P1 spec calls out by name,
        // so a future regression here fails loudly and specifically.
        expect(cleared.localAudioPath, isNull);
        expect(cleared.biomarkers?.toJson(), entry.biomarkers?.toJson());
        expect(cleared.parentHookId, entry.parentHookId);
        expect(cleared.wasGrounded, entry.wasGrounded);
        expect(cleared.verifiedProof?.toJson(), entry.verifiedProof?.toJson());
        expect(cleared.ownerKey, entry.ownerKey);
        expect(cleared.archiveThreadId, entry.archiveThreadId);
        expect(cleared.archivePackId, entry.archivePackId);
        expect(cleared.isPinned, entry.isPinned);
        expect(cleared.pinnedAt, entry.pinnedAt);
        expect(cleared.isArchived, entry.isArchived);
        expect(cleared.archivedAt, entry.archivedAt);
        expect(cleared.updatedAt, withSyncHistory.updatedAt);
        expect(cleared.revision, withSyncHistory.revision);
        expect(cleared.changeId, withSyncHistory.changeId);
        expect(cleared.deletedAt, withSyncHistory.deletedAt);
      },
    );

    test('does not delete temp audio for degraded offline draft retry', () async {
      final audio = File('${tempDir.path}/vm_rec_offline.m4a');
      await audio.writeAsString('offline audio');
      final entry = JournalEntry(
        id: 'draft-2',
        createdAt: DateTime.utc(2026, 6, 15),
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
        durationSeconds: 18,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audio.path,
      );
      await journal.save(entry);

      final released = await TempRecordingCleanup.releaseTempAudioIfSafe(
        entry,
        journal,
      );

      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isTrue);
      expect(audio.existsSync(), isTrue);
      expect(released.localAudioPath, audio.path);
    });
  });

  group('capture pipeline integration', () {
    test('offline draft save keeps vm_rec audio for retry', () async {
      final dir = Directory.systemTemp.createTempSync('vm_pipeline_draft_');
      await AppServices.resetForTest(
        journalPath: '${dir.path}/journal.json',
        networkOverrides: [
          captureApiClientProvider.overrideWithValue(_FailingTranscribeApi()),
        ],
      );
      final audioDir = Directory.systemTemp.createTempSync(
        'vm_pipeline_audio_',
      );
      final audio = File('${audioDir.path}/vm_rec_capture.m4a')
        ..writeAsBytesSync(List.filled(1200, 1));

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(result.syncSucceeded, isFalse);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(result.entry), isTrue);
      expect(result.entry.localAudioPath, audio.path);
      expect(audio.existsSync(), isTrue);

      dir.deleteSync(recursive: true);
      audioDir.deleteSync(recursive: true);
    });
  });
}

class _FailingTranscribeApi implements CaptureApiClient {
  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'test-token', expiresInSeconds: 3600),
    );
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiFailureResult(
      ApiFailureMapper.fromException(
        ApiException('Service unavailable', statusCode: 503),
      ),
    );
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