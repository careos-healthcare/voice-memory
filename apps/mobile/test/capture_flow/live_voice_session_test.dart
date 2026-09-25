import 'package:archiveme_mobile/features/capture_flow/live_voice_session.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses on-device speech when the phone can stream it', () {
    expect(
      resolveLiveStt(onDeviceStreaming: true, online: false),
      LiveSttRoute.onDevice,
    );
    expect(
      resolveLiveStt(onDeviceStreaming: false, online: true),
      LiveSttRoute.whisper,
    );
    expect(
      resolveLiveStt(onDeviceStreaming: false, online: false),
      LiveSttRoute.offline,
    );
  });

  test('silence after speech asks for an assistant reply', () async {
    var now = DateTime.utc(2026, 9, 25, 12);
    String? heard;
    final session = LiveVoiceSession(
      clock: () => now,
      respond: (utterance, history) async {
        heard = utterance;
        return 'What stood out?';
      },
    );
    session.notePartial('the deadline moved');
    session.noteLevel(-20);
    session.noteLevel(-50);
    now = now.add(const Duration(milliseconds: 900));
    session.noteLevel(-50);
    await Future<void>.delayed(Duration.zero);
    expect(heard, 'the deadline moved');
    expect(session.turns.last.role, LiveTurnRole.assistant);
    expect(session.turns.last.text, 'What stood out?');
    await session.close();
    session.notePartial('after close');
    expect(session.closed, isTrue);
    expect(session.turns.where((turn) => turn.text == 'after close'), isEmpty);
  });

  testWidgets('bubbles keep the user and the assistant apart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureRecordingPanel(
            duration: const Duration(seconds: 4),
            levels: const [0.2, 0.8],
            turns: const [
              LiveConversationTurn(role: LiveTurnRole.user, text: 'I kept circling it'),
              LiveConversationTurn(role: LiveTurnRole.assistant, text: 'What stood out?'),
            ],
            sttRoute: LiveSttRoute.onDevice,
            onStop: () {},
            onCancel: () {},
            onPause: () {},
            onResume: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('capture_user_turn_0')), findsOneWidget);
    expect(find.byKey(const Key('capture_assistant_turn_1')), findsOneWidget);
    expect(find.byKey(const Key('capture_level_meter')), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
  });
}
