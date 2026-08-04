import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_conversation/conversation_ingestion_task.dart';
import 'package:voicememory_mobile/features/voice_conversation/conversational_orb_overlay.dart';
import 'package:voicememory_mobile/features/voice_conversation/voice_conversation_engine.dart';

void main() {
  testWidgets('renders listening, thinking, speaking and graph search states', (
    tester,
  ) async {
    _useTallViewport(tester);
    final controller = _FakeConversationController();
    await tester.pumpWidget(_harness(controller));

    controller.emit(
      const VoiceConversationState(
        phase: VoiceConversationPhase.listening,
        micLevel: .7,
      ),
    );
    await tester.pump();
    expect(find.text('Listening'), findsOneWidget);
    expect(
      find.byKey(const Key('conversational_orb_visualizer')),
      findsOneWidget,
    );

    controller.emit(
      const VoiceConversationState(phase: VoiceConversationPhase.thinking),
    );
    await tester.pump();
    expect(find.text('Thinking'), findsOneWidget);

    controller.emit(
      const VoiceConversationState(
        phase: VoiceConversationPhase.searchingGraph,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('conversational_orb_searching_graph_badge')),
      findsOneWidget,
    );

    controller.emit(
      VoiceConversationState(
        phase: VoiceConversationPhase.speaking,
        outputLevel: .8,
        transcript: [
          VoiceConversationTranscriptLine(
            role: VoiceConversationRole.user,
            text: 'What has changed about work?',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('ArchiveMe is speaking'), findsOneWidget);
    expect(
      find.textContaining('What has changed about work?', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('handles microphone denial and graceful disconnect', (
    tester,
  ) async {
    _useTallViewport(tester);
    final controller = _FakeConversationController(
      const VoiceConversationState(
        phase: VoiceConversationPhase.permissionDenied,
        errorMessage: 'Microphone permission is required to talk.',
      ),
    );
    var closed = false;
    await tester.pumpWidget(
      _harness(controller, onClosed: () => closed = true),
    );

    expect(
      find.byKey(const Key('voice-conversation-open-settings')),
      findsOneWidget,
    );
    expect(
      find.text('Microphone permission is required to talk.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('conversational_orb_end_button')));
    await tester.pump();

    expect(controller.stopCalls, 1);
    expect(closed, isTrue);
  });
}

void _useTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _harness(
  VoiceConversationController controller, {
  VoidCallback? onClosed,
}) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(
            key: Key('memory_graph_background'),
            color: Color(0xFFEFF2F8),
          ),
        ),
        ConversationalOrbOverlay(
          controller: controller,
          onClosed: onClosed ?? () {},
          startAutomatically: false,
        ),
      ],
    ),
  ),
);

class _FakeConversationController implements VoiceConversationController {
  _FakeConversationController([this._state = const VoiceConversationState()]);

  final _states = StreamController<VoiceConversationState>.broadcast();
  VoiceConversationState _state;
  int stopCalls = 0;

  @override
  VoiceConversationState get state => _state;

  @override
  Stream<VoiceConversationState> get states => _states.stream;

  void emit(VoiceConversationState value) {
    _state = value;
    _states.add(value);
  }

  @override
  Future<void> start() async {}

  @override
  Future<ConversationIngestionResult?> stop({bool ingest = true}) async {
    stopCalls++;
    emit(
      VoiceConversationState(
        phase: VoiceConversationPhase.disconnected,
        transcript: _state.transcript,
      ),
    );
    return null;
  }
}
