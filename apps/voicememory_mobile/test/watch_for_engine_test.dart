import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

JournalEntry _entry(String text, {int pad = 80}) {
  final filler = 'x' * pad;
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 5, 25, 12),
    transcript: '$text $filler',
    durationSeconds: 45,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: const [],
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: text,
    ),
  );
}

WatchForItem _pending({String text = 'whether you take responsibility before asking for help'}) {
  return WatchForItem(
    id: 'wf1',
    createdAt: DateTime(2026, 5, 24),
    targetDate: DateTime(2026, 5, 25),
    text: text,
    chips: const ['feeling responsible', 'asking for help', 'doing it alone'],
    status: WatchForStatus.pending,
    result: WatchForResult.none,
  );
}

void main() {
  const engine = WatchForEngine();

  test('builds useful fallback watch-for', () {
    final item = engine.buildSuggested(now: DateTime(2026, 5, 25));
    expect(item.text, contains('whether'));
    expect(item.chips, isNotEmpty);
    expect(item.targetDate, WatchForItem.dateOnly(DateTime(2026, 5, 26)));
  });

  test('uses tomorrow return loop watch-for when available', () {
    final loop = TomorrowReturnLoop(
      noticedToday: 'You keep carrying everything alone.',
      comeBackTomorrow: 'Come back tomorrow.',
      watchForNextTime: 'whether guilt when you slow down returns',
      generatedAt: DateTime(2026, 5, 25),
      watchForChips: const ['feeling responsible', 'doing it alone'],
    );
    final item = engine.buildSuggested(now: DateTime(2026, 5, 25), loop: loop);
    expect(item.text, loop.watchForNextTime);
    expect(item.chips, loop.displayWatchChips);
  });

  test('cycles deterministic alternatives', () {
    final a = engine.buildSuggested(now: DateTime(2026, 5, 25), alternativeIndex: 0);
    final b = engine.buildSuggested(now: DateTime(2026, 5, 25), alternativeIndex: 1);
    expect(a.text, isNot(equals(b.text)));
  });

  test('detects showedAgain by keyword and chip overlap', () {
    final result = engine.compareReflection(
      pending: _pending(),
      entry: _entry(
        'I took responsibility again before asking for help and felt responsible',
      ),
    );
    expect(result, WatchForResult.showedAgain);
    expect(
      engine.resultHeadline(result),
      ConsumerUiCopy.watchForResultShowedAgain,
    );
  });

  test('detects didNotShow when no overlap and enough text', () {
    final result = engine.compareReflection(
      pending: _pending(text: 'whether guilt when you slow down returns'),
      entry: _entry(
        'Vacation plans and sunny weather made today feel open and unhurried',
        pad: 60,
      ),
    );
    expect(result, WatchForResult.didNotShow);
  });

  test('vague transcript with lighter hint uses lighter result copy', () {
    const engine = WatchForEngine();
    final result = engine.compareReflection(
      pending: _pending(),
      entry: JournalEntry(
        id: 'short',
        createdAt: DateTime(2026, 5, 25),
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
      comparisonHint: ReturnCaptureComparisonHints.lighter,
    );
    expect(result, WatchForResult.changedShape);
    expect(
      engine.resultHeadline(result, comparisonHint: ReturnCaptureComparisonHints.lighter),
      ConsumerUiCopy.watchForResultFeltLighterToday,
    );
    expect(
      engine.resultBody(
        pending: _pending(),
        result: result,
        entry: _entry('ok', pad: 0),
        comparisonHint: ReturnCaptureComparisonHints.lighter,
      ),
      contains('lighter'),
    );
  });

  test('detects unclear when text is too short', () {
    final result = engine.compareReflection(
      pending: _pending(),
      entry: JournalEntry(
        id: 'short',
        createdAt: DateTime(2026, 5, 25),
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
    );
    expect(result, WatchForResult.unclear);
  });

  test('detects changedShape when overlap and shift markers', () {
    final result = engine.compareReflection(
      pending: _pending(),
      entry: _entry(
        'I felt responsible before asking for help but worried about disappointing someone instead',
        pad: 40,
      ),
    );
    expect(result, WatchForResult.changedShape);
  });
}
