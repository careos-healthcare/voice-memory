import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_data_flow.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/security/archive_privacy_controls_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteProcessingDataFlow copy alignment', () {
    test('purpose map covers every beta purpose', () {
      expect(
        RemoteProcessingDataFlow.purposeFlows.keys,
        containsAll(RemoteProcessingPurpose.values),
      );
    });

    test('onboarding copy matches transcription and reflection data map', () {
      final transcription =
          RemoteProcessingDataFlow.purposeFlows[
            RemoteProcessingPurpose.remoteTranscription
          ]!;
      final reflection =
          RemoteProcessingDataFlow.purposeFlows[
            RemoteProcessingPurpose.remoteReflection
          ]!;

      expect(transcription.sendsAudio, isTrue);
      expect(transcription.sendsText, isFalse);
      expect(reflection.sendsAudio, isFalse);
      expect(reflection.sendsText, isTrue);

      expect(
        RemoteProcessingConsentCopy.detailBullet1.toLowerCase(),
        contains('audio'),
      );
      expect(
        RemoteProcessingConsentCopy.detailBullet1.toLowerCase(),
        contains('transcript'),
      );
      expect(
        RemoteProcessingConsentCopy.detailBullet3.toLowerCase(),
        contains('nothing is sent'),
      );
      expect(
        RemoteProcessingConsentCopy.declinedFootnote.toLowerCase(),
        isNot(contains('on-device transcription')),
      );
    });

    test('privacy and data-flow surfaces mention consent-gated sending', () {
      for (final copy in [
        PrivacyScreenCopy.aiProcessingBody,
        PrivacyScreenCopy.remoteProcessingSwitchBodyOff,
        ArchiveDataFlowCopy.bodySections.join(' '),
      ]) {
        expect(copy.toLowerCase(), isNot(contains('never sent')));
        expect(copy.toLowerCase(), contains('device'));
      }

      expect(
        PrivacyScreenCopy.aiProcessingBody.toLowerCase(),
        contains('audio'),
      );
      expect(
        PrivacyScreenCopy.aiProcessingBody.toLowerCase(),
        contains('transcript'),
      );
    });
  });
}
