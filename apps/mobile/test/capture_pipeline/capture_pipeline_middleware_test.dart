import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_pipeline_test_support.dart';

class BlockingUsageGuard extends ApiUsageGuard {
  BlockingUsageGuard() : super();

  @override
  ApiUsageCheckResult checkAttempt({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) {
    return ApiUsageCheckResult.blocked(reason: 'test_blocked');
  }
}

class FailingAnalyzer extends CaptureProofAnalyzer {
  FailingAnalyzer(CapturePipelineDependencies deps) : super(deps);

  @override
  Future<VerifiedProof> postAndAdmit({
    required String transcript,
    required String captureToken,
    required String idempotencyKey,
    required String entryId,
    required ProofSourceType sourceType,
  }) async {
    throw StateError('should not reach analyzer');
  }
}

void main() {
  group('CapturePipelineMiddleware', () {
    test('analyzeWithAuthRetry throws AnalyzeBlockedException when guard blocks',
        () async {
      final dir = await Directory.systemTemp.createTemp('middleware_test_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.grant();

      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: JournalStore(file: File('${dir.path}/journal.json')),
        consentStore: consentStore,
      );
      final blockingDeps = CapturePipelineDependencies(
        captureRepository: built.facade.dependencies.captureRepository,
        attest: built.facade.dependencies.attest,
        journalStore: built.facade.dependencies.journalStore,
        consentStore: consentStore,
        usageGuard: BlockingUsageGuard(),
        proofAdmission: CanonicalProofAdmissionService(),
        scopeProvider: const FixedScopeProvider(),
      );
      final middleware = CapturePipelineMiddleware(
        blockingDeps,
        FailingAnalyzer(blockingDeps),
      );

      expect(
        () => middleware.analyzeWithAuthRetry(
          transcript: 'long enough transcript for analyze path',
          scopeKey: 'text:test',
          entryId: 'entry-1',
          sourceType: ProofSourceType.userTyped,
        ),
        throwsA(isA<AnalyzeBlockedException>()),
      );

      await dir.delete(recursive: true);
    });
  });
}
