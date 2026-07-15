import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';

void main() {
  group('Microphone pre-prompt Apple compliance', () {
    test('request CTA avoids system-style permission words', () {
      expect(
        MicrophonePermissionCopy.requestMicrophoneCta,
        'Use voice',
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

    test('pre-prompt title does not use Allow or OK', () {
      final title = MicrophonePermissionCopy.neededTitle.toLowerCase();
      expect(title, isNot(contains('allow')));
      expect(title, isNot(startsWith('ok')));
    });
  });
}
