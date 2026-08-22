import 'package:archiveme_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_cwr_journal_$stamp.json',
    prefsPath: '/tmp/vm_cwr_prefs_$stamp.json',
  );
}

void main() {
  test('question rated tracks yes sort_of not_really', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = HookDiagnosisStore(AppServices.instance.prefs);

    // Append sequentially — concurrent unawaited appends race on read-modify-write.
    await store.append(
      HookDiagnosisEvent(
        id: 'hd_a',
        createdAt: DateTime(2026, 6, 12),
        type: HookDiagnosisEventType.checkInQuestionRated,
        checkInId: 'tci_a',
        rating: HookDiagnosisRating.yes,
      ),
    );
    await store.append(
      HookDiagnosisEvent(
        id: 'hd_b',
        createdAt: DateTime(2026, 6, 12, 1),
        type: HookDiagnosisEventType.checkInQuestionRated,
        checkInId: 'tci_b',
        rating: HookDiagnosisRating.sortOf,
      ),
    );
    await store.append(
      HookDiagnosisEvent(
        id: 'hd_c',
        createdAt: DateTime(2026, 6, 12, 2),
        type: HookDiagnosisEventType.checkInQuestionRated,
        checkInId: 'tci_c',
        rating: HookDiagnosisRating.notReally,
      ),
    );

    final events = await store.loadAll();
    expect(events, hasLength(3));
    expect(events.map((e) => e.rating).toSet(), {
      HookDiagnosisRating.yes,
      HookDiagnosisRating.sortOf,
      HookDiagnosisRating.notReally,
    });
    for (final e in events) {
      expect(e.type, HookDiagnosisEventType.checkInQuestionRated);
    }
  });
}