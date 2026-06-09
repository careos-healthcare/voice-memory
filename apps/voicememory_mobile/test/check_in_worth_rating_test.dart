import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_tracker.dart';
import 'package:voicememory_mobile/services/app_services.dart';

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

    HookDiagnosisTracker.trackCheckInQuestionRated(
      checkInId: 'tci_a',
      rating: HookDiagnosisRating.yes,
    );
    HookDiagnosisTracker.trackCheckInQuestionRated(
      checkInId: 'tci_b',
      rating: HookDiagnosisRating.sortOf,
    );
    HookDiagnosisTracker.trackCheckInQuestionRated(
      checkInId: 'tci_c',
      rating: HookDiagnosisRating.notReally,
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final events = await store.loadAll();
    expect(events, hasLength(3));
    expect(
      events.map((e) => e.rating).toSet(),
      {
        HookDiagnosisRating.yes,
        HookDiagnosisRating.sortOf,
        HookDiagnosisRating.notReally,
      },
    );
    for (final e in events) {
      expect(e.type, HookDiagnosisEventType.checkInQuestionRated);
    }
  });
}
