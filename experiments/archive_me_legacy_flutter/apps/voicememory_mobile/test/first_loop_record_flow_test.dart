import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/record/record_stack_policy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/archive_memory_demo_card.dart';
import 'package:voicememory_mobile/widgets/record/first_loop_ready_card.dart';
import 'package:voicememory_mobile/widgets/record/first_loop_start_card.dart';
import 'package:voicememory_mobile/widgets/patterns/first_loop_state_card.dart';

const _bannedVisible = <String>[
  'archive',
  'belief',
  'intelligence',
  'evidence',
  'signal',
  'prediction',
  'contradiction',
  'discovery',
  'engine',
  'analysis',
];

bool _containsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.toLowerCase().contains(word);
}

Iterable<String> _visibleText(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void _expectNoBannedWords(WidgetTester tester) {
  final visible = _visibleText(tester).join(' \n ');
  for (final word in _bannedVisible) {
    expect(
      _containsBanned(visible, word),
      isFalse,
      reason: 'visible copy must not contain "$word": $visible',
    );
  }
}

void main() {
  testWidgets('first-run policy keeps archive demo off the ready stack', (
    tester,
  ) async {
    final stack = decideRecordStack(
      hasDueCheck: false,
      isFirstRun: true,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: false,
      inputQualityNeedsCoach: false,
      hasCompletedResult: false,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
    );
    expect(stack.showArchiveMemoryDemo, isFalse);
    expect(stack.showStarterPrompts, isFalse);
    expect(stack.primaryState, RecordPrimaryState.firstRun);
  });

  testWidgets('ArchiveMemoryDemoCard shows Day 1/3/7 and positioning line', (
    tester,
  ) async {
    var tapped = false;
    await _pump(tester, ArchiveMemoryDemoCard(onRecord: () => tapped = true));

    expect(find.text(ConsumerUiCopy.archiveMemoryDemoTitle), findsOneWidget);
    expect(find.textContaining('Day 1:'), findsOneWidget);
    expect(find.textContaining('Day 3:'), findsOneWidget);
    expect(find.textContaining('Day 7:'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.firstRecordPositioningLine),
      findsOneWidget,
    );
    await tester.tap(find.text(ConsumerUiCopy.archiveMemoryDemoCta));
    expect(tapped, isTrue);
  });

  testWidgets('FirstLoopStartCard shows framing and fires onRecord', (
    tester,
  ) async {
    var tapped = false;
    await _pump(tester, FirstLoopStartCard(onRecord: () => tapped = true));

    expect(find.text('Start with one moment'), findsOneWidget);
    expect(find.text('Record one moment'), findsOneWidget);
    expect(
      find.text('I said yes before checking what I needed.'),
      findsOneWidget,
    );
    _expectNoBannedWords(tester);

    await tester.tap(find.text('Record one moment'));
    expect(tapped, isTrue);
  });

  testWidgets('FirstLoopReadyCard shows tomorrow question and CTAs', (
    tester,
  ) async {
    var done = false;
    var another = false;
    await _pump(
      tester,
      FirstLoopReadyCard(
        question: 'What happens right before you say yes?',
        onDone: () => done = true,
        onRecordAnother: () => another = true,
      ),
    );

    expect(find.text('Tomorrow\u2019s check is set'), findsOneWidget);
    expect(find.text('What happens right before you say yes?'), findsOneWidget);
    expect(find.text('Done for today'), findsOneWidget);
    _expectNoBannedWords(tester);

    await tester.tap(find.text('Done for today'));
    await tester.tap(find.text('Record another moment'));
    expect(done, isTrue);
    expect(another, isTrue);
  });

  testWidgets('Patterns no-reflection state shows Record one moment', (
    tester,
  ) async {
    await _pump(
      tester,
      FirstLoopStateCard(
        phase: FirstLoopStatePhase.recordMoment,
        onRecord: () {},
      ),
    );
    expect(find.text('Record one moment'), findsNWidgets(2));
    expect(find.text(ConsumerUiCopy.patternsEarlyStateBody), findsOneWidget);
    _expectNoBannedWords(tester);
  });

  testWidgets('Patterns loop-ready state shows tomorrow check question', (
    tester,
  ) async {
    await _pump(
      tester,
      FirstLoopStateCard(
        phase: FirstLoopStatePhase.ready,
        question: 'What happens right before you say yes?',
        onRecord: () {},
      ),
    );
    expect(find.text('Tomorrow\u2019s check is ready'), findsOneWidget);
    expect(find.text('What happens right before you say yes?'), findsOneWidget);
    expect(find.text('Record another moment'), findsOneWidget);
    _expectNoBannedWords(tester);
  });

  testWidgets('Patterns choose-check state shows choose tomorrow check', (
    tester,
  ) async {
    await _pump(
      tester,
      FirstLoopStateCard(
        phase: FirstLoopStatePhase.chooseCheck,
        onRecord: () {},
      ),
    );
    expect(find.text('Choose tomorrow\u2019s check'), findsNWidgets(2));
    _expectNoBannedWords(tester);
  });

  test('first-run archive demo suppresses no-check retention card', () {
    final d = decideRecordStack(
      hasDueCheck: false,
      isFirstRun: true,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: false,
      inputQualityNeedsCoach: false,
      hasCompletedResult: false,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
      hasRetentionStateCard: true,
      suppressRetentionForFirstRunDemo: true,
    );
    expect(d.showArchiveMemoryDemo, isFalse);
    expect(d.showRetentionStateCard, isFalse);
  });
}
