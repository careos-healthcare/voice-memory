import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_silence_retry.dart';

void main() {
  group('AudioSilenceRetryPolicy', () {
    test('triggers retry below -50 on iOS physical', () {
      expect(
        AudioSilenceRetryPolicy.shouldRetryInitialSilence(
          isIosPhysical: true,
          retryAlreadyAttempted: false,
          maxDbInInitialWindow: -53,
        ),
        isTrue,
      );
    });

    test('does not retry when levels are healthy', () {
      expect(
        AudioSilenceRetryPolicy.shouldSkipRetry(
          isIosPhysical: true,
          retryAlreadyAttempted: false,
          maxDbInInitialWindow: -35,
        ),
        isTrue,
      );
    });

    test('does not retry twice', () {
      expect(
        AudioSilenceRetryPolicy.shouldRetryInitialSilence(
          isIosPhysical: true,
          retryAlreadyAttempted: true,
          maxDbInInitialWindow: -60,
        ),
        isFalse,
      );
    });

    test('does not retry off physical iOS', () {
      expect(
        AudioSilenceRetryPolicy.shouldRetryInitialSilence(
          isIosPhysical: false,
          retryAlreadyAttempted: false,
          maxDbInInitialWindow: -60,
        ),
        isFalse,
      );
    });
  });
}
