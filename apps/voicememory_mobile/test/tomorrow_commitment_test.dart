import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_commitment_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_commitment_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/tomorrow_return_status_card.dart';
import 'package:voicememory_mobile/widgets/record/tomorrow_commitment_card.dart';

bool _visibleContainsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.contains(word);
}

const _bannedVisible = <String>[
  'voicememory',
  'archive',
  'belief',
  'beliefs',
  'intelligence',
  'evidence',
  'discover',
  'discovery',
  'signal',
  'signals',
  'analyst',
  'historian',
  'theory',
  'contradiction',
  'prediction',
];

TomorrowReturnLoop _sampleLoop() => ScreenshotSampleData.tomorrowReturnLoop;

Future<void> _resetTestServices(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_commit_journal_$stamp.json',
    prefsPath: '/tmp/vm_commit_prefs_$stamp.json',
  );
}

void main() {
  test('commitment store saves and loads', () async {
    final dir = await Directory.systemTemp.createTemp('vm_commit_test');
    final store = TomorrowCommitmentStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );

    final commitment = TomorrowCommitment(
      committedAt: DateTime(2026, 5, 24, 18),
      targetDate: DateTime(2026, 5, 25),
      promptText: ScreenshotSampleData.commitmentSamplePrompt,
      watchForChips: ScreenshotSampleData.returnLoopWatchChips,
    );

    await store.write(commitment);
    final read = await store.read();

    expect(read?.promptText, commitment.promptText);
    expect(read?.watchForChips, commitment.watchForChips);
    expect(
      TomorrowCommitment.dateOnly(read!.targetDate),
      TomorrowCommitment.dateOnly(commitment.targetDate),
    );
  });

  test('saveFromReturnLoop sets target date to tomorrow', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await _resetTestServices('$stamp');

    final now = DateTime(2026, 6, 10, 15, 30);
    final saved = await TomorrowCommitmentCoordinator.saveFromReturnLoop(
      _sampleLoop(),
      now: now,
    );

    expect(
      TomorrowCommitment.dateOnly(saved.targetDate),
      TomorrowCommitment.tomorrowFrom(now),
    );
    expect(saved.watchForChips, isNotEmpty);

    final read = await TomorrowCommitmentStore(
      AppServices.instance.prefs,
    ).read();
    expect(read?.promptText, saved.promptText);
  });

  test('markCompleteIfTargetDay sets completedAt on target day', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await _resetTestServices('done_$stamp');

    final targetDay = DateTime(2026, 7, 1);
    await TomorrowCommitmentStore(AppServices.instance.prefs).write(
      TomorrowCommitment(
        committedAt: targetDay.subtract(const Duration(days: 1)),
        targetDate: targetDay,
        promptText: 'Watch for pressure.',
        watchForChips: const ['feeling responsible'],
      ),
    );

    await TomorrowCommitmentCoordinator.markCompleteIfTargetDay(
      now: DateTime(2026, 7, 1, 9),
    );

    final read = await TomorrowCommitmentStore(
      AppServices.instance.prefs,
    ).read();
    expect(read?.completedAt, isNotNull);
    expect(
      read!.displayState(DateTime(2026, 7, 1, 12)),
      TomorrowCommitmentDisplayState.completedToday,
    );
  });

  test('screenshot sample commitment exposes watch chips and prompt', () {
    final now = DateTime(2026, 5, 25, 10);
    final c = ScreenshotSampleData.tomorrowCommitmentForPreview(now);
    expect(c.promptText, ScreenshotSampleData.commitmentSamplePrompt);
    expect(c.watchForChips, ScreenshotSampleData.returnLoopWatchChips);
    expect(c.displayState(now), TomorrowCommitmentDisplayState.awaitingReturn);
  });

  testWidgets('commitment card renders without banned words', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TomorrowCommitmentCard(loop: _sampleLoop())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(ConsumerUiCopy.tomorrowCommitmentTitle), findsOneWidget);

    final visible = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .join('\n')
        .toLowerCase();
    for (final word in _bannedVisible) {
      expect(
        _visibleContainsBanned(visible, word),
        isFalse,
        reason: 'found $word',
      );
    }
  });

  testWidgets('tapping Remind me tomorrow shows confirmed state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TomorrowCommitmentCard(
            loop: _sampleLoop(),
            onRemindTomorrow: (_) async {
              saved = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(ConsumerUiCopy.tomorrowCommitmentRemindCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(saved, isTrue);

    expect(
      find.text(ConsumerUiCopy.tomorrowCommitmentConfirmedLine1),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.tomorrowCommitmentConfirmedLine2),
      findsOneWidget,
    );
  });

  testWidgets('Patterns status card renders active commitment state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 5, 25);
    final commitment = ScreenshotSampleData.tomorrowCommitmentForPreview(now);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TomorrowReturnStatusCard(
            commitment: commitment,
            state: TomorrowCommitmentDisplayState.awaitingReturn,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text(ConsumerUiCopy.tomorrowReturnStatusCameBackTitle),
      findsOneWidget,
    );
    expect(find.textContaining('doing it alone'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsComeBackRecordCta), findsOneWidget);
  });

  testWidgets('status card completed CTA routes to belief-changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/patterns',
      routes: [
        GoRoute(
          path: '/patterns',
          builder: (context, state) => Scaffold(
            body: TomorrowReturnStatusCard(
              commitment: ScreenshotSampleData.tomorrowCommitmentActive,
              state: TomorrowCommitmentDisplayState.completedToday,
            ),
          ),
        ),
        GoRoute(
          path: '/belief-changes',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('changes-screen'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();

    await tester.tap(
      find.text(ConsumerUiCopy.tomorrowReturnStatusSeeChangedCta),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('changes-screen'), findsOneWidget);
  });
}
