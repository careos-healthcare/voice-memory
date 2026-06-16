import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/active_pattern_thread_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

ActivePatternThread _thread(String id) => ActivePatternThread(
  id: id,
  title: 'Taking responsibility before asking for help',
  createdAt: DateTime(2026, 5, 25),
  updatedAt: DateTime(2026, 5, 25),
  watchForText: 'whether you take responsibility before asking for help',
  chips: const ['feeling responsible'],
  status: ActivePatternThreadStatus.active,
  daysActive: 2,
  lastResult: WatchForResult.showedAgain,
  lastResultDate: DateTime(2026, 5, 25),
  nextPrompt: 'Today, notice whether this shows up again.',
);

void main() {
  test('current thread persists and history caps at 10', () async {
    final dir = await Directory.systemTemp.createTemp('vm_thread_store');
    final store = ActivePatternThreadStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );

    await store.writeCurrent(_thread('current'));
    final read = await store.readCurrent();
    expect(read?.id, 'current');

    await store.writeCurrent(null);
    expect(await store.readCurrent(), isNull);

    for (var i = 0; i < 12; i++) {
      await store.appendHistory(_thread('h$i'));
    }
    final history = await store.readHistory();
    expect(history.length, lessThanOrEqualTo(10));
  });
}
