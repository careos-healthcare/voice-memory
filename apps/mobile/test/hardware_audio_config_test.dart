import 'package:archiveme_mobile/audio/hardware_audio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IOSAudioConfig', () {
    const config = IOSAudioConfig();

    test('enables silence retry scheduling', () {
      expect(config.schedulesCaptureSilenceRetry, isTrue);
      expect(config.silenceRetryThresholdDb, -50);
      expect(config.captureSilentThresholdDb, -45);
    });

    test('shows built-in mic guidance for silent built-in input', () {
      expect(
        config.shouldShowBuiltInMicSilentGuidance(
          likelySilent: true,
          portType: 'BuiltInMic',
        ),
        isTrue,
      );
    });
  });

  group('AndroidAudioConfig', () {
    const config = AndroidAudioConfig();

    test('disables silence retry scheduling', () {
      expect(config.schedulesCaptureSilenceRetry, isFalse);
    });

    test('does not show built-in mic guidance', () {
      expect(
        config.shouldShowBuiltInMicSilentGuidance(
          likelySilent: true,
          portType: 'BuiltInMic',
        ),
        isFalse,
      );
      expect(
        config.captureInputRecommendation(
          likelySilent: true,
          portType: 'BuiltInMic',
        ),
        isNull,
      );
    });
  });
}
