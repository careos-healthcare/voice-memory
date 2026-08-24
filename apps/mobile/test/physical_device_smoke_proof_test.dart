import 'dart:io';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/physical_device_smoke/physical_device_smoke_proof.dart';
import 'package:archiveme_mobile/features/physical_device_smoke/physical_device_smoke_proof_copy.dart';
import 'package:flutter_test/flutter_test.dart';

const _docsPath = 'docs/physical_device_smoke_proof.md';

PhysicalDeviceSmokeProofInput _input({
  bool? freshInstallOpens = true,
  bool appNameArchiveMe = true,
  bool? launchScreenOk = true,
  bool? micPermissionAcceptPath = true,
  bool? micPermissionDenyPath = true,
  bool? typedSave = true,
  bool? voiceSave = true,
  bool? transcriptAppears = true,
  bool? postSaveReinforcementAppears = true,
  bool? firstProofPath = true,
  bool? correctionPath = true,
  bool? proScreenOpens = true,
  bool? revenueCatProductLoad = true,
  bool purchaseUnavailableCopySafe = true,
  bool? restorePathOpens = true,
  bool privacyTermsSupportRoutesOpen = true,
  bool? offlineLaunchSafe = true,
  bool? noCrash = true,
  bool noPrivateTextLeakedInLogs = true,
}) => PhysicalDeviceSmokeProofInput(
  freshInstallOpens: freshInstallOpens,
  appNameArchiveMe: appNameArchiveMe,
  launchScreenOk: launchScreenOk,
  micPermissionAcceptPath: micPermissionAcceptPath,
  micPermissionDenyPath: micPermissionDenyPath,
  typedSave: typedSave,
  voiceSave: voiceSave,
  transcriptAppears: transcriptAppears,
  postSaveReinforcementAppears: postSaveReinforcementAppears,
  firstProofPath: firstProofPath,
  correctionPath: correctionPath,
  proScreenOpens: proScreenOpens,
  revenueCatProductLoad: revenueCatProductLoad,
  purchaseUnavailableCopySafe: purchaseUnavailableCopySafe,
  restorePathOpens: restorePathOpens,
  privacyTermsSupportRoutesOpen: privacyTermsSupportRoutesOpen,
  offlineLaunchSafe: offlineLaunchSafe,
  noCrash: noCrash,
  noPrivateTextLeakedInLogs: noPrivateTextLeakedInLogs,
);

PhysicalDeviceSmokeProofCheck _check(
  PhysicalDeviceSmokeProofResult result,
  PhysicalDeviceSmokeProofCheckId id,
) => result.checks.firstWhere((check) => check.id == id);

void main() {
  group('PhysicalDeviceSmokeProof.build', () {
    test('checklist has nineteen canonical items', () {
      final result = PhysicalDeviceSmokeProof.build(_input());
      expect(result.checks.length, PhysicalDeviceSmokeProof.checkCount);
      expect(result.checks.map((check) => check.id).toList(), [
        PhysicalDeviceSmokeProofCheckId.freshInstallOpens,
        PhysicalDeviceSmokeProofCheckId.appNameArchiveMe,
        PhysicalDeviceSmokeProofCheckId.launchScreenOk,
        PhysicalDeviceSmokeProofCheckId.micPermissionAcceptPath,
        PhysicalDeviceSmokeProofCheckId.micPermissionDenyPath,
        PhysicalDeviceSmokeProofCheckId.typedSave,
        PhysicalDeviceSmokeProofCheckId.voiceSave,
        PhysicalDeviceSmokeProofCheckId.transcriptAppears,
        PhysicalDeviceSmokeProofCheckId.postSaveReinforcementAppears,
        PhysicalDeviceSmokeProofCheckId.firstProofPath,
        PhysicalDeviceSmokeProofCheckId.correctionPath,
        PhysicalDeviceSmokeProofCheckId.proScreenOpens,
        PhysicalDeviceSmokeProofCheckId.revenueCatProductLoad,
        PhysicalDeviceSmokeProofCheckId.purchaseUnavailableCopySafe,
        PhysicalDeviceSmokeProofCheckId.restorePathOpens,
        PhysicalDeviceSmokeProofCheckId.privacyTermsSupportRoutesOpen,
        PhysicalDeviceSmokeProofCheckId.offlineLaunchSafe,
        PhysicalDeviceSmokeProofCheckId.noCrash,
        PhysicalDeviceSmokeProofCheckId.noPrivateTextLeakedInLogs,
      ]);
    });

    test('all checks pass -> proved', () {
      final result = PhysicalDeviceSmokeProof.build(_input());
      expect(result.decision, PhysicalDeviceSmokeProofDecision.proved);
      expect(result.allPassed, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('pending device steps -> manualRequired', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(
          freshInstallOpens: null,
          launchScreenOk: null,
          micPermissionAcceptPath: null,
          micPermissionDenyPath: null,
          typedSave: null,
          voiceSave: null,
          transcriptAppears: null,
          postSaveReinforcementAppears: null,
          firstProofPath: null,
          correctionPath: null,
          proScreenOpens: null,
          revenueCatProductLoad: null,
          restorePathOpens: null,
          offlineLaunchSafe: null,
          noCrash: null,
        ),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.manualRequired);
    });

    test('wrong app name -> blocked', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(appNameArchiveMe: false),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.blocked);
      expect(
        result.earliestBlocker,
        PhysicalDeviceSmokeProofCheckId.appNameArchiveMe,
      );
    });

    test('purchase unavailable copy unsafe -> blocked', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(purchaseUnavailableCopySafe: false),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.blocked);
    });

    test('privacy routes missing -> blocked', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(privacyTermsSupportRoutesOpen: false),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.blocked);
    });

    test('private text log policy fail -> blocked', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(noPrivateTextLeakedInLogs: false),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.blocked);
    });

    test('fresh install fail blocks later capture checks', () {
      final result = PhysicalDeviceSmokeProof.build(
        _input(freshInstallOpens: false),
      );
      expect(
        _check(result, PhysicalDeviceSmokeProofCheckId.typedSave).status,
        PhysicalDeviceSmokeProofStatus.blocked,
      );
    });

    test('report exposes canonical copy', () {
      final report = PhysicalDeviceSmokeProof.report(
        PhysicalDeviceSmokeProof.build(_input()),
      );
      expect(report.headline, PhysicalDeviceSmokeProofCopy.headline);
      expect(report.guardrail, PhysicalDeviceSmokeProofCopy.guardrail);
    });
  });

  group('PhysicalDeviceSmokeProof.fromRepoSignals', () {
    late String infoPlistSource;
    late String launchScreenSource;
    late String micPermissionCopySource;
    late String visibleArchiveProofCopySource;
    late String recordFramingCopySource;
    late String transcriptCorrectionCopySource;
    late String archiveEvidenceGateSource;
    late String postSaveReinforcementCopySource;
    late String appRouterSource;
    late String securitySettingsSource;
    late String proValueCopySource;
    late String recordPipelineLogSource;

    setUpAll(() {
      infoPlistSource = File('ios/Runner/Info.plist').readAsStringSync();
      launchScreenSource = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      micPermissionCopySource = File(
        'lib/features/voice_capture/microphone_permission_copy.dart',
      ).readAsStringSync();
      visibleArchiveProofCopySource = File(
        'lib/features/archive_proof/visible_archive_proof_copy.dart',
      ).readAsStringSync();
      recordFramingCopySource = File(
        'lib/record/record_screen_framing_copy.dart',
      ).readAsStringSync();
      transcriptCorrectionCopySource = File(
        'lib/features/transcript_correction/transcript_correction_copy.dart',
      ).readAsStringSync();
      archiveEvidenceGateSource = File(
        'lib/features/archive_evidence/archive_evidence_quality_gate.dart',
      ).readAsStringSync();
      postSaveReinforcementCopySource = File(
        'lib/features/post_save_reinforcement/post_save_reinforcement_placement_copy.dart',
      ).readAsStringSync();
      appRouterSource = File('lib/router/app_router.dart').readAsStringSync();
      securitySettingsSource = File(
        'lib/features/settings/screens/security_settings_screen.dart',
      ).readAsStringSync();
      proValueCopySource = File(
        'lib/features/pro_value/pro_value_copy.dart',
      ).readAsStringSync();
      recordPipelineLogSource = File(
        'lib/services/record_pipeline_log.dart',
      ).readAsStringSync();
    });

    test('repo signals detect ArchiveMe name and trust routes', () {
      expect(
        PhysicalDeviceSmokeProof.detectAppNameArchiveMe(infoPlistSource),
        isTrue,
      );
      expect(
        PhysicalDeviceSmokeProof.detectLaunchScreenPresent(launchScreenSource),
        isTrue,
      );
      expect(
        PhysicalDeviceSmokeProof.detectPrivacyTermsSupportRoutes(
          appRouterSource,
        ),
        isTrue,
      );
      expect(
        PhysicalDeviceSmokeProof.detectPurchaseUnavailableCopy(
          proValueCopySource,
        ),
        isTrue,
      );
      expect(
        PhysicalDeviceSmokeProof.detectLogPrivacyPolicy(
          recordPipelineLogSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals returns manualRequired with repo checks passing', () {
      final result = PhysicalDeviceSmokeProof.build(
        PhysicalDeviceSmokeProof.fromRepoSignals(
          infoPlistSource: infoPlistSource,
          launchScreenStoryboardSource: launchScreenSource,
          micPermissionCopySource: micPermissionCopySource,
          visibleArchiveProofCopySource: visibleArchiveProofCopySource,
          recordFramingCopySource: recordFramingCopySource,
          transcriptCorrectionCopySource: transcriptCorrectionCopySource,
          archiveEvidenceGateSource: archiveEvidenceGateSource,
          postSaveReinforcementCopySource: postSaveReinforcementCopySource,
          appRouterSource: appRouterSource,
          securitySettingsSource: securitySettingsSource,
          proValueCopySource: proValueCopySource,
          recordPipelineLogSource: recordPipelineLogSource,
        ),
      );
      expect(result.decision, PhysicalDeviceSmokeProofDecision.manualRequired);
      expect(
        _check(result, PhysicalDeviceSmokeProofCheckId.appNameArchiveMe).status,
        PhysicalDeviceSmokeProofStatus.pass,
      );
      expect(
        _check(
          result,
          PhysicalDeviceSmokeProofCheckId.privacyTermsSupportRoutesOpen,
        ).status,
        PhysicalDeviceSmokeProofStatus.pass,
      );
    });
  });

  group('Release smoke guard', () {
    test('missing RevenueCat key does not crash initialize', () async {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      expect(rc.isConfigured, isFalse);
      expect(rc.diagnostics.apiKeyMissing, isTrue);
    });
  });

  group('protected regression', () {
    test('docs describe checklist-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('proof/checklist only'));
      expect(doc, contains('no feature changes'));
      expect(doc, contains('iphone'));
    });

    test('guardrail forbids feature changes', () {
      final lower = PhysicalDeviceSmokeProofCopy.guardrail.toLowerCase();
      expect(lower, contains('checklist only'));
      expect(lower, contains('do not change product features'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PhysicalDeviceSmokeProofCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}