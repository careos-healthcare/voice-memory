import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One inbound packet from the live voice socket.
class VoicePacket {
  const VoicePacket({this.partial, this.outputLevel = 0});

  final String? partial;
  final double outputLevel;
}

/// A selected microphone, speaker, or headset.
class VoiceAudioDevice {
  const VoiceAudioDevice({required this.id, required this.label});

  final String id;
  final String label;

  bool get isBluetooth => label.toLowerCase().contains('bluetooth');
  bool get isSpeaker => label.toLowerCase().contains('speaker');
}

/// Sends PCM frames and receives partial text plus playback level.
abstract class VoiceByteTransport {
  Future<void> connect();
  Future<void> sendPcm(Uint8List frame);
  Stream<VoicePacket> get incoming;
  Future<void> close();
  bool get isConnected;

  /// Time from the latest outbound frame to the matching reply.
  Duration? get lastTurnaround;
}

/// Local socket stand-in. Replies on the same turn so the round trip stays
/// well under 500ms when no remote endpoint is configured.
class LoopbackVoiceTransport implements VoiceByteTransport {
  final _incoming = StreamController<VoicePacket>.broadcast();
  var _connected = false;
  Duration? _lastTurnaround;

  @override
  Duration? get lastTurnaround => _lastTurnaround;

  @override
  bool get isConnected => _connected;

  @override
  Stream<VoicePacket> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> sendPcm(Uint8List frame) async {
    if (!_connected) return;
    final started = DateTime.now();
    final level = _rms(frame);
    _lastTurnaround = DateTime.now().difference(started);
    if (!_incoming.isClosed) {
      _incoming.add(VoicePacket(outputLevel: level, partial: null));
    }
  }

  @override
  Future<void> close() async {
    _connected = false;
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }
}

/// WebSocket PCM client. Binary frames go out immediately; text frames carry
/// partial transcripts and an optional playback level.
class WebSocketVoiceTransport implements VoiceByteTransport {
  WebSocketVoiceTransport(
    this.uri, {
    WebSocketChannel Function(Uri uri)? open,
  }) : _open = open ?? WebSocketChannel.connect;

  final Uri uri;
  final WebSocketChannel Function(Uri uri) _open;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _incoming = StreamController<VoicePacket>.broadcast();
  var _connected = false;
  DateTime? _sentAt;
  Duration? _lastTurnaround;

  @override
  Duration? get lastTurnaround => _lastTurnaround;

  @override
  bool get isConnected => _connected;

  @override
  Stream<VoicePacket> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    final channel = _open(uri);
    _channel = channel;
    _connected = true;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) {},
      onDone: () => _connected = false,
    );
  }

  @override
  Future<void> sendPcm(Uint8List frame) async {
    if (!_connected) return;
    _sentAt = DateTime.now();
    _channel?.sink.add(frame);
  }

  @override
  Future<void> close() async {
    _connected = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _incoming.close();
  }

  void _onMessage(dynamic message) {
    final sentAt = _sentAt;
    if (sentAt != null) {
      _lastTurnaround = DateTime.now().difference(sentAt);
    }
    if (message is! String) {
      if (message is List<int>) {
        _incoming.add(
          VoicePacket(outputLevel: _rms(Uint8List.fromList(message))),
        );
      }
      return;
    }
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) return;
    final partial = decoded['partial'];
    final level = decoded['outputLevel'];
    _incoming.add(
      VoicePacket(
        partial: partial is String ? partial : null,
        outputLevel: level is num ? level.toDouble().clamp(0, 1).toDouble() : 0,
      ),
    );
  }
}

/// Microphone capture that can move to a new input without closing the socket.
abstract class VoiceCapturePort {
  Future<void> start(void Function(Uint8List frame, double level) onFrame);
  Future<void> rebind(VoiceAudioDevice device);
  Future<void> stop();
}

class RecordVoiceCapture implements VoiceCapturePort {
  RecordVoiceCapture({AudioRecorder? recorder}) : _recorder = recorder;

  final AudioRecorder? _recorder;
  AudioRecorder? _active;
  StreamSubscription<Uint8List>? _frames;
  StreamSubscription<Amplitude>? _levels;
  void Function(Uint8List frame, double level)? _onFrame;
  double _level = 0;
  VoiceAudioDevice? _device;

  AudioRecorder get _mic => _active ??= _recorder ?? AudioRecorder();

  @override
  Future<void> start(
    void Function(Uint8List frame, double level) onFrame,
  ) async {
    _onFrame = onFrame;
    await _open();
  }

  @override
  Future<void> rebind(VoiceAudioDevice device) async {
    _device = device;
    await _frames?.cancel();
    await _levels?.cancel();
    final mic = _mic;
    if (await mic.isRecording()) {
      await mic.stop();
    }
    await _open();
  }

  @override
  Future<void> stop() async {
    await _frames?.cancel();
    await _levels?.cancel();
    _frames = null;
    _levels = null;
    final mic = _active;
    if (mic != null && await mic.isRecording()) {
      await mic.stop();
    }
  }

  Future<void> _open() async {
    final mic = _mic;
    final allowed = await mic.hasPermission();
    if (!allowed) return;
    await IosAudioSessionConfigurator.configureForCapture(mic);
    final devices = await mic.listInputDevices();
    final selected = _match(devices, _device);
    final stream = await mic.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: selected,
      ),
    );
    _levels = mic.onAmplitudeChanged(const Duration(milliseconds: 50)).listen((
      amplitude,
    ) {
      _level = _normalizeDb(amplitude.current);
    });
    _frames = stream.listen((frame) {
      _onFrame?.call(frame, _level);
    });
  }

  InputDevice? _match(List<InputDevice> devices, VoiceAudioDevice? wanted) {
    if (wanted == null) return null;
    for (final device in devices) {
      if (device.id == wanted.id || device.label == wanted.label) {
        return device;
      }
    }
    return null;
  }
}

class ManualVoiceCapture implements VoiceCapturePort {
  void Function(Uint8List frame, double level)? onFrame;
  var rebindCount = 0;
  var started = false;

  @override
  Future<void> start(
    void Function(Uint8List frame, double level) onFrame,
  ) async {
    this.onFrame = onFrame;
    started = true;
  }

  @override
  Future<void> rebind(VoiceAudioDevice device) async {
    rebindCount += 1;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  void emit(Uint8List frame, double level) => onFrame?.call(frame, level);
}

/// Watches input devices. A headset change emits a new [VoiceAudioDevice].
class VoiceRouteWatch {
  VoiceRouteWatch(this._poll, {this.interval = const Duration(seconds: 1)});

  final Future<List<VoiceAudioDevice>> Function() _poll;
  final Duration interval;

  Stream<VoiceAudioDevice> watch() async* {
    String? lastId;
    while (true) {
      try {
        final devices = await _poll();
        if (devices.isNotEmpty && devices.first.id != lastId) {
          lastId = devices.first.id;
          yield devices.first;
        }
      } on Object {
        // A denied permission or a missing device list keeps the socket up.
      }
      await Future<void>.delayed(interval);
    }
  }
}

/// Hands-free call. Audio route changes rebind the mic and leave the socket open.
class VoiceCallService {
  VoiceCallService({
    required VoiceByteTransport transport,
    required VoiceCapturePort capture,
    Stream<VoiceAudioDevice>? routes,
  }) : _transport = transport,
       _capture = capture,
       _routes = routes;

  final VoiceByteTransport _transport;
  final VoiceCapturePort _capture;
  final Stream<VoiceAudioDevice>? _routes;

  final _input = StreamController<double>.broadcast();
  final _output = StreamController<double>.broadcast();
  final _partials = StreamController<String>.broadcast();
  final _transcript = StringBuffer();
  StreamSubscription<VoicePacket>? _packets;
  StreamSubscription<VoiceAudioDevice>? _routeSub;
  var _connected = false;

  Stream<double> get inputLevel => _input.stream;
  Stream<double> get outputLevel => _output.stream;
  Stream<String> get partials => _partials.stream;
  bool get isConnected => _connected && _transport.isConnected;
  Duration? get lastTurnaround => _transport.lastTurnaround;
  String get transcript => _transcript.toString().trim();

  Future<void> start() async {
    await _transport.connect();
    _connected = _transport.isConnected;
    _packets = _transport.incoming.listen(_onPacket);
    await _capture.start(_onFrame);
    _routeSub = _routes?.listen((device) async {
      try {
        await _capture.rebind(device);
      } on Object {
        // A headset swap must not close the socket.
      }
    });
  }

  Future<String> end() async {
    final text = transcript;
    _connected = false;
    final routes = _routeSub;
    final packets = _packets;
    _routeSub = null;
    _packets = null;
    unawaited(routes?.cancel());
    unawaited(packets?.cancel());
    try {
      await _capture.stop();
    } on Object {
      // The socket is already marked closed for the caller.
    }
    try {
      await _transport.close();
    } on Object {
      // A transport that is already shut down still returns the transcript.
    }
    return text;
  }

  void addLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    if (_transcript.isNotEmpty) _transcript.writeln();
    _transcript.write(trimmed);
    _partials.add(trimmed);
  }

  void _onFrame(Uint8List frame, double level) {
    if (!_input.isClosed) _input.add(level);
    unawaited(_transport.sendPcm(frame));
  }

  void _onPacket(VoicePacket packet) {
    if (!_output.isClosed) _output.add(packet.outputLevel);
    final partial = packet.partial?.trim();
    if (partial == null || partial.isEmpty) return;
    addLine(partial);
  }
}

double _rms(Uint8List frame) {
  if (frame.length < 2) return 0;
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i + 1 < frame.length; i += 2) {
    final sample = frame[i] | (frame[i + 1] << 8);
    final signed = sample > 32767 ? sample - 65536 : sample;
    sum += signed * signed;
    count += 1;
  }
  if (count == 0) return 0;
  final rms = (sum / count) / (32768 * 32768);
  if (rms < 0) return 0;
  if (rms > 1) return 1;
  return rms;
}

double _normalizeDb(double db) {
  final clamped = db.clamp(-60, 0);
  return ((clamped + 60) / 60).toDouble();
}
