import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Re-runs remote analyze + proof admission for locally saved entries that
/// never received a [VerifiedProof] (consent/network was unavailable at save).
class DeferredProofAdmissionReconciler {
  DeferredProofAdmissionReconciler({
    required CapturePipelineMiddleware middleware,
    required JournalStore journalStore,
    required RemoteProcessingConsentStore consentStore,
  }) : _middleware = middleware,
       _journalStore = journalStore,
       _consentGate = RemoteProcessingConsentGate(consentStore);

  final CapturePipelineMiddleware _middleware;
  final JournalStore _journalStore;
  final RemoteProcessingConsentGate _consentGate;

  /// `CapturePipelineMiddleware.analyzeWithAuthRetry` only enforces the API
  /// usage guard, so nothing downstream re-checks consent: this predicate is
  /// the last thing between a stored transcript and `/api/analyze`.
  Future<bool> _remoteReflectionAllowed() => _consentGate
      .isPurposePermittedNow(RemoteProcessingPurpose.remoteReflection);

  static bool needsDeferredProofAdmission(JournalEntry entry) {
    if (entry.isDeleted) return false;
    if (entry.verifiedProof != null) return false;
    if (entry.transcriptStatus.isPending ||
        entry.transcriptStatus.isProvisional) {
      return false;
    }
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty || transcript.startsWith('[draft]')) return false;
    return !_hasMeaningfulReflection(entry.reflection);
  }

  static bool _hasMeaningfulReflection(Reflection reflection) {
    return reflection.exactLanguagePattern.trim().isNotEmpty ||
        (reflection.concreteObservation.trim().isNotEmpty &&
            reflection.concreteObservation.trim() !=
                CaptureSaveMessages.savedPrivatelyOnDevice);
  }

  Future<int> reconcileAll() async {
    if (!await _remoteReflectionAllowed()) return 0;

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
    if (!needsDeferredProofAdmission(entry)) return false;
    if (!await _remoteReflectionAllowed()) return false;

    final scopeKey = 'proof_admission:${entry.id}';
    try {
      final verifiedProof = await _middleware.analyzeWithAuthRetry(
        transcript: entry.transcript.trim(),
        scopeKey: scopeKey,
        entryId: entry.id,
        sourceType: _sourceTypeFor(entry),
        attestFirst: true,
      );
      final updated = entry.copyWith(
        reflection: verifiedProof.reflection,
        verifiedProof: verifiedProof,
      );
      await _journalStore.saveEdit(
        updated,
        first25Source: 'deferred_proof_admission',
      );
      _middleware.clearCaptureToken();
      return true;
    } on AnalyzeBlockedException {
      return false;
    } catch (_, stackTrace) {
      return false;
    }
  }

  ProofSourceType _sourceTypeFor(JournalEntry entry) {
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath != null && audioPath.isNotEmpty) {
      return ProofSourceType.userVoiceTranscript;
    }
    return ProofSourceType.userTyped;
  }
}