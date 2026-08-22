import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Re-runs server transcription for entries marked [TranscriptStatus.provisional].
class ProvisionalTranscriptReconciler {
  ProvisionalTranscriptReconciler({
    required CaptureRepository captureRepository,
    required CaptureAttestService attest,
    required JournalStore journalStore,
    required RemoteProcessingConsentStore consentStore,
    ApiUsageGuard? usageGuard,
  }) : _captureRepository = captureRepository,
       _attest = attest,
       _journalStore = journalStore,
       _consentGate = RemoteProcessingConsentGate(consentStore),
       _usageGuard = usageGuard ?? ApiUsageGuard.shared;

  final CaptureRepository _captureRepository;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final RemoteProcessingConsentGate _consentGate;
  final ApiUsageGuard _usageGuard;

  Future<int> reconcileAll() async {
    final entries = await _journalStore.loadAll();
    var updated = 0;
    for (final entry in entries) {
      if (await reconcileEntry(entry)) {
        updated++;
      }
    }
    return updated;
  }

  Future<bool> reconcileEntry(JournalEntry entry) async {
    if (entry.transcriptStatus != TranscriptStatus.provisional) return false;
    if (!await _remoteTranscriptionAllowed()) return false;
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return false;
    final audioFile = await _resolveAudioFile(audioPath);
    if (audioFile == null) return false;

    final scopeKey = 'reconcile:${entry.id}';
    final guard = _usageGuard.checkAttempt(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );
    if (!guard.allowed) return false;

    final idempotencyKey = _usageGuard.idempotencyKey(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );

    var token = await _attest.ensureCaptureToken();
    ApiResult<String> result = await _captureRepository.postTranscribe(
      audioFile: audioFile,
      durationSeconds: entry.durationSeconds,
      captureToken: token,
      idempotencyKey: idempotencyKey,
    );

    if (result case ApiFailureResult(
      :final failure,
    ) when failure is ApiFailureAuthRequired) {
      token = await _attest.ensureCaptureToken(forceRefresh: true);
      result = await _captureRepository.postTranscribe(
        audioFile: audioFile,
        durationSeconds: entry.durationSeconds,
        captureToken: token,
        idempotencyKey: idempotencyKey,
      );
    }

    if (result is ApiSuccess<String>) {
      final trimmed = result.value.trim();
      final quality = TranscriptQuality.evaluate(trimmed);
      if (!quality.isValid) {
        TranscriptionLog.failed(reason: 'reconcile_low_quality');
        return false;
      }
      _usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: true,
      );
      // Server speech-to-text over the user's own recording: genuinely their
      // words, so this is one of the few paths that may restore quotability to
      // an entry that was previously unquotable.
      final updated = entry.copyWith(
        transcript: trimmed,
        transcriptStatus: TranscriptStatus.finalTranscript,
        transcriptProvenance: TranscriptProvenance.speechToText,
      );
      await _journalStore.save(updated, first25Source: 'provisional_reconcile');
      TranscriptionLog.success(transcriptLength: trimmed.length);
      return true;
    }

    _usageGuard.recordAttempt(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
      success: false,
    );
    return false;
  }

  /// Both gates that stand between stored audio and a third-party transcriber.
  ///
  /// `/api/transcribe` forwards audio to OpenAI Whisper, so re-transcribing an
  /// entry uploads a recording the user has already saved. The on-device-only
  /// switch defaults to on, which means the default outcome of this method —
  /// and therefore of any re-transcription built on it — is that nothing
  /// leaves the device.
  ///
  /// [RemoteProcessingConsentGate] owns that composition, so this cannot drift
  /// from `CaptureProofAnalyzer.isPurposeGranted` or from the toggle's copy.
  Future<bool> _remoteTranscriptionAllowed() => _consentGate
      .isPurposePermittedNow(RemoteProcessingPurpose.remoteTranscription);

  Future<File?> _resolveAudioFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }
}