import 'package:archiveme_mobile/features/capture_flow/live_voice_session.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses on-device speech when the phone can stream it', () {
    expect(
      resolveLiveStt(onDeviceStreaming: true),
      LiveSttRoute.onDevice,
    );
    expect(
      resolveLiveStt(onDeviceStreaming: false),
      LiveSttRoute.offline,
    );
  });

  test('silence after speech keeps the user line and asks for no reply', () async {
    var now = DateTime.utc(2026, 9, 25, 12);
    final session = LiveVoiceSession(clock: () => now);
    session.notePartial('the deadline moved');
    session.noteLevel(-20);
    session.noteLevel(-50);
    now = now.add(const Duration(milliseconds: 900));
    session.noteLevel(-50);
    await Future<void>.delayed(Duration.zero);
    expect(session.turns, hasLength(1));
    expect(session.turns.single.text, 'the deadline moved');
    expect(session.turns.single.partial, isFalse);
    await session.close();
    session.notePartial('after close');
    expect(session.closed, isTrue);
    expect(session.turns.where((turn) => turn.text == 'after close'), isEmpty);
  });

  testWidgets('the recording screen shows one dictation transcript', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureRecordingPanel(
            duration: const Duration(seconds: 4),
            levels: const [0.2, 0.8],
            turns: const [
              LiveConversationTurn(text: 'I kept circling it'),
            ],
            onStop: () {},
            onCancel: () {},
            onPause: () {},
            onResume: () {},
          ),
        ),
      ),
    );
    expect(find.text('I kept circling it'), findsOneWidget);
    expect(find.byKey(const Key('capture_level_meter')), findsOneWidget);
    expect(find.text('What stood out?'), findsNothing);
    expect(find.text('Whisper'), findsNothing);
  });
}
