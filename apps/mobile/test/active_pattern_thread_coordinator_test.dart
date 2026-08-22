import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_thread_coord_journal_$stamp.json',
    prefsPath: '/tmp/vm_thread_coord_prefs_$stamp.json',
  );
}

WatchForItem _completed(WatchForResult result) => WatchForItem(
  id: 'wf',
  createdAt: DateTime(2026, 5, 24),
  targetDate: DateTime(2026, 5, 25),
  text: 'whether you take responsibility before asking for help',
  chips: const ['feeling responsible', 'asking for help'],
  status: WatchForStatus.checked,
  result: result,
  completedAt: DateTime(2026, 5, 25, 11),
);

void main() {
  test('watch-for result creates thread', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final thread =
        await ActivePatternThreadCoordinator.updateFromWatchForResult(
          completed: _completed(WatchForResult.showedAgain),
        );
    expect(thread.title, contains('Taking responsibility'));
    final store = ActivePatternThreadStore(AppServices.instance.prefs);
    expect((await store.readCurrent())?.id, thread.id);
  });

  test('pause and resume thread', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivePatternThreadCoordinator.updateFromWatchForResult(
      completed: _completed(WatchForResult.showedAgain),
    );
    await ActivePatternThreadCoordinator.pauseThread();
    expect(await ActivePatternThreadCoordinator.loadCurrentThread(), isNull);

    final resumed = await ActivePatternThreadCoordinator.resumeThread();
    expect(resumed?.status, ActivePatternThreadStatus.active);
    expect(await ActivePatternThreadCoordinator.loadCurrentThread(), isNotNull);
  });

  test('screenshot sample exists', () {
    final sample = ActivePatternThreadCoordinator.screenshotSample();
    expect(sample.title, contains('Taking responsibility'));
    expect(sample.daysActive, 3);
    expect(sample.lastResult, WatchForResult.showedAgain);
    expect(sample.chips, hasLength(3));
  });

  test('consumer copy uses ArchiveMe not VoiceMemory', () {
    expect(ConsumerUiCopy.patternsEmptySubtitle, contains('ArchiveMe'));
    expect(
      ConsumerUiCopy.patternsEmptySubtitle,
      isNot(contains('VoiceMemory')),
    );
    expect(ConsumerUiCopy.tomorrowCommitmentTitle, contains('ArchiveMe'));
    expect(ConsumerUiCopy.activePatternPostSaveLine, contains('ArchiveMe'));
  });
}