import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

WatchForItem _item({
  required String id,
  required DateTime target,
  WatchForStatus status = WatchForStatus.pending,
  WatchForResult result = WatchForResult.none,
}) {
  return WatchForItem(
    id: id,
    createdAt: target.subtract(const Duration(days: 1)),
    targetDate: target,
    text: 'whether you take responsibility before asking for help',
    chips: const ['feeling responsible'],
    status: status,
    result: result,
    completedAt: status == WatchForStatus.checked ? target : null,
  );
}

void main() {
  test('persists pending, completed, and history cap', () async {
    final dir = await Directory.systemTemp.createTemp('vm_watch_for_store');
    final store = WatchForStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );

    final pending = _item(id: 'p1', target: DateTime(2026, 5, 26));
    await store.writePending(pending);
    expect((await store.readPending())?.id, 'p1');

    final completed = pending.copyWith(
      status: WatchForStatus.checked,
      result: WatchForResult.showedAgain,
      completedAt: DateTime(2026, 5, 26, 10),
    );
    await store.writePending(null);
    await store.writeLatestCompleted(completed);
    expect(await store.readPending(), isNull);
    expect(
      (await store.readLatestCompleted())?.result,
      WatchForResult.showedAgain,
    );

    for (var i = 0; i < 16; i++) {
      await store.appendHistory(
        _item(
          id: 'h$i',
          target: DateTime(2026, 5, 1 + i),
          status: WatchForStatus.checked,
          result: WatchForResult.showedAgain,
        ),
      );
    }
    final history = await store.readHistory();
    expect(history.length, lessThanOrEqualTo(14));
    expect(history.first.id, 'h15');
  });

  test('round-trips json fields', () async {
    final raw = _item(id: 'x', target: DateTime(2026, 6, 1)).toJson();
    final read = WatchForItem.fromJson(raw);
    expect(read?.text, contains('responsibility'));
    expect(read?.chips, isNotEmpty);
  });
}
