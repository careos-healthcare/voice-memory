import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/mic_capture_input_health.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_environment.dart';

/// Platform-specific audio capture health, silence retry, and VAD settings.
abstract interface class HardwareAudioConfig {
  /// Whether to schedule the initial-window silence retry timer during capture.
  bool get schedulesCaptureSilenceRetry;

  /// Whether silence retry is eligible for the current runtime environment.
  Future<bool> captureSilenceRetryEligible();

  Duration get silenceRetryInitialWindow;

  double get silenceRetryThresholdDb;

  /// Post-capture dB threshold for marking input as likely silent.
  double get captureSilentThresholdDb;

  IosCaptureAudioMode get primaryCaptureAudioMode;

  IosCaptureAudioMode get silenceRetryCaptureAudioMode;

  VadStreamConfig get vadStreamConfig;

  bool shouldShowBuiltInMicSilentGuidance({
    required bool likelySilent,
    String? portType,
    String? portName,
  });

  String? captureInputRecommendation({
    required bool likelySilent,
    String? portType,
    String? portName,
  });

  String? captureInputDebugLabel({String? portName, String? portType});
}

/// iOS capture defaults — silence retry on physical devices, built-in mic guidance.
final class IOSAudioConfig implements HardwareAudioConfig {
  const IOSAudioConfig();

  @override
  bool get schedulesCaptureSilenceRetry => true;

  @override
  Future<bool> captureSilenceRetryEligible() =>
      MicrophonePermissionEnvironment.isIosPhysicalDevice();

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
      MicCaptureInputHealth.shouldShowBuiltInSilentGuidance(
        likelySilent: likelySilent,
        portType: portType,
        portName: portName,
      );

  @override
  String? captureInputRecommendation({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) =>
      MicCaptureInputHealth.recommendation(
        likelySilent: likelySilent,
        portType: portType,
        portName: portName,
      );

  @override
  String? captureInputDebugLabel({String? portName, String? portType}) =>
      MicCaptureInputHealth.debugInputLabel(
        portName: portName,
        portType: portType,
      );
}

/// Android capture defaults — no silence retry or built-in mic routing guidance.
final class AndroidAudioConfig implements HardwareAudioConfig {
  const AndroidAudioConfig();

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
