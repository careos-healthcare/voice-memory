import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/beta/tester_mission_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/support/support_feedback_copy.dart';
import 'package:archiveme_mobile/features/trust/capture_recovery_copy.dart';
import 'package:archiveme_mobile/features/trust/capture_recovery_gates.dart';
import 'package:archiveme_mobile/features/trust/trust_reliability_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/security/privacy_data_controls_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/widgets/about/privacy_trust_section.dart';
import 'package:archiveme_mobile/widgets/record/capture_recovery_hint_strip.dart';
import 'package:archiveme_mobile/widgets/record/microphone_permission_blocked_panel.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_data_controls_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecoveryFailingAnalyzeApi implements CaptureApiClient {
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
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiFailureResult(
      ApiFailureMapper.fromException(
        const SocketException('Network unavailable'),
      ),
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

JournalEntry _entry({required String id, required DateTime createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript:
          'A long enough transcript to count as a saved reflection for tests.',
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'You mentioned pressure in this moment.',
        repeatedSignal: '',
      ),
    );

void main() {
  group('CaptureRecoveryCopy canonical recovery messages', () {
    test('matches reliability brief', () {
      expect(
        CaptureRecoveryCopy.micDeniedBody,
        MicrophonePermissionCopy.deniedBody,
      );
      expect(
        CaptureRecoveryCopy.recordingFailed,
        VoiceCaptureCopy.recordingFailed,
      );
      expect(CaptureRecoveryCopy.saveFailed, VoiceCaptureCopy.saveFailed);
      expect(
        CaptureRecoveryCopy.transcriptUnavailable,
        VoiceCaptureCopy.transcriptUnavailable,
      );
      expect(
        CaptureRecoveryCopy.noClearMatchYet,
        EarlyRepeatProgressCopy.twoUnrelatedBody,
      );
      expect(
        CaptureRecoveryCopy.noClearMatchYet,
        PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedBody,
      );
      expect(
        TesterMissionCopy.entry2UnrelatedBody,
        'Step 2 still forming. Record the next real moment.',
      );
    });

    test('avoid scary therapy and transcript dump language', () {
      for (final line in CaptureRecoveryCopy.all) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('diagnosis')));
        expect(lower, isNot(contains('therapy')));
        expect(lower, isNot(contains('transcript:')));
        expect(lower, isNot(contains('failed catastrophically')));
      }
    });
  });

  group('Microphone permission copy', () {
    test('denied copy is calm and actionable', () {
      expect(MicrophonePermissionCopy.neededTitle, 'Record with your voice');
      expect(
        MicrophonePermissionCopy.neededBody,
        contains('Ten seconds is enough'),
      );
      expect(
        MicrophonePermissionCopy.deniedBody,
        CaptureRecoveryCopy.micDeniedBody,
      );
      expect(
        MicrophonePermissionCopy.deniedBody,
        contains('Turn it on in Settings'),
      );
      expect(
        MicrophonePermissionCopy.deniedBody,
        contains('use text if available'),
      );
      expect(
        MicrophonePermissionCopy.deniedBody.toLowerCase(),
        isNot(contains('ai listens')),
      );
      expect(
        MicrophonePermissionCopy.deniedBody.toLowerCase(),
        isNot(contains('therapy')),
      );
    });

    testWidgets('blocked panel shows denied guidance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophonePermissionBlockedPanel(
              onOpenSettings: () {},
              onTypeInstead: () async {},
            ),
          ),
        ),
      );

      expect(find.text(MicrophonePermissionCopy.neededTitle), findsOneWidget);
      expect(find.text(MicrophonePermissionCopy.deniedBody), findsOneWidget);
    });
  });

  group('Recording and save failure copy', () {
    test('recording failure offers text fallback path', () {
      expect(
        VoiceCaptureCopy.recordingFailed,
        CaptureRecoveryCopy.recordingFailed,
      );
      expect(
        VoiceCaptureCopy.recordingFailed,
        contains('save a short text moment'),
      );

      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.error,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
      );
      expect(policy.state, RecordCtaPolicyState.error);
      expect(policy.secondaryLabels, isNotEmpty);
    });

    test('save failure does not claim saved', () {
      expect(VoiceCaptureCopy.saveFailed, CaptureRecoveryCopy.saveFailed);
      expect(VoiceCaptureCopy.saveFailed, contains('not saved'));
      expect(
        VoiceCaptureCopy.saveFailed.toLowerCase(),
        isNot(contains('saved privately')),
      );
      expect(
        VoiceCaptureCopy.saveFailed.toLowerCase(),
        isNot(contains('moment saved')),
      );
    });

    test('transcript unavailable confirms save without dumping text', () {
      expect(
        VoiceCaptureCopy.transcriptUnavailable,
        CaptureRecoveryCopy.transcriptUnavailable,
      );
      expect(
        VoiceCaptureCopy.transcriptUnavailable,
        contains('saved the moment'),
      );
      expect(
        VoiceCaptureCopy.transcriptUnavailable,
        contains('transcript may need another try'),
      );
      expect(
        VoiceCaptureCopy.transcriptUnavailable,
        isNot(contains('transcript:')),
      );
    });

    test('local text save failure throws not saved copy', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_save_fail_');
      final journalPath = '${tempDir.path}/journal.json';
      await AppServices.resetForTest(
        journalPath: journalPath,
        skipRevenueCat: true,
        networkOverrides: [
          captureApiClientProvider.overrideWithValue(
            _RecoveryFailingAnalyzeApi(),
          ),
        ],
      );
      Process.runSync('chmod', ['444', journalPath]);

      await expectLater(
        AppServices.instance.pipeline.saveTextThought(
          transcript: 'Pressure showed up again during the meeting.',
        ),
        throwsA(
          predicate<CapturePipelineFailure>(
            (e) => e.message == VoiceCaptureCopy.saveFailed,
          ),
        ),
      );
      Process.runSync('chmod', ['644', journalPath]);
    });
  });

  group('No clear match and return-after-delay recovery', () {
    test('unrelated entries use shared no clear match copy', () {
      expect(
        EarlyRepeatProgressCopy.twoUnrelatedBody,
        'No clear match yet — that is okay. Record the next real moment.',
      );
    });

    test('returning after delay copy is calm', () {
      expect(
        CaptureRecoveryCopy.returnedAfterDelayBody,
        'Record what came up today — short is fine.',
      );
    });

    testWidgets('returned-after-delay strip renders welcome back', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CaptureRecoveryHintStrip.returnedAfterDelay()),
        ),
      );

      expect(
        find.byKey(const Key('capture_recovery_returned_after_delay')),
        findsOneWidget,
      );
      expect(
        find.text(CaptureRecoveryCopy.returnedAfterDelayTitle),
        findsOneWidget,
      );
      expect(
        find.text(CaptureRecoveryCopy.returnedAfterDelayBody),
        findsOneWidget,
      );
    });

    test('return gate opens after several days away', () {
      final now = DateTime(2026, 6, 15, 12);
      final entries = [
        _entry(id: 'e1', createdAt: now.subtract(const Duration(days: 5))),
      ];
      expect(
        CaptureRecoveryGates.daysSinceLastEntry(entries: entries, now: now),
        5,
      );
      expect(
        CaptureRecoveryGates.showReturnedAfterDelay(
          entryCount: 1,
          daysSinceLastEntry: 5,
          isReady: true,
          isRecording: false,
          isPostSave: false,
        ),
        isTrue,
      );
      expect(
        CaptureRecoveryGates.showReturnedAfterDelay(
          entryCount: 1,
          daysSinceLastEntry: 1,
          isReady: true,
          isRecording: false,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('test build recovery copy stays calm and local-first', () {
      expect(
        CaptureRecoveryCopy.testBuildEntitlementTimeout.toLowerCase(),
        contains('still work'),
      );
      expect(
        CaptureRecoveryCopy.testBuildNetworkUnavailable.toLowerCase(),
        contains('still works'),
      );
    });
  });

  group('Privacy and support trust copy', () {
    testWidgets('About trust section is visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyTrustSection())),
      );

      expect(find.text(TrustReliabilityCopy.sectionTitle), findsOneWidget);
      expect(
        find.text(TrustReliabilityCopy.archivePrivateTitle),
        findsOneWidget,
      );
      expect(find.text(TrustReliabilityCopy.resetArchiveTitle), findsOneWidget);
      expect(
        find.text(TrustReliabilityCopy.copyPrivateReportsTitle),
        findsOneWidget,
      );
      expect(
        find.text(TrustReliabilityCopy.supportAvailableTitle),
        findsOneWidget,
      );
    });

    test('support URL is configured', () {
      expect(AppConfig.supportUrl, SupportFeedbackCopy.supportUrl);
      expect(AppConfig.supportUrl, contains('archiveme-support'));
    });

    test('no false never-leaves-device claims in trust copy', () {
      for (final text in [
        TrustReliabilityCopy.archivePrivateSubtitle,
        TrustReliabilityCopy.resetArchiveSubtitle,
        TrustReliabilityCopy.copyPrivateReportsSubtitle,
        PrivacyCopyPolicy.personalNotMedicalDisclaimer,
      ]) {
        expect(text.toLowerCase(), isNot(contains('never leaves')));
        expect(text.toLowerCase(), isNot(contains('never leaves the device')));
      }
    });
  });

  group('Reset archive confirmation', () {
    testWidgets('reset requires confirmation with clear consequences', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClearLocalArchiveDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();

      expect(
        find.text(PrivacyDataControlsCopy.clearLocalArchiveConfirmTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyDataControlsCopy.clearLocalArchiveConfirmBody),
        findsOneWidget,
      );
      expect(find.text(PrivacyDataControlsCopy.cancel), findsOneWidget);
      expect(
        find.text(PrivacyDataControlsCopy.clearArchiveConfirm),
        findsOneWidget,
      );
      expect(
        PrivacyDataControlsCopy.clearLocalArchiveConfirmBody,
        contains('cannot be undone'),
      );
    });
  });

  group('Export and report copy', () {
    test('private report copy does not imply audio sharing', () {
      expect(PrivateArchiveReportCopy.copyReportCta, 'Copy report');
      expect(
        PrivateArchiveReportCopy.intro,
        contains('private summary from your saved moments'),
      );
      expect(
        PrivateArchiveReportCopy.intro.toLowerCase(),
        isNot(contains('share audio')),
      );
    });
  });

  group('Billing isolation', () {
    test('recovery copy files do not touch billing RevenueCat restore', () {
      final joined = CaptureRecoveryCopy.all.join('\n').toLowerCase();
      expect(joined, isNot(contains('revenuecat')));
      expect(joined, isNot(contains('restore purchases')));
    });
  });
}