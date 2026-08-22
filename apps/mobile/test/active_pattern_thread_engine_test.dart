import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ActivePatternThreadEngine();

  test('title cleanup removes whether and formats gerund', () {
    expect(
      engine.titleFromWatchFor(
        'whether you take responsibility before asking for help',
      ),
      'Taking responsibility before asking for help',
    );
    expect(
      engine.titleFromWatchFor('whether the same worry shows up again'),
      'The same worry returning',
    );
  });

  test('showedAgain updates active status', () {
    final status = engine.statusFromRecentResults([WatchForResult.showedAgain]);
    expect(status, ActivePatternThreadStatus.active);
  });

  test('two didNotShow results update easing status', () {
    final status = engine.statusFromRecentResults([
      WatchForResult.didNotShow,
      WatchForResult.didNotShow,
    ]);
    expect(status, ActivePatternThreadStatus.easing);
  });

  test('changedShape updates changing status', () {
    final status = engine.statusFromRecentResults([
      WatchForResult.changedShape,
    ]);
    expect(status, ActivePatternThreadStatus.changing);
  });

  test('buildFromWatchForResult sets nextPrompt for active thread', () {
    final completed = WatchForItem(
      id: 'w1',
      createdAt: DateTime(2026, 5, 25),
      targetDate: DateTime(2026, 5, 25),
      text: 'whether you take responsibility before asking for help',
      chips: const ['feeling responsible'],
      status: WatchForStatus.checked,
      result: WatchForResult.showedAgain,
      completedAt: DateTime(2026, 5, 25, 10),
    );
    final thread = engine.buildFromWatchForResult(completed: completed);
    expect(thread.title, contains('Taking responsibility'));
    expect(thread.nextPrompt, contains('Today, notice whether'));
    expect(thread.daysActive, 1);
  });
}