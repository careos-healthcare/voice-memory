import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_conversation/graph_retrieval_tool.dart';
import 'package:voicememory_mobile/features/voice_conversation/realtime_session_config.dart';
import 'package:voicememory_mobile/features/voice_conversation/realtime_session_service.dart';
import 'package:voicememory_mobile/features/voice_conversation/realtime_voice_transport.dart';
import 'package:voicememory_mobile/features/voice_conversation/voice_conversation_audio.dart';
import 'package:voicememory_mobile/features/voice_conversation/voice_conversation_engine.dart';

void main() {
  test('executes query_memory_graph locally and returns tool output', () async {
    final transport = _FakeTransport();
    final graphTool = _FakeGraphTool();
    final engine = VoiceConversationEngine(
      sessionService: _FakeMinter(),
      transport: transport,
      capture: _FakeCapture(),
      playback: _FakePlayback(),
      graphTool: graphTool,
    );
    addTearDown(engine.dispose);

    await engine.start();
    transport.emit({
      'type': 'response.function_call_arguments.done',
      'name': 'query_memory_graph',
      'call_id': 'call-1',
      'arguments': '{"topic":"work","timeframe":"last 30 days"}',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(graphTool.arguments?['topic'], 'work');
    expect(
      transport.sent,
      contains(
        predicate<Map<String, dynamic>>(
          (event) =>
              event['type'] == 'conversation.item.create' &&
              (event['item'] as Map)['call_id'] == 'call-1' &&
              '${(event['item'] as Map)['output']}'.contains('local-result'),
        ),
      ),
    );
    expect(
      transport.sent,
      contains(
        predicate<Map<String, dynamic>>(
          (event) => event['type'] == 'response.create',
        ),
      ),
    );
    expect(engine.state.phase, VoiceConversationPhase.thinking);
  });

  test('streams microphone PCM directly to provider transport', () async {
    final capture = _FakeCapture();
    final transport = _FakeTransport();
    final engine = VoiceConversationEngine(
      sessionService: _FakeMinter(),
      transport: transport,
      capture: capture,
      playback: _FakePlayback(),
      graphTool: _FakeGraphTool(),
    );
    addTearDown(engine.dispose);

    await engine.start();
    capture.push([1, 0, 2, 0]);

    expect(transport.sent.single['type'], 'input_audio_buffer.append');
    expect(engine.state.micLevel, greaterThan(0));
  });
}

class _FakeMinter implements RealtimeSessionMinter {
  @override
  Future<RealtimeSessionConfig> mint() async => RealtimeSessionConfig(
    sessionId: 'session',
    clientSecret: 'ek_test',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    model: 'gpt-realtime',
    voice: 'marin',
    sampleRateHz: 24000,
    realtimeWebSocketUrl: Uri.parse(
      'wss://api.openai.com/v1/realtime?model=gpt-realtime',
    ),
  );
}

class _FakeTransport implements RealtimeVoiceTransport {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  void emit(Map<String, dynamic> event) => controller.add(event);

  @override
  Stream<Map<String, dynamic>> get events => controller.stream;

  @override
  Future<void> connect(RealtimeSessionConfig config) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void send(Map<String, dynamic> event) => sent.add(event);
}

class _FakeCapture implements VoiceConversationPcmCapture {
  void Function(List<int>)? callback;

  @override
  bool get isCapturing => callback != null;

  void push(List<int> bytes) => callback?.call(bytes);

  @override
  Future<void> start({required void Function(List<int>) onChunk}) async {
    callback = onChunk;
  }

  @override
  Future<void> stop() async => callback = null;

  @override
  void dispose() {}
}

class _FakePlayback implements VoiceConversationPlayback {
  @override
  Future<void> dispose() async {}

  @override
  void feed(List<int> pcmBytes) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> prepare() async {}

  @override
  Future<void> stop() async {}
}

class _FakeGraphTool implements MemoryGraphQueryTool {
  Map<String, dynamic>? arguments;

  @override
  Future<String> executeJson(Map<String, dynamic> arguments) async {
    this.arguments = arguments;
    return '{"nodes":["local-result"]}';
  }
}
