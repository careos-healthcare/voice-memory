import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Microphone pre-prompt Apple compliance', () {
    test('request CTA avoids system-style permission words', () {
      expect(
        MicrophonePermissionCopy.requestMicrophoneCta,
        'Use voice to record',
      );
      expect(
        MicrophonePermissionCopy.isAppleCompliantPrePromptCta(
          MicrophonePermissionCopy.requestMicrophoneCta,
        ),
        isTrue,
      );
    });

    test('rejects Allow/OK/Grant/Permit style CTAs', () {
      for (final bad in [
        'Allow microphone',
        'Allow',
        'OK',
        'Grant access',
        'Permit recording',
      ]) {
        expect(
          MicrophonePermissionCopy.isAppleCompliantPrePromptCta(bad),
          isFalse,
          reason: bad,
        );
      }
    });

    test('granted microphone hides the explanation; other states keep it', () {
      expect(
        MicrophonePermissionCopy.showsPermissionExplanation(
          granted: true,
          blocked: false,
          requiresSettings: false,
        ),
        isFalse,
      );
      expect(
        MicrophonePermissionCopy.showsPermissionExplanation(
          granted: false,
          blocked: false,
          requiresSettings: false,
        ),
        isTrue,
      );
      expect(MicrophonePermissionCopy.saveTypedCta, 'Save');
      expect(MicrophonePermissionCopy.savedOnDevice, 'Saved on this device.');
      expect(MicrophonePermissionCopy.startRecordingLabel, 'Start recording');
    });

    test('requesting status avoids Allow/OK wording', () {
      final status = MicrophonePermissionCopy.statusRequesting.toLowerCase();
      expect(status, isNot(contains('allow')));
      expect(status, isNot(startsWith('ok')));
    });
  });
}