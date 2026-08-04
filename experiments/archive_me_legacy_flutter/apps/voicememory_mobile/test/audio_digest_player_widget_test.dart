import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/audio_digest_speaker.dart';
import 'package:voicememory_mobile/widgets/audio_digest_player_widget.dart';

class _FakeAudioDigestSpeaker implements AudioDigestSpeaker {
  VoidCallback? onStarted;
  VoidCallback? onCompleted;
  ValueChanged<String>? onError;
  String? spokenNarrative;
  var stopCount = 0;

  @override
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    this.onStarted = onStarted;
    this.onCompleted = onCompleted;
    this.onError = onError;
  }

  @override
  Future<void> speak(String narrative) async {
    spokenNarrative = narrative;
    onStarted?.call();
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    onCompleted?.call();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('plays and stops the supplied private digest narrative', (
    tester,
  ) async {
    final speaker = _FakeAudioDigestSpeaker();
    const narrative = 'Weekly Audio Retrospective. Five moments were saved.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDigestPlayerWidget(narrative: narrative, speaker: speaker),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Weekly Audio Retrospective'), findsOneWidget);
    expect(find.text('Play retrospective'), findsOneWidget);

    await tester.tap(find.byKey(const Key('audio_digest_play_button')));
    await tester.pump();

    expect(speaker.spokenNarrative, narrative);
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('audio_digest_play_button')));
    await tester.pump();

    expect(speaker.stopCount, 1);
    expect(find.text('Play retrospective'), findsOneWidget);
  });
}
