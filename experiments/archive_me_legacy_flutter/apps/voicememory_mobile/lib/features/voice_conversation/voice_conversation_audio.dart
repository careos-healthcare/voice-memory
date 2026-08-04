import 'dart:async';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../features/voice_capture/audio/capture_audio_session.dart';
import '../../features/voice_capture/microphone_permission_gateway.dart';

abstract interface class VoiceConversationPcmCapture {
  bool get isCapturing;
  Future<void> start({required void Function(List<int>) onChunk});
  Future<void> stop();
  void dispose();
}

class RecordVoiceConversationPcmCapture implements VoiceConversationPcmCapture {
  RecordVoiceConversationPcmCapture({
    AudioRecorder? recorder,
    MicrophonePermissionGateway? permissionGateway,
  }) : _recorder = recorder ?? AudioRecorder(),
       _permission = permissionGateway ?? PermissionHandlerMicrophoneGateway();

  static const sampleRateHz = 24000;
  final AudioRecorder _recorder;
  final MicrophonePermissionGateway _permission;
  StreamSubscription<Uint8List>? _subscription;

  @override
  bool get isCapturing => _subscription != null;

  @override
  Future<void> start({required void Function(List<int>) onChunk}) async {
    final status = await _permission.request();
    final recorderPermission = await _permission.recorderPermission(
      request: true,
    );
    if (!status.isGranted || recorderPermission == false) {
      throw const MicrophonePermissionDeniedException();
    }
    await CaptureAudioSessionConfigurator.configureForCapture(_recorder);
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRateHz,
        numChannels: 1,
        autoGain: false,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _subscription = stream.listen((chunk) => onChunk(chunk));
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.cancel();
    } on Object {
      // Recorder may already be stopped after an interruption.
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    unawaited(_recorder.dispose());
  }
}

class MicrophonePermissionDeniedException implements Exception {
  const MicrophonePermissionDeniedException();

  @override
  String toString() => 'Microphone permission is required.';
}
