import 'dart:io';

import 'package:archiveme_mobile/features/trial/positioning_comprehension_model.dart';
import 'package:archiveme_mobile/features/trial/positioning_comprehension_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PositioningComprehensionStore> _store(String stamp) async {
  final dir = Directory.systemTemp.createTempSync('vm_positioning_$stamp');
  final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
  return PositioningComprehensionStore(prefs);
}

void main() {
  test('records archive memory answer', () async {
    final store = await _store('a');
    expect(await store.hasAnswered(), isFalse);
    await store.recordAnswer(PositioningComprehensionAnswer.archiveMemory);
    expect(await store.hasAnswered(), isTrue);
    final all = await store.loadAll();
    expect(all.first.answer, PositioningComprehensionAnswer.archiveMemory);
  });

  test('summary pass when 3 of 5 chose archive memory', () {
    const summary = PositioningComprehensionSummary(
      askedCount: 5,
      answeredCount: 5,
      archiveMemoryCount: 3,
      journalCount: 1,
      chatCount: 1,
      notSureCount: 0,
    );
    expect(summary.pass, isTrue);
    expect(summary.archiveMemoryRate, 0.6);
  });
}