import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_lifecycle_rules.dart';

void main() {
  group('LiveVoiceLifecycleRules', () {
    test('shouldPauseCapture for inactive, paused, and hidden', () {
      expect(
        LiveVoiceLifecycleRules.shouldPauseCapture(AppLifecycleState.inactive),
        isTrue,
      );
      expect(
        LiveVoiceLifecycleRules.shouldPauseCapture(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        LiveVoiceLifecycleRules.shouldPauseCapture(AppLifecycleState.hidden),
        isTrue,
      );
      expect(
        LiveVoiceLifecycleRules.shouldPauseCapture(AppLifecycleState.resumed),
        isFalse,
      );
    });

    test(
      'shouldAttemptCaptureResume requires foreground and healthy session',
      () {
        expect(
          LiveVoiceLifecycleRules.shouldAttemptCaptureResume(
            state: AppLifecycleState.resumed,
            sessionActive: true,
            hasError: false,
            isSaving: false,
          ),
          isTrue,
        );
        expect(
          LiveVoiceLifecycleRules.shouldAttemptCaptureResume(
            state: AppLifecycleState.paused,
            sessionActive: true,
            hasError: false,
            isSaving: false,
          ),
          isFalse,
        );
        expect(
          LiveVoiceLifecycleRules.shouldAttemptCaptureResume(
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
