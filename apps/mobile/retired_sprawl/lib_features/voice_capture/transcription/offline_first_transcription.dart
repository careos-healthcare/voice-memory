import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/transcription/on_device_whisper_engine.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:flutter/foundation.dart';

/// Where a finished voice recording was transcribed.
enum OfflineTranscriptionRoute {
  /// On-device Whisper produced the transcript. The audio was not uploaded.
  local,

  /// Local Whisper did not run or did not produce text, so the existing
  /// cloud transcription call ran.
  cloud,

  /// Local Whisper did not produce text, and the cloud call was not allowed.
  unavailable,
}

class OfflineFirstTranscriptionResult {
  const OfflineFirstTranscriptionResult._({
    required this.route,
    this.transcript,
    this.cloudValue,
  });

  const OfflineFirstTranscriptionResult.local(String transcript)
    : this._(route: OfflineTranscriptionRoute.local, transcript: transcript);

  const OfflineFirstTranscriptionResult.cloud(Object? value)
    : this._(route: OfflineTranscriptionRoute.cloud, cloudValue: value);

  const OfflineFirstTranscriptionResult.unavailable()
    : this._(route: OfflineTranscriptionRoute.unavailable);

  final OfflineTranscriptionRoute route;
  final String? transcript;

  /// Whatever the injected cloud call returned. Production passes a
  /// `TranscriptionOutcome`.
  final Object? cloudValue;

  bool get usedLocalWhisper => route == OfflineTranscriptionRoute.local;
}

/// Transcribes a voice recording on-device first.
///
/// Hardware that cannot run Whisper, a missing model, or an empty local result
/// falls through to [transcribeInCloud] when [allowCloudFallback] is true.
/// "Never send to server" passes false and leaves the recording untranscribed
/// by this service rather than uploading it.
class OfflineFirstTranscriptionService {
  OfflineFirstTranscriptionService({
    this.hardwareSupported,
    this.modelReady,
    this.downloadModel,
    this.transcribeLocally,
    OnDeviceWhisperEngine? engine,
  }) : _engine = engine ?? OnDeviceWhisperEngine();

  /// When null, iOS and Android count as capable. Desktop tests do not.
  final Future<bool> Function()? hardwareSupported;

  /// When null, the iOS channel and sherpa weights on disk are checked.
  final Future<bool> Function()? modelReady;

  /// Downloads weights. Null means this build has no model URL, so a missing
  /// model is a local failure and the cloud endpoint is the next step.
  final Future<bool> Function()? downloadModel;

  final Future<String?> Function(File audioFile, ConfirmedSpeechLocale locale)?
  transcribeLocally;

  final OnDeviceWhisperEngine _engine;

  /// Local Whisper only. Null means the caller should use the cloud endpoint.
  Future<String?> attemptOnDevice({
    required File audioFile,
    required ConfirmedSpeechLocale? speechLocale,
    required void Function(PipelineStage stage) onStage,
  }) async {
    final result = await transcribe(
      audioFile: audioFile,
      speechLocale: speechLocale,
      onStage: onStage,
      allowCloudFallback: false,
      transcribeInCloud: () async => null,
    );
    return result.transcript;
  }

  Future<OfflineFirstTranscriptionResult> transcribe({
    required File audioFile,
    required ConfirmedSpeechLocale? speechLocale,
    required void Function(PipelineStage stage) onStage,
    required bool allowCloudFallback,
    required Future<Object?> Function() transcribeInCloud,
  }) async {
    if (!await _hardwareSupports()) {
      return _cloudOrUnavailable(allowCloudFallback, transcribeInCloud);
    }
    if (speechLocale == null || !audioFile.existsSync()) {
      return _cloudOrUnavailable(allowCloudFallback, transcribeInCloud);
    }

    final ready = await _modelIsReady();
    if (!ready) {
      final download = downloadModel;
      if (download == null) {
        return _cloudOrUnavailable(allowCloudFallback, transcribeInCloud);
      }
      onStage(PipelineStage.downloadingLocalModel);
      final installed = await download();
      if (!installed) {
        return _cloudOrUnavailable(allowCloudFallback, transcribeInCloud);
      }
    }

    onStage(PipelineStage.processingOnDevice);
    try {
      final local = transcribeLocally ?? _engine.transcribe;
      final text = await local(audioFile, speechLocale);
      final trimmed = text?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return OfflineFirstTranscriptionResult.local(trimmed);
      }
    } on Object {
      // A failed on-device pass is the cloud endpoint's cue.
    }
    return _cloudOrUnavailable(allowCloudFallback, transcribeInCloud);
  }

  Future<bool> _hardwareSupports() async {
    final override = hardwareSupported;
    if (override != null) return override();
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<bool> _modelIsReady() async {
    final override = modelReady;
    if (override != null) return override();
    if (await _engine.iosModelReady()) return true;
    return _engine.sherpaModelsPresent();
  }

  Future<OfflineFirstTranscriptionResult> _cloudOrUnavailable(
    bool allowCloudFallback,
    Future<Object?> Function() transcribeInCloud,
  ) async {
    if (!allowCloudFallback) {
      return const OfflineFirstTranscriptionResult.unavailable();
    }
    final value = await transcribeInCloud();
    return OfflineFirstTranscriptionResult.cloud(value);
  }
}
