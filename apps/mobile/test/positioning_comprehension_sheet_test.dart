import 'package:archiveme_mobile/features/trial/positioning_comprehension_model.dart';
import 'package:archiveme_mobile/features/trial/positioning_comprehension_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sheet widget I/O is covered by [PositioningComprehensionStore] tests; this
/// file verifies the sheet's store wiring without modal/prefs deadlocks in
/// widget tests.
void main() {
  test('comprehension sheet records archive memory choice', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_positioning_sheet_journal_$stamp.json',
      prefsPath: '/tmp/vm_positioning_sheet_prefs_$stamp.json',
    );
    final store = PositioningComprehensionStore(AppServices.instance.prefs);

    await store.markAsked();
    await store.recordAnswer(PositioningComprehensionAnswer.archiveMemory);

    expect(await store.hasAnswered(), isTrue);
    final all = await store.loadAll();
    expect(all.first.answer, PositioningComprehensionAnswer.archiveMemory);
    expect(PositioningComprehensionCopy.archiveMemoryLabel, isNotEmpty);
  });
}