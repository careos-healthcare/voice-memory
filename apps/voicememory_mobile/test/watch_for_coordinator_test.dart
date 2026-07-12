import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

JournalEntry _entry(String text) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 5, 25, 12),
    transcript:
        '$text — enough detail for comparing responsibility and asking for help today.',
    durationSeconds: 45,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: const ['feeling responsible', 'asking for help'],
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: text,
    ),
  );
}

Future<void> _reset(String stamp) async {
  final tmp = await Directory.systemTemp.createTemp('vm_watch_coord_$stamp');
  await AppServices.resetForTest(
    journalPath: '${tmp.path}/journal.json',
    prefsPath: '${tmp.path}/prefs.json',
  );
}

Future<ActivationEventCounts> _readEventsWhenReady({
  required int shown,
  required int selected,
}) async {
  for (var i = 0; i < 100; i++) {
    final events = await ActivationEventsStore(
      AppServices.instance.prefs,
    ).read();
    if (events.tomorrowQuestionVariantShown >= shown &&
        events.tomorrowQuestionVariantSelected >= selected) {
      return events;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  return ActivationEventsStore(AppServices.instance.prefs).read();
}

void main() {
  test('accepts and stores pending watch-for', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final suggested = WatchForCoordinator.buildSuggestedWatchForAfterSave(
      entries: [_entry('I keep taking responsibility before asking for help')],
      now: DateTime(2026, 5, 25),
    );
    final accepted = await WatchForCoordinator.acceptSuggestedWatchFor(
      suggested,
    );
    final store = WatchForStore(AppServices.instance.prefs);
    final pending = await store.readPending();
    expect(pending?.id, accepted.id);
    expect(pending?.status, WatchForStatus.pending);
  });

  test('loads pending only for targetDate today', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = WatchForStore(AppServices.instance.prefs);
    await store.writePending(
      WatchForItem(
        id: 'future',
        createdAt: DateTime(2026, 5, 25),
        targetDate: DateTime(2026, 5, 27),
        text: 'whether the same worry shows up again',
        chips: const [],
        status: WatchForStatus.pending,
        result: WatchForResult.none,
      ),
    );
    final notToday = await WatchForCoordinator.loadPendingForToday(
      now: DateTime(2026, 5, 26),
    );
    expect(notToday, isNull);

    await store.writePending(
      WatchForItem(
        id: 'today',
        createdAt: DateTime(2026, 5, 25),
        targetDate: DateTime(2026, 5, 26),
        text: 'whether you take responsibility before asking for help',
        chips: const ['feeling responsible'],
        status: WatchForStatus.pending,
        result: WatchForResult.none,
      ),
    );
    final today = await WatchForCoordinator.loadPendingForToday(
      now: DateTime(2026, 5, 26),
    );
    expect(today?.id, 'today');
  });

  test('completes with lighter hint when transcript is vague', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = WatchForStore(AppServices.instance.prefs);
    await store.writePending(
      WatchForItem(
        id: 'due-lighter',
        createdAt: DateTime(2026, 5, 25),
        targetDate: DateTime(2026, 5, 26),
        text:
            'Tomorrow, notice if you say yes or carry something before checking what you need.',
        chips: const ['saying yes fast'],
        status: WatchForStatus.pending,
        result: WatchForResult.none,
        specificPrompt:
            'Tomorrow, notice if you say yes or carry something before checking what you need.',
      ),
    );
    await ReturnCaptureStore(AppServices.instance.prefs).saveSelection(
      ReturnCaptureSelection(
        watchForId: 'due-lighter',
        selectedQuickAnswerId: 'felt_lighter',
        comparisonHint: ReturnCaptureComparisonHints.lighter,
        createdAt: DateTime(2026, 5, 26, 8),
      ),
    );

    final completed = await WatchForCoordinator.completePendingAfterSave(
      entries: [
        JournalEntry(
          id: 'short',
          createdAt: DateTime(2026, 5, 26, 11),
          transcript: 'ok',
          durationSeconds: 5,
          reflection: Reflection(
            mood: '',
            emotionalIntensity: 1,
            recurringThemes: const [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      ],
      now: DateTime(2026, 5, 26, 11),
    );

    expect(completed?.comparisonHint, ReturnCaptureComparisonHints.lighter);
    expect(WatchForCoordinator.headlineFor(completed!), contains('lighter'));
    expect(
      await ReturnCaptureStore(AppServices.instance.prefs).loadLatest(),
      isNull,
    );
  });

  test('completes pending after next-day save', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = WatchForStore(AppServices.instance.prefs);
    await store.writePending(
      WatchForItem(
        id: 'due',
        createdAt: DateTime(2026, 5, 25),
        targetDate: DateTime(2026, 5, 26),
        text: 'whether you take responsibility before asking for help',
        chips: const ['feeling responsible', 'asking for help'],
        status: WatchForStatus.pending,
        result: WatchForResult.none,
      ),
    );
    final completed = await WatchForCoordinator.completePendingAfterSave(
      entries: [
        _entry(
          'I took responsibility before asking for help and felt responsible again',
        ),
      ],
      now: DateTime(2026, 5, 26, 11),
    );
    expect(completed?.result, WatchForResult.showedAgain);
    expect(await store.readPending(), isNull);
    expect((await store.readLatestCompleted())?.status, WatchForStatus.checked);
  });

  test('screenshot samples expose pending and completed', () {
    final pending = ScreenshotSampleData.watchForPendingForToday(
      DateTime(2026, 5, 26),
    );
    expect(pending.text, ScreenshotSampleData.watchForSpecificPrompt);
    expect(pending.isDueOn(DateTime(2026, 5, 26)), isTrue);

    final completed = ScreenshotSampleData.watchForCompletedSample;
    expect(completed.result, WatchForResult.showedAgain);
    expect(
      ScreenshotSampleData.watchForCompletedHeadline,
      contains('showed up again'),
    );
    expect(ScreenshotSampleData.watchForCompletedBody, contains('Yesterday'));
  });

  test('tracks question variant shown and selected metrics', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    ActivationTracker.trackTomorrowQuestionVariantShown(
      variantId: 'sharper',
      categoryId: 'worry',
    );
    ActivationTracker.trackTomorrowQuestionVariantSelected(
      variantId: 'practical',
      categoryId: 'responsibility',
    );

    final events = await _readEventsWhenReady(shown: 1, selected: 1);
    expect(events.tomorrowQuestionVariantShown, 1);
    expect(events.tomorrowQuestionVariantSelected, 1);
  });

  test('buildSuggested uses loop watch-for', () {
    final loop = TomorrowReturnLoop(
      noticedToday: 'noticed',
      comeBackTomorrow: 'come back',
      watchForNextTime: 'whether the same worry shows up again',
      generatedAt: DateTime(2026, 5, 25),
      watchForChips: const ['same worry'],
    );
    final item = WatchForCoordinator.buildSuggestedWatchForAfterSave(
      entries: const [],
      loop: loop,
      now: DateTime(2026, 5, 25),
    );
    expect(item.text, loop.watchForNextTime);
  });
}
