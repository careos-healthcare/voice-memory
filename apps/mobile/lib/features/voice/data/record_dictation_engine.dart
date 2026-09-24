import 'dart:async';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/voice/presentation/dictation_mic_bar.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:record/record.dart';

/// Microphone levels plus partial text from [partials].
///
/// [speech] is the live recognizer binding (on-device Whisper chunks or a
/// socket). A denied microphone permission ends the session quietly.
class RecordDictationEngine implements DictationEngine {
  RecordDictationEngine({
    AudioRecorder? recorder,
    Stream<String>? speech,
  }) : _recorder = recorder,
       _speech = speech;

  final AudioRecorder? _recorder;
  final Stream<String>? _speech;
  final _partials = StreamController<String>.broadcast();
  final _levels = StreamController<double>.broadcast();
  AudioRecorder? _active;
  StreamSubscription<Amplitude>? _amplitude;
  StreamSubscription<Uint8List>? _frames;
  StreamSubscription<String>? _speechSub;

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  AudioRecorder get _mic => _active ??= _recorder ?? AudioRecorder();

  @override
  Future<void> start() async {
    _speechSub = _speech?.listen(_partials.add);
    final mic = _mic;
    final allowed = await mic.hasPermission();
    if (!allowed) return;
    await IosAudioSessionConfigurator.configureForCapture(mic);
    final stream = await mic.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _amplitude = mic
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amplitude) {
          if (_levels.isClosed) return;
          _levels.add(_normalizeDb(amplitude.current));
        });
    _frames = stream.listen((_) {});
  }

  @override
  Future<void> stop() async {
    await _speechSub?.cancel();
    await _amplitude?.cancel();
    await _frames?.cancel();
    _speechSub = null;
    _amplitude = null;
    _frames = null;
    final mic = _active;
    if (mic != null && await mic.isRecording()) {
      await mic.stop();
    }
  }

  void addPartial(String text) {
    if (!_partials.isClosed) _partials.add(text);
  }
}

double _normalizeDb(double db) {
  final clamped = db.clamp(-60, 0);
  return ((clamped + 60) / 60).toDouble();
}
