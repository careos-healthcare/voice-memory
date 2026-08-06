import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_lifecycle_policy.dart';

void main() {
  group('LiveVoiceLifecyclePolicy', () {
    test('shouldPauseCapture for inactive, paused, and hidden', () {
      expect(
        LiveVoiceLifecyclePolicy.shouldPauseCapture(AppLifecycleState.inactive),
        isTrue,
      );
      expect(
        LiveVoiceLifecyclePolicy.shouldPauseCapture(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        LiveVoiceLifecyclePolicy.shouldPauseCapture(AppLifecycleState.hidden),
        isTrue,
      );
      expect(
        LiveVoiceLifecyclePolicy.shouldPauseCapture(AppLifecycleState.resumed),
        isFalse,
      );
    });

    test(
      'shouldAttemptCaptureResume requires foreground and healthy session',
      () {
        expect(
          LiveVoiceLifecyclePolicy.shouldAttemptCaptureResume(
            state: AppLifecycleState.resumed,
            sessionActive: true,
            hasError: false,
            isSaving: false,
          ),
          isTrue,
        );
        expect(
          LiveVoiceLifecyclePolicy.shouldAttemptCaptureResume(
            state: AppLifecycleState.paused,
            sessionActive: true,
            hasError: false,
            isSaving: false,
          ),
          isFalse,
        );
        expect(
          LiveVoiceLifecyclePolicy.shouldAttemptCaptureResume(
            state: AppLifecycleState.resumed,
            sessionActive: true,
            hasError: true,
            isSaving: false,
          ),
          isFalse,
        );
      },
    );
  });
}
