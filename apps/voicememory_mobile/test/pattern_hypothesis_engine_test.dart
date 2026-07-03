import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/post_save_insight/selected_signal_coordinator.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_coordinator.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:voicememory_mobile/features/retention/pattern_hypothesis_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, int.parse(id)),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: 'You mentioned pressure in this moment.',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_hypothesis_journal_$stamp.json',
    prefsPath: '/tmp/vm_hypothesis_prefs_$stamp.json',
  );
}

void main() {
  test('hypothesis appears only after 2+ moments', () async {
    const engine = PatternHypothesisEngine();
    final one = await engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
    ]);
    expect(one.hasEnoughData, isFalse);

    final two = await engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ]);
    expect(two.hasEnoughData, isTrue);
    expect(two.patternMightBe, isNotEmpty);
  });

  test('evidence uses saved moments and selected signal', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SelectedSignalCoordinator.save(
      title: 'Carrying too much responsibility',
      categoryId: 'responsibility',
      strengthLabel: 'Early signal',
      nextPrompt: 'When did you next feel pressure to say yes?',
      whySuggested: 'You mentioned saying yes, pressure.',
      evidenceChips: const ['saying yes', 'pressure'],
    );

    const engine = PatternHypothesisEngine();
    final hypothesis = await engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ]);

    expect(hypothesis.evidenceSoFar, isNotEmpty);
    expect(
      hypothesis.evidenceSoFar.any(
        (e) => e.toLowerCase().contains('mentioned'),
      ),
      isTrue,
    );
  });

  test('Not me saves correction feedback', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.rejected,
      signalId: 'test_signal',
      signalTitle: 'Carrying too much responsibility',
      categoryId: 'responsibility',
    );

    final rows = await SignalFeedbackStore.instance().loadAll();
    expect(rows, isNotEmpty);
    expect(rows.first.action, PostSaveSignalAction.rejected);
  });

  test('generic harness entries return insufficient hypothesis', () async {
    const engine = PatternHypothesisEngine();
    final hypothesis = await engine.build([
      _entry('1', 'This is a test to check function'),
      _entry('2', 'This is a second test for pressure'),
    ]);
    expect(hypothesis.hasEnoughData, isFalse);
    expect(hypothesis.patternMightBe, isEmpty);
    expect(hypothesis.evidenceSoFar, isEmpty);
  });

  test('hypothesis copy uses working hypothesis language', () async {
    const engine = PatternHypothesisEngine();
    final hypothesis = await engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ]);

    expect(
      ConsumerUiCopy.patternHypothesisTitle.toLowerCase(),
      contains('hypothesis'),
    );
    expect(ConsumerUiCopy.patternHypothesisLead.toLowerCase(), contains('may'));
    expect(
      hypothesis.wouldProveWrong.toLowerCase(),
      isNot(contains('diagnosis')),
    );
  });
}
