import 'dart:async';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_analytics.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/related_source_resolver.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

/// Posts analyze requests and admits verified proofs for capture handlers.
class CaptureProofAnalyzer {
  CaptureProofAnalyzer(this._deps);

  final CapturePipelineDependencies _deps;

  Future<bool> remoteProcessingConsented() =>
      isPurposeGranted(RemoteProcessingPurpose.remoteReflection);

  Future<bool> isPurposeGranted(RemoteProcessingPurpose purpose) async {
    try {
      await OnDeviceProcessingStore.ensureLoaded();
      if (OnDeviceProcessingStore.enabled) return false;
      return await _deps.consentStore.isPurposeGrantedNow(purpose);
    } catch (_, stackTrace) {
      return false;
    }
  }

  Future<VerifiedProof> postAndAdmit({
    required String transcript,
    required String captureToken,
    required String idempotencyKey,
    required String entryId,
    required ProofSourceType sourceType,
  }) async {
    final revision = UserContentSafety.privacyHash(transcript);
    final analyzeResult = await _deps.captureRepository.postAnalyzeRaw(
      transcript: transcript,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
    final raw = analyzeResult.when(
      success: (value) => value,
      onFailure: (failure) => throw failure.toApiException(),
    );
    final consentedNow = await remoteProcessingConsented();
    final startedAt = DateTime.now();
    final subject = ProofSourceEntry(
      entryId: entryId,
      archiveScope: _deps.archiveScope,
      ownerScope: _deps.ownerScope,
      transcript: transcript,
      transcriptRevision: revision,
      createdAt: raw.receivedAt,
      sourceType: sourceType,
      remoteProcessingConsented: consentedNow,
    );
    final result = _deps.proofAdmission.admit(
      raw: raw,
      sourceEntries: [subject, ...await _relatedSources(subject)],
      activeArchiveScope: _deps.archiveScope,
      activeOwnerScope: _deps.ownerScope,
      primarySourceEntryId: entryId,
    );
    final admitted = result is ProofAdmitted ? result.proof : null;
    unawaited(
      ProductAnalytics.track(
        ProofAdmissionAnalytics.eventName,
        parameters: ProofAdmissionAnalytics.payload(
          result: result,
          distinctSourceCount:
              admitted?.qualityReceipt.frequency.distinctMoments ?? 0,
          contradictionCount:
              admitted?.qualityReceipt.contradictions.length ?? 0,
          duration: DateTime.now().difference(startedAt),
        ),
      ),
    );
    if (admitted != null) return admitted;
    final rejected = result as ProofNotAdmitted;
    throw FormatException(
      'Analysis was not admitted (${rejected.outcome.name}:${rejected.reason}).',
    );
  }

  Future<List<ProofSourceEntry>> _relatedSources(
    ProofSourceEntry subject,
  ) async {
    try {
      final archive = await _deps.journalStore.loadAll();
      final resolver = RelatedSourceResolver(
        archiveScope: _deps.archiveScope,
        ownerScope: _deps.ownerScope,
      )..sync(archive);
      resolver.index.upsertEntry(subject);
      return resolver.index
          .relatedSources(subject.entryId)
          .map((id) => archive.where((entry) => entry.id == id).firstOrNull)
          .whereType<JournalEntry>()
          .map(resolver.sourceFor)
          .toList();
    } on Object catch (error, stackTrace) {
      RecordPipelineLog.backgroundProcessingFailed(
        operation: 'related_sources',
        error: error,
      );
      return const [];
    }
  }
}