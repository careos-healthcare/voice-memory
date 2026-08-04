import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/morning_briefing/morning_briefing_audio.dart';
import 'package:voicememory_mobile/features/morning_briefing/morning_briefing_models.dart';
import 'package:voicememory_mobile/features/morning_briefing/ui/morning_briefing_sheet.dart';

void main() {
  testWidgets('plays narration and focuses the highlighted graph node', (
    tester,
  ) async {
    final audio = _FakeAudioController();
    String? focused;
    String? jumped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MorningBriefingSheet(
            briefing: _briefing(),
            loadAudio: () async => Uint8List.fromList([1, 2, 3]),
            audioController: audio,
            onStartDayFocus: (target) => focused = target,
            onSnooze: () {},
            onJumpToGraph: (target) => jumped = target,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('morning-briefing-audio-toggle')));
    await tester.pump();

    expect(audio.playCount, 1);
    expect(focused, 'node-focus');
    expect(find.bySemanticsLabel('Pause morning narration'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.byKey(const Key('morning-jump-graph')));
    expect(jumped, 'node-focus');
  });

  testWidgets('snooze action invokes the local scheduling callback', (
    tester,
  ) async {
    var snoozed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MorningBriefingSheet(
            briefing: _briefing(),
            loadAudio: () async => null,
            audioController: _FakeAudioController(),
            onStartDayFocus: (_) {},
            onSnooze: () => snoozed = true,
            onJumpToGraph: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.byKey(const Key('morning-snooze')));
    await tester.pump();
    expect(snoozed, isTrue);
  });
}

MorningBriefing _briefing() => MorningBriefing(
  id: 'briefing-1',
  localDay: DateTime(2026, 7, 27),
  generatedAt: DateTime.utc(2026, 7, 27, 6),
  sections: [
    MorningBriefingSection(
      kind: MorningBriefingSectionKind.restAndRecovery,
      title: 'Rest & Recovery',
      narrative: 'Your recovery is steady.',
    ),
    MorningBriefingSection(
      kind: MorningBriefingSectionKind.mindMapMomentum,
      title: 'Mind Map Momentum',
      narrative: 'Project momentum is rising.',
    ),
    MorningBriefingSection(
      kind: MorningBriefingSectionKind.todaysSingleFocus,
      title: "Today's Single Focus",
      narrative: 'Take one grounded step.',
    ),
  ],
  sleepQualityScore: 82,
  activeHabitCount: 2,
  bestHabitRun: 5,
  highlightedNodeId: 'node-focus',
);

class _FakeAudioController implements MorningBriefingAudioController {
  late VoidCallback _onStarted;
  late VoidCallback _onCompleted;
  int playCount = 0;

  @override
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _onStarted = onStarted;
    _onCompleted = onCompleted;
  }

  @override
  Future<void> play({
    required String narration,
    Uint8List? encryptedAudio,
  }) async {
    playCount++;
    _onStarted();
  }

  @override
  Future<void> stop() async => _onCompleted();

  @override
  Future<void> dispose() async {}
}
