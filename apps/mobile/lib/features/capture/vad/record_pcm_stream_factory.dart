import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:record/record.dart';

/// Opens a PCM16 mono sidecar stream via `record` for the VAD pipeline.
typedef RecordPcmStreamFactory =
    Future<Stream<Uint8List>> Function(
      AudioRecorder recorder,
      VadStreamConfig config,
    );

Future<Stream<Uint8List>> defaultRecordPcmStreamFactory(
  AudioRecorder recorder,
  VadStreamConfig config,
) async {
  await IosAudioSessionConfigurator.configureForCapture(recorder);
  return recorder.startStream(
    RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: config.sampleRateHz,
      numChannels: 1,
    ),
  );
}
