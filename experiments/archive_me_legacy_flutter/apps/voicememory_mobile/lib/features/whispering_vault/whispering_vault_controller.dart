import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../live_audio/domain/services/live_pcm_wav.dart';
import 'audio_graph_mapper.dart';
import 'audio_vault_storage.dart';
import 'local_whisper_service.dart';

enum WhisperingVaultState {
  idle,
  loadingModel,
  recording,
  transcribing,
  ready,
  error,
}

abstract interface class WhisperingVaultViewModel implements Listenable {
  WhisperingVaultState get state;
  String get transcript;
  String? get errorMessage;
  List<double> get waveform;
  AudioGraphMapping? get mapping;
  bool get isPlaying;
  double get playbackRate;
  Future<void> toggleRecording();
  Future<void> togglePlayback();
  Future<void> setPlaybackRate(double rate);
}

abstract interface class WhisperAudioCapture {
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

final class RecordWhisperAudioCapture implements WhisperAudioCapture {
  RecordWhisperAudioCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<Stream<Uint8List>> start() async {
    if (!await _recorder.hasPermission()) {
      throw const LocalWhisperException('Microphone permission is required.');
    }
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

final class WhisperingVaultController extends ChangeNotifier
    implements WhisperingVaultViewModel {
  WhisperingVaultController({
    required this.whisper,
    required this.storage,
    required this.mapper,
    WhisperAudioCapture? capture,
    AudioPlayer? player,
  }) : _capture = capture ?? RecordWhisperAudioCapture(),
       _player = player ?? AudioPlayer() {
    _subscriptions.add(
      _player.onPlayerStateChanged.listen((playerState) {
        isPlaying = playerState == PlayerState.playing;
        notifyListeners();
      }),
    );
  }

  final LocalWhisperService whisper;
  final AudioVaultStorage storage;
  final AudioGraphMapper mapper;
  final WhisperAudioCapture _capture;
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _transcriptionTimer;
  String? _recordId;
  bool _transcribingSnapshot = false;
  StreamSubscription<Uint8List>? _captureSubscription;
  BytesBuilder _pcm = BytesBuilder(copy: false);
  Future<void> _chunkWrites = Future<void>.value();
  int _chunkIndex = 0;

  @override
  WhisperingVaultState state = WhisperingVaultState.idle;
  @override
  String transcript = '';
  @override
  String? errorMessage;
  @override
  List<double> waveform = const [];
  @override
  AudioGraphMapping? mapping;
  @override
  bool isPlaying = false;
  @override
  double playbackRate = 1;

  @override
  Future<void> toggleRecording() =>
      state == WhisperingVaultState.recording ? stop() : start();

  Future<void> start() async {
    if (state == WhisperingVaultState.recording ||
        state == WhisperingVaultState.transcribing) {
      return;
    }
    state = WhisperingVaultState.loadingModel;
    errorMessage = null;
    transcript = '';
    mapping = null;
    waveform = const [];
    notifyListeners();
    try {
      if (!whisper.isLoaded) await whisper.loadModel();
      final record = await storage.beginStream();
      _recordId = record.id;
      _pcm = BytesBuilder(copy: false);
      _chunkIndex = 0;
      _chunkWrites = Future<void>.value();
      final stream = await _capture.start();
      _captureSubscription = stream.listen(
        _onAudioChunk,
        onError: (Object error, StackTrace stackTrace) => _fail(error),
        cancelOnError: true,
      );
      state = WhisperingVaultState.recording;
      notifyListeners();
      _transcriptionTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_transcribeSnapshot()),
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> stop() async {
    if (state != WhisperingVaultState.recording) return;
    _transcriptionTimer?.cancel();
    state = WhisperingVaultState.transcribing;
    notifyListeners();
    Uint8List? pcm;
    Uint8List? wav;
    try {
      await _captureSubscription?.cancel();
      _captureSubscription = null;
      await _capture.stop();
      await _chunkWrites;
      pcm = _pcm.takeBytes();
      wav = _wavFromPcm(pcm);
      final finalTranscript = await whisper.transcribeBuffer(wav);
      transcript = finalTranscript;
      final record = await storage.finalizeStream(
        id: _recordId!,
        wavBytes: wav,
        duration: Duration(milliseconds: (pcm.length / 32).round()),
      );
      await storage.saveTranscript(record.id, finalTranscript);
      mapping = await mapper.mapTranscript(
        audioId: record.id,
        transcript: finalTranscript,
        capturedAt: record.capturedAt,
      );
      state = WhisperingVaultState.ready;
      notifyListeners();
    } on Object catch (error) {
      _fail(error);
    } finally {
      if (pcm case final bytes?) {
        bytes.fillRange(0, bytes.length, 0);
      }
      if (wav case final bytes?) {
        bytes.fillRange(0, bytes.length, 0);
      }
      _pcm = BytesBuilder(copy: false);
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    if (state != WhisperingVaultState.recording || chunk.isEmpty) return;
    if (_pcm.length + chunk.length > AudioVaultStorage.maximumChunkBytes - 44) {
      _fail(
        const LocalWhisperException(
          'Recording reached the secure local size limit.',
        ),
      );
      return;
    }
    final copy = Uint8List.fromList(chunk);
    _pcm.add(copy);
    final index = _chunkIndex++;
    final recordId = _recordId!;
    _chunkWrites = _chunkWrites.then(
      (_) =>
          storage.appendStreamChunk(id: recordId, index: index, pcmBytes: copy),
    );
    var sum = 0.0;
    var samples = 0;
    final data = ByteData.sublistView(copy);
    for (var offset = 0; offset + 1 < copy.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little) / 32768;
      sum += sample * sample;
      samples++;
    }
    final rms = samples == 0 ? .02 : sqrt(sum / samples).clamp(.02, 1.0);
    waveform = [...waveform, rms];
    if (waveform.length > 72) {
      waveform = waveform.sublist(waveform.length - 72);
    }
    notifyListeners();
  }

  Future<void> _transcribeSnapshot() async {
    if (state != WhisperingVaultState.recording || _transcribingSnapshot) {
      return;
    }
    final pcm = _pcm.toBytes();
    if (pcm.length < 32000) {
      pcm.fillRange(0, pcm.length, 0);
      return;
    }
    _transcribingSnapshot = true;
    final wav = _wavFromPcm(pcm);
    try {
      final progressive = await whisper.transcribeBuffer(wav);
      if (state == WhisperingVaultState.recording &&
          progressive.trim().isNotEmpty) {
        transcript = progressive.trim();
        notifyListeners();
      }
    } on Object {
      // A partial WAV can be between header updates. Final transcription still
      // runs over the completed file after stop.
    } finally {
      pcm.fillRange(0, pcm.length, 0);
      wav.fillRange(0, wav.length, 0);
      _transcribingSnapshot = false;
    }
  }

  @override
  Future<void> togglePlayback() async {
    final id = _recordId;
    if (id == null) return;
    if (isPlaying) {
      await _player.pause();
      return;
    }
    if (_player.state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    final bytes = await storage.audio(id);
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlaybackRate(playbackRate);
      await _player.play(BytesSource(bytes));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    if (![1.0, 1.5, 2.0].contains(rate)) {
      throw ArgumentError.value(rate, 'rate');
    }
    playbackRate = rate;
    await _player.setPlaybackRate(rate);
    notifyListeners();
  }

  Uint8List _wavFromPcm(Uint8List pcm) =>
      wrapPcm16LeMonoInWav(pcm, sampleRateHz: 16000);

  void _fail(Object error) {
    _transcriptionTimer?.cancel();
    if (state == WhisperingVaultState.recording) {
      unawaited(_captureSubscription?.cancel());
      _captureSubscription = null;
      unawaited(_capture.stop());
    }
    state = WhisperingVaultState.error;
    errorMessage = error is LocalWhisperException
        ? error.message
        : 'The offline recording could not be processed.';
    notifyListeners();
  }

  @override
  void dispose() {
    _transcriptionTimer?.cancel();
    unawaited(_captureSubscription?.cancel());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final residualPcm = _pcm.takeBytes();
    residualPcm.fillRange(0, residualPcm.length, 0);
    unawaited(_capture.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }
}
