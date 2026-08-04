import 'dart:async';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../voice_capture/audio/capture_audio_session.dart';
import '../../voice_capture/microphone_permission_gateway.dart';
import '../domain/services/live_pcm16_capture_source.dart';
import '../live_audio_constants.dart';
import 'live_audio_pipeline_log.dart';

/// Microphone PCM capture via the `record` package — 16-bit LE mono @ 16 kHz.
class RecordLivePcm16CaptureSource implements LivePcm16CaptureSource {
  RecordLivePcm16CaptureSource({
    this._recorder,
    MicrophonePermissionGateway? permissionGateway,
    bool? configureCaptureSession,
    @Deprecated('Use configureCaptureSession instead.')
    bool? configureIosAudioSession,
  }) : _permissionGateway =
           permissionGateway ?? PermissionHandlerMicrophoneGateway(),
       configureCaptureSession =
           configureCaptureSession ?? configureIosAudioSession ?? true;

  final AudioRecorder? _recorder;
  final MicrophonePermissionGateway _permissionGateway;
  final bool configureCaptureSession;

  AudioRecorder? _activeRecorder;
  StreamSubscription<Uint8List>? _chunkSubscription;
  var _capturing = false;

  static RecordConfig get captureConfig => const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: liveInputSampleRateHz,
    numChannels: liveInputNumChannels,
  );

  @override
  bool get isCapturing => _capturing;

  AudioRecorder get _recorderInstance =>
      _activeRecorder ??= _recorder ?? AudioRecorder();

  @override
  Future<void> start({required void Function(List<int> chunk) onChunk}) async {
    if (_capturing) {
      throw StateError('Live PCM capture is already active');
    }

    await _ensureMicrophonePermission();

    final recorder = _recorderInstance;
    if (configureCaptureSession) {
      await CaptureAudioSessionConfigurator.configureForCapture(recorder);
    }

    final stream = await recorder.startStream(captureConfig);
    _capturing = true;
    LiveAudioPipelineLog.captureStarted(
      sampleRateHz: liveInputSampleRateHz,
      numChannels: liveInputNumChannels,
    );

    _chunkSubscription = stream.listen(
      (chunk) => onChunk(chunk),
      onError: (Object error, StackTrace stackTrace) {
        LiveAudioPipelineLog.failure('pcm_capture_stream', error);
        Error.throwWithStackTrace(
          LivePcm16CaptureException('Microphone stream failed.'),
          stackTrace,
        );
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> stop() async {
    if (!_capturing) return;

    await _chunkSubscription?.cancel();
    _chunkSubscription = null;

    try {
      await _recorderInstance.cancel();
    } catch (error) {
      LiveAudioPipelineLog.failure('pcm_capture_stop', error);
    }

    _capturing = false;
    LiveAudioPipelineLog.captureStopped();
  }

  @override
  void dispose() {
    unawaited(stop());
    _activeRecorder?.dispose();
    _activeRecorder = null;
  }

  Future<void> _ensureMicrophonePermission() async {
    final recorder = _recorderInstance;
    if (await recorder.hasPermission()) {
      return;
    }

    final status = await _permissionGateway.status;
    if (status.isGranted || await recorder.hasPermission()) {
      return;
    }

    final requested = await _permissionGateway.request();
    if (requested.isGranted || await recorder.hasPermission(request: true)) {
      return;
    }

    throw LivePcm16CaptureException(
      'Microphone permission is required for live audio.',
    );
  }
}
