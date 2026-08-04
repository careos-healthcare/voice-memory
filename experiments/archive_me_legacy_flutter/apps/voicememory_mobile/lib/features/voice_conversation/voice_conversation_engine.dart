import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../live_audio/infrastructure/live_pcm24_playback_engine.dart';
import 'conversation_ingestion_task.dart';
import 'graph_retrieval_tool.dart';
import 'realtime_session_service.dart';
import 'realtime_voice_transport.dart';
import 'voice_conversation_audio.dart';

enum VoiceConversationPhase {
  disconnected,
  connecting,
  listening,
  thinking,
  searchingGraph,
  speaking,
  ending,
  permissionDenied,
  error,
}

class VoiceConversationState {
  const VoiceConversationState({
    this.phase = VoiceConversationPhase.disconnected,
    this.transcript = const [],
    this.partialAssistantText = '',
    this.micLevel = 0,
    this.outputLevel = 0,
    this.errorMessage,
  });

  final VoiceConversationPhase phase;
  final List<VoiceConversationTranscriptLine> transcript;
  final String partialAssistantText;
  final double micLevel;
  final double outputLevel;
  final String? errorMessage;

  VoiceConversationState copyWith({
    VoiceConversationPhase? phase,
    List<VoiceConversationTranscriptLine>? transcript,
    String? partialAssistantText,
    double? micLevel,
    double? outputLevel,
    String? errorMessage,
    bool clearError = false,
  }) => VoiceConversationState(
    phase: phase ?? this.phase,
    transcript: transcript ?? this.transcript,
    partialAssistantText: partialAssistantText ?? this.partialAssistantText,
    micLevel: micLevel ?? this.micLevel,
    outputLevel: outputLevel ?? this.outputLevel,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

abstract interface class VoiceConversationPlayback {
  Future<void> prepare();
  void feed(List<int> pcmBytes);
  Future<void> flush();
  Future<void> stop();
  Future<void> dispose();
}

class Pcm24VoiceConversationPlayback implements VoiceConversationPlayback {
  Pcm24VoiceConversationPlayback({LivePcm24PlaybackEngine? engine})
    : _engine = engine ?? LivePcm24PlaybackEngine();

  final LivePcm24PlaybackEngine _engine;

  @override
  Future<void> prepare() => _engine.prepare();

  @override
  void feed(List<int> pcmBytes) => _engine.feed(pcmBytes);

  @override
  Future<void> flush() => _engine.flush();

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> dispose() => _engine.dispose();
}

abstract interface class VoiceConversationController {
  VoiceConversationState get state;
  Stream<VoiceConversationState> get states;
  Future<void> start();
  Future<ConversationIngestionResult?> stop({bool ingest = true});
}

class VoiceConversationEngine implements VoiceConversationController {
  VoiceConversationEngine({
    required this.sessionService,
    required this.transport,
    required this.capture,
    required this.playback,
    required this.graphTool,
    this.ingestionTask,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RealtimeSessionMinter sessionService;
  final RealtimeVoiceTransport transport;
  final VoiceConversationPcmCapture capture;
  final VoiceConversationPlayback playback;
  final MemoryGraphQueryTool graphTool;
  final ConversationIngestionTask? ingestionTask;
  final DateTime Function() _clock;
  final _states = StreamController<VoiceConversationState>.broadcast();
  VoiceConversationState _state = const VoiceConversationState();
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  DateTime? _startedAt;
  var _stopping = false;

  @override
  VoiceConversationState get state => _state;
  @override
  Stream<VoiceConversationState> get states => _states.stream;

  @override
  Future<void> start() async {
    if (_state.phase != VoiceConversationPhase.disconnected &&
        _state.phase != VoiceConversationPhase.error &&
        _state.phase != VoiceConversationPhase.permissionDenied) {
      return;
    }
    _stopping = false;
    _emit(
      const VoiceConversationState(phase: VoiceConversationPhase.connecting),
    );
    try {
      final config = await sessionService.mint();
      _eventSubscription = transport.events.listen(
        (event) => unawaited(_handleEvent(event)),
        onError: (Object _) =>
            _fail('The realtime voice connection was interrupted.'),
      );
      await transport.connect(config);
      await playback.prepare();
      await capture.start(onChunk: _sendAudio);
      _startedAt = _clock().toUtc();
      _emit(_state.copyWith(phase: VoiceConversationPhase.listening));
    } on MicrophonePermissionDeniedException {
      await transport.disconnect();
      _emit(
        _state.copyWith(
          phase: VoiceConversationPhase.permissionDenied,
          errorMessage: 'Microphone permission is required to talk.',
        ),
      );
    } on Object {
      await capture.stop();
      await transport.disconnect();
      _fail('Voice conversation could not start. Please try again.');
    }
  }

  @override
  Future<ConversationIngestionResult?> stop({bool ingest = true}) async {
    if (_stopping) return null;
    _stopping = true;
    _emit(_state.copyWith(phase: VoiceConversationPhase.ending));
    await capture.stop();
    await playback.stop();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await transport.disconnect();
    ConversationIngestionResult? result;
    final startedAt = _startedAt;
    if (ingest && startedAt != null && ingestionTask != null) {
      result = await ingestionTask!.run(
        transcript: _state.transcript,
        duration: _clock().toUtc().difference(startedAt),
      );
    }
    _startedAt = null;
    _emit(
      VoiceConversationState(
        phase: VoiceConversationPhase.disconnected,
        transcript: _state.transcript,
      ),
    );
    return result;
  }

  void _sendAudio(List<int> chunk) {
    if (chunk.isEmpty || _stopping) return;
    _emit(_state.copyWith(micLevel: _pcmLevel(chunk)));
    try {
      transport.send({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(chunk),
      });
    } on Object {
      _fail('The microphone stream was disconnected.');
    }
  }

  Future<void> _handleEvent(Map<String, dynamic> event) async {
    if (_stopping) return;
    final type = event['type'] as String? ?? '';
    switch (type) {
      case 'input_audio_buffer.speech_started':
        await playback.flush();
        _emit(_state.copyWith(phase: VoiceConversationPhase.listening));
        return;
      case 'input_audio_buffer.speech_stopped':
        _emit(_state.copyWith(phase: VoiceConversationPhase.thinking));
        return;
      case 'conversation.item.input_audio_transcription.completed':
        _appendTranscript(
          VoiceConversationRole.user,
          event['transcript'] as String? ?? '',
        );
        return;
      case 'response.output_audio.delta':
      case 'response.audio.delta':
        final encoded = event['delta'] as String? ?? '';
        if (encoded.isNotEmpty) {
          final bytes = base64Decode(encoded);
          playback.feed(bytes);
          _emit(
            _state.copyWith(
              phase: VoiceConversationPhase.speaking,
              outputLevel: _pcmLevel(bytes),
            ),
          );
        }
        return;
      case 'response.output_audio_transcript.delta':
      case 'response.audio_transcript.delta':
        final delta = event['delta'] as String? ?? '';
        _emit(
          _state.copyWith(
            partialAssistantText: '${_state.partialAssistantText}$delta',
          ),
        );
        return;
      case 'response.output_audio_transcript.done':
      case 'response.audio_transcript.done':
        final text =
            event['transcript'] as String? ?? _state.partialAssistantText;
        _appendTranscript(VoiceConversationRole.assistant, text);
        _emit(_state.copyWith(partialAssistantText: ''));
        return;
      case 'response.function_call_arguments.done':
        await _executeTool(event);
        return;
      case 'response.done':
        _emit(
          _state.copyWith(
            phase: VoiceConversationPhase.listening,
            outputLevel: 0,
          ),
        );
        return;
      case 'transport.disconnected':
        if (!_stopping) {
          _fail('The realtime voice connection ended.');
        }
        return;
      case 'error':
        _fail('The realtime AI provider reported a session error.');
        return;
      default:
        return;
    }
  }

  Future<void> _executeTool(Map<String, dynamic> event) async {
    if (event['name'] != 'query_memory_graph') {
      _sendToolOutput(event, jsonEncode({'error': 'Unsupported local tool.'}));
      return;
    }
    _emit(_state.copyWith(phase: VoiceConversationPhase.searchingGraph));
    String output;
    try {
      final raw = event['arguments'] as String? ?? '{}';
      final decoded = jsonDecode(raw);
      output = await graphTool.executeJson(
        decoded is Map ? Map<String, dynamic>.from(decoded) : const {},
      );
    } on Object {
      output = jsonEncode({
        'error': 'The local Memory Graph query could not be completed.',
      });
    }
    _sendToolOutput(event, output);
    transport.send(const {'type': 'response.create'});
    _emit(_state.copyWith(phase: VoiceConversationPhase.thinking));
  }

  void _sendToolOutput(Map<String, dynamic> event, String output) {
    transport.send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': event['call_id'],
        'output': output,
      },
    });
  }

  void _appendTranscript(VoiceConversationRole role, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _emit(
      _state.copyWith(
        transcript: [
          ..._state.transcript,
          VoiceConversationTranscriptLine(
            role: role,
            text: trimmed,
            createdAt: _clock().toUtc(),
          ),
        ],
      ),
    );
  }

  void _fail(String message) {
    if (_stopping) return;
    _emit(
      _state.copyWith(
        phase: VoiceConversationPhase.error,
        errorMessage: message,
      ),
    );
  }

  void _emit(VoiceConversationState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> dispose() async {
    await stop(ingest: false);
    capture.dispose();
    await playback.dispose();
    await _states.close();
  }
}

double _pcmLevel(List<int> bytes) {
  if (bytes.length < 2) return 0;
  var sum = 0.0;
  var samples = 0;
  for (var index = 0; index + 1 < bytes.length; index += 2) {
    final unsigned = bytes[index] | (bytes[index + 1] << 8);
    final signed = unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
    final normalized = signed / 32768.0;
    sum += normalized * normalized;
    samples++;
  }
  if (samples == 0) return 0;
  return (math.sqrt(sum / samples) * 3).clamp(0, 1);
}
