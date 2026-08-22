import 'dart:io';

import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_facade.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

export 'capture_pipeline/capture_pipeline_models.dart';

/// Backward-compatible entry point delegating to [CapturePipelineFacade].
class CapturePipelineService {
  CapturePipelineService({
    required CaptureRepository captureRepository,
    required CaptureAttestService attest,
    required JournalStore journalStore,
    required RemoteProcessingConsentStore consentStore,
    ProofScopeProvider scopeProvider = const AppServicesProofScopeProvider(),
    ApiUsageGuard? usageGuard,
    ImageEmbeddingService? imageEmbeddingService,
    VoiceLocalAiPort? localAiPipeline,
    ReflectionEmbeddingIndexWorker? reflectionEmbeddingIndexWorker,
    CanonicalProofAdmissionService? proofAdmission,
    SpeechLocaleReader? speechLocale,
    AccountSessionGuard Function()? sessionGuardFactory,
    CapturePipelineFacade? facade,
  }) : _facade =
           facade ??
           CapturePipelineFacade.standard(
             CapturePipelineDependencies(
               captureRepository: captureRepository,
               attest: attest,
               journalStore: journalStore,
               consentStore: consentStore,
               usageGuard: usageGuard ?? ApiUsageGuard.shared,
               proofAdmission:
                   proofAdmission ??
                   CanonicalProofAdmissionService(
                     correctionPolicy: ArchiveCorrectionStore.instance,
                   ),
               scopeProvider: scopeProvider,
               imageEmbeddingService: imageEmbeddingService,
               localAiPipeline: localAiPipeline,
               reflectionEmbeddingIndexWorker: reflectionEmbeddingIndexWorker,
               speechLocale: speechLocale,
               sessionGuardFactory:
                   sessionGuardFactory ?? AccountSessionGuard.capture,
             ),
           );

  final CapturePipelineFacade _facade;

  /// Account-scoped consent for remote transcript processing.
  RemoteProcessingConsentStore get consentStore =>
      _facade.dependencies.consentStore;

  CapturePipelineDependencies get dependencies => _facade.dependencies;

  /// Broadcast stream of capture pipeline stage progression.
  Stream<PipelineState> get pipelineStates => _facade.pipelineStates;

  /// Closes [pipelineStates]. Call when the service is discarded.
  void dispose() => _facade.dispose();

  /// Every capture writes a new moment into the owner's journal under their
  /// name. Caregiver consent covers reading named streams, never writing, so a
  /// caregiver session has no path to any of these regardless of scopes.
  Future<void> _assertOwnerCapture() => CaregiverSessionGuard.assertOwnerAccess(
        CaregiverSessionGuard.captureJournalEntry,
      );

  Future<CapturePipelineOutcome> run({
    required File audioFile,
    required int durationSeconds,
  }) async {
    await _assertOwnerCapture();
    return _facade.run(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
    );
  }

  Future<CapturePipelineOutcome> attachTypedTextToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) async {
    await _assertOwnerCapture();
    return _facade.attachTypedTextToVoiceEntry(
      entry: entry,
      transcript: transcript,
    );
  }

  Future<PostSaveMomentDetailOutcome> savePostSaveMomentDetail({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) async {
    await _assertOwnerCapture();
    return _facade.savePostSaveMomentDetail(
      parentEntry: parentEntry,
      detailType: detailType,
      detailText: detailText,
    );
  }

  Future<CapturePipelineOutcome> saveTextThought({
    required String transcript,
  }) async {
    await _assertOwnerCapture();
    return _facade.saveTextThought(transcript: transcript);
  }

  Future<CapturePipelineOutcome> saveImageCaptionEntry({
    required String caption,
    required ImageEvidence imageEvidence,
  }) async {
    await _assertOwnerCapture();
    return _facade.saveImageCaptionEntry(
      caption: caption,
      imageEvidence: imageEvidence,
    );
  }

  Future<CapturePipelineOutcome> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
  }) async {
    await _assertOwnerCapture();
    return _facade.saveLiveVoiceTranscript(
      transcript: transcript,
      durationSeconds: durationSeconds,
    );
  }

  Future<CapturePipelineOutcome> saveRecoveredVaultEntry({
    required String transcript,
    required Map<String, dynamic> reflectionJson,
    required int durationSeconds,
    required bool remoteProcessingConsented,
  }) async {
    await _assertOwnerCapture();
    return _facade.saveRecoveredVaultEntry(
      transcript: transcript,
      reflectionJson: reflectionJson,
      durationSeconds: durationSeconds,
      remoteProcessingConsented: remoteProcessingConsented,
    );
  }

  Future<CapturePipelineOutcome> runWatchCapture({
    required String audioFilePath,
    int? durationSeconds,
  }) async {
    await _assertOwnerCapture();
    return _facade.runWatchCapture(
      audioFilePath: audioFilePath,
      durationSeconds: durationSeconds,
    );
  }
}
