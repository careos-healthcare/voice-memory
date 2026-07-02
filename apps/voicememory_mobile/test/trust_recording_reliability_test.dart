import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/support/support_feedback_copy.dart';
import 'package:voicememory_mobile/features/trust/trust_reliability_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/widgets/about/privacy_trust_section.dart';
import 'package:voicememory_mobile/widgets/record/microphone_permission_blocked_panel.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_dialogs.dart';

void main() {
  group('Microphone permission copy', () {
    test('denied copy is calm and actionable', () {
      expect(MicrophonePermissionCopy.neededTitle, 'Microphone access is needed');
      expect(
        MicrophonePermissionCopy.neededBody,
        contains('Ten seconds is enough'),
      );
      expect(
        MicrophonePermissionCopy.deniedBody,
        contains('Turn it on in Settings'),
      );
      expect(
        MicrophonePermissionCopy.deniedBody,
        contains('use text if available'),
      );
      expect(MicrophonePermissionCopy.deniedBody.toLowerCase(), isNot(contains('ai listens')));
      expect(MicrophonePermissionCopy.deniedBody.toLowerCase(), isNot(contains('therapy')));
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
      expect(VoiceCaptureCopy.saveFailed, contains('not saved'));
      expect(VoiceCaptureCopy.saveFailed.toLowerCase(), isNot(contains('saved privately')));
      expect(VoiceCaptureCopy.saveFailed.toLowerCase(), isNot(contains('moment saved')));
    });

    test('transcript unavailable confirms save without dumping text', () {
      expect(
        VoiceCaptureCopy.transcriptUnavailable,
        contains('saved the moment'),
      );
      expect(VoiceCaptureCopy.transcriptUnavailable, isNot(contains('transcript:')));
    });
  });

  group('Privacy and support trust copy', () {
    testWidgets('About trust section is visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyTrustSection()),
        ),
      );

      expect(find.text(TrustReliabilityCopy.sectionTitle), findsOneWidget);
      expect(find.text(TrustReliabilityCopy.archivePrivateTitle), findsOneWidget);
      expect(find.text(TrustReliabilityCopy.resetArchiveTitle), findsOneWidget);
      expect(find.text(TrustReliabilityCopy.copyPrivateReportsTitle), findsOneWidget);
      expect(find.text(TrustReliabilityCopy.supportAvailableTitle), findsOneWidget);
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
      expect(find.text(PrivacyDataControlsCopy.clearArchiveConfirm), findsOneWidget);
      expect(
        PrivacyDataControlsCopy.clearLocalArchiveConfirmBody,
        contains('cannot be undone'),
      );
    });
  });

  group('Export and report copy', () {
    test('private report copy does not imply audio sharing', () {
      expect(
        PrivateArchiveReportCopy.copyReportCta,
        'Copy private report',
      );
      expect(
        PrivateArchiveReportCopy.copyReportHelper,
        contains('not audio'),
      );
      expect(
        PrivateArchiveReportCopy.copyReportHelper.toLowerCase(),
        isNot(contains('share audio')),
      );
    });
  });
}
