import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  test('saves loads and clears selection', () async {
    final dir = await Directory.systemTemp.createTemp('vm_return_capture');
    final store = ReturnCaptureStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );

    expect(await store.loadLatest(), isNull);

    final selection = ReturnCaptureSelection(
      watchForId: 'wf-1',
      selectedQuickAnswerId: 'felt_lighter',
      comparisonHint: ReturnCaptureComparisonHints.lighter,
      createdAt: DateTime(2026, 5, 26, 9),
    );
    await store.saveSelection(selection);

    final read = await store.loadLatest();
    expect(read?.watchForId, 'wf-1');
    expect(read?.selectedQuickAnswerId, 'felt_lighter');
    expect(read?.comparisonHint, ReturnCaptureComparisonHints.lighter);

    await store.clear();
    expect(await store.loadLatest(), isNull);
  });
}
