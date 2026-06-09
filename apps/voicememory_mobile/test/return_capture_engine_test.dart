import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';

WatchForItem _pending() {
  return WatchForItem(
    id: 'wf-return',
    createdAt: DateTime(2026, 5, 25),
    targetDate: DateTime(2026, 5, 26),
    text:
        'Tomorrow, notice if you say yes or carry something before checking what you need.',
    chips: const ['saying yes fast'],
    status: WatchForStatus.pending,
    result: WatchForResult.none,
    checkInQuestion: 'Did you ask for help, or carry it alone?',
    specificPrompt:
        'Tomorrow, notice if you say yes or carry something before checking what you need.',
  );
}

void main() {
  const engine = ReturnCaptureEngine();

  test('creates four quick answers', () {
    final model = engine.build(pending: _pending());
    expect(model.quickAnswers, hasLength(4));
    expect(
      model.quickAnswers.map((a) => a.id).toList(),
      [
        'showed_up_again',
        'felt_lighter',
        'felt_heavier',
        'not_today',
      ],
    );
  });

  test('each quick answer has correct follow-up prompt', () {
    final answers = kDefaultReturnQuickAnswers;
    expect(answers[0].followUpPrompt, 'What was the moment?');
    expect(answers[1].followUpPrompt, 'What made it lighter today?');
    expect(answers[2].followUpPrompt, 'What made it heavier today?');
    expect(answers[3].followUpPrompt, 'What was different today?');
  });

  test('includes check-in question in starters when available', () {
    final model = engine.build(pending: _pending());
    expect(model.suggestedStarters.first, contains('help'));
    expect(model.suggestedStarters, contains('Today, it showed up when…'));
  });

  test('maps quality from rich pending watch-for', () {
    final model = engine.build(pending: _pending());
    expect(model.quality, ReturnCaptureQuality.high);
  });
}
