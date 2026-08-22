import 'package:archiveme_mobile/audio/hardware_audio_config.dart';
import 'package:archiveme_mobile/audio/silence_retry_policy.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SilenceRetryPolicy', () {
    test('triggers retry below threshold when eligible', () async {
      final policy = SilenceRetryPolicy(_EligibleHardwareAudioConfig());

      expect(
        await policy.shouldRetryForInitialSilence(maxDbInInitialWindow: -53),
        isTrue,
      );
    });

    test('does not retry when levels are healthy', () async {
      final policy = SilenceRetryPolicy(_EligibleHardwareAudioConfig());

      expect(
        await policy.shouldRetryForInitialSilence(maxDbInInitialWindow: -35),
        isFalse,
      );
    });

    test('does not retry twice', () async {
      final policy = SilenceRetryPolicy(_EligibleHardwareAudioConfig());
      policy.commitRetryAttempt();

      expect(
        await policy.shouldRetryForInitialSilence(maxDbInInitialWindow: -60),
        isFalse,
      );
    });

    test('does not retry when config is ineligible', () async {
      final policy = SilenceRetryPolicy(_IneligibleHardwareAudioConfig());

      expect(
        await policy.shouldRetryForInitialSilence(maxDbInInitialWindow: -60),
        isFalse,
      );
    });

    test('does not schedule initial check when retry is disabled', () {
      final policy = SilenceRetryPolicy(_IneligibleHardwareAudioConfig());
      var invoked = false;

      policy.scheduleInitialSilenceCheck(() async {
        invoked = true;
      });

      expect(policy.retryAttempted, isFalse);
      expect(invoked, isFalse);
    });
  });
}

final class _EligibleHardwareAudioConfig implements HardwareAudioConfig {
  @override
  bool get schedulesCaptureSilenceRetry => true;

  @override
  Future<bool> captureSilenceRetryEligible() async => true;

  @override
  Duration get silenceRetryInitialWindow => const Duration(seconds: 2);

  @override
  double get silenceRetryThresholdDb => -50;

  @override
  double get captureSilentThresholdDb => -45;

  @override
  IosCaptureAudioMode get primaryCaptureAudioMode =>
      IosCaptureAudioMode.spokenAudio;

  @override
  IosCaptureAudioMode get silenceRetryCaptureAudioMode =>
      IosCaptureAudioMode.measurement;

  @override
  VadStreamConfig get vadStreamConfig => const VadStreamConfig();

  @override
  bool shouldShowBuiltInMicSilentGuidance({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) =>
      false;

  @override
  String? captureInputRecommendation({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) =>
      null;

  @override
  String? captureInputDebugLabel({String? portName, String? portType}) => null;
}

final class _IneligibleHardwareAudioConfig implements HardwareAudioConfig {
  @override
  bool get schedulesCaptureSilenceRetry => false;

  @override
  Future<bool> captureSilenceRetryEligible() async => false;

  @override
  Duration get silenceRetryInitialWindow => const Duration(seconds: 2);

  @override
  double get silenceRetryThresholdDb => -50;

  @override
  double get captureSilentThresholdDb => -45;

  @override
  IosCaptureAudioMode get primaryCaptureAudioMode =>
      IosCaptureAudioMode.spokenAudio;

  @override
  IosCaptureAudioMode get silenceRetryCaptureAudioMode =>
      IosCaptureAudioMode.spokenAudio;

  @override
  VadStreamConfig get vadStreamConfig => const VadStreamConfig();

  @override
  bool shouldShowBuiltInMicSilentGuidance({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) =>
      false;

  @override
  String? captureInputRecommendation({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) =>
      null;

  @override
  String? captureInputDebugLabel({String? portName, String? portType}) => null;
}
