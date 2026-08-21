import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_service.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Shared, constructor-injected dependencies for capture pipeline handlers.
class CapturePipelineDependencies {
  const CapturePipelineDependencies({
    required this.captureRepository,
    required this.attest,
    required this.journalStore,
    required this.consentStore,
    required this.usageGuard,
    required this.proofAdmission,
    required this.scopeProvider,
    this.imageEmbeddingService,
    this.localAiPipeline,
    this.reflectionEmbeddingIndexWorker,
    this.sessionGuardFactory = AccountSessionGuard.capture,
  });

  final CaptureRepository captureRepository;
  final CaptureAttestService attest;
  final JournalStore journalStore;
  final RemoteProcessingConsentStore consentStore;
  final ApiUsageGuard usageGuard;
  final CanonicalProofAdmissionService proofAdmission;
  final ProofScopeProvider scopeProvider;
  final ImageEmbeddingService? imageEmbeddingService;
  final VoiceLocalAiPort? localAiPipeline;
  final ReflectionEmbeddingIndexWorker? reflectionEmbeddingIndexWorker;
  final AccountSessionGuard Function() sessionGuardFactory;

  String get archiveScope => scopeProvider.activeArchiveScope;
  String get ownerScope => scopeProvider.activeOwnerScope;

  CapturePipelineDependencies copyWith({
    VoiceLocalAiPort? localAiPipeline,
    ReflectionEmbeddingIndexWorker? reflectionEmbeddingIndexWorker,
  }) {
    return CapturePipelineDependencies(
      captureRepository: captureRepository,
      attest: attest,
      journalStore: journalStore,
      consentStore: consentStore,
      usageGuard: usageGuard,
      proofAdmission: proofAdmission,
      scopeProvider: scopeProvider,
      imageEmbeddingService: imageEmbeddingService,
      localAiPipeline: localAiPipeline ?? this.localAiPipeline,
      reflectionEmbeddingIndexWorker:
          reflectionEmbeddingIndexWorker ?? this.reflectionEmbeddingIndexWorker,
      sessionGuardFactory: sessionGuardFactory,
    );
  }
}
