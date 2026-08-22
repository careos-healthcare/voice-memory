import 'dart:io';

import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../capture_pipeline/capture_pipeline_test_support.dart';

void main() {
  test('on-device toggle blocks remote processing purposes', () async {
    final dir = await Directory.systemTemp.createTemp('on_device_test_');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.setEnabled(true);

    final consentStore = RemoteProcessingConsentStore(prefs);
    await consentStore.grant();

    final built = await buildCapturePipelineFacade(
      prefs: prefs,
      journal: JournalStore(file: File('${dir.path}/journal.json')),
      consentStore: consentStore,
    );
    final analyzer = CaptureProofAnalyzer(
      CapturePipelineDependencies(
        captureRepository: built.facade.dependencies.captureRepository,
        attest: built.facade.dependencies.attest,
        journalStore: built.facade.dependencies.journalStore,
        consentStore: consentStore,
        usageGuard: built.facade.dependencies.usageGuard,
        proofAdmission: CanonicalProofAdmissionService(),
        scopeProvider: const FixedScopeProvider(),
      ),
    );

    expect(
      await analyzer.isPurposeGranted(RemoteProcessingPurpose.remoteTranscription),
      isFalse,
    );
    expect(
      await analyzer.isPurposeGranted(RemoteProcessingPurpose.remoteReflection),
      isFalse,
    );
  });

  test('default on-device mode is enabled', () async {
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.ensureLoaded();
    expect(OnDeviceProcessingStore.enabled, isTrue);
  });
}
