import 'package:archiveme_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_tracker.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_hd_journal_$stamp.json',
    prefsPath: '/tmp/vm_hd_prefs_$stamp.json',
  );
}

HookDiagnosisEvent _event({
  required String type,
  String? rating,
  String? reason,
}) {
  return HookDiagnosisEvent(
    id: 'e_${DateTime.now().microsecondsSinceEpoch}',
    createdAt: DateTime.now(),
    type: type,
    checkInId: 'tci1',
    rating: rating,
    reason: reason,
  );
}

void main() {
  test('append and load events', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = HookDiagnosisStore(AppServices.instance.prefs);
    await store.append(
      _event(
        type: HookDiagnosisEventType.checkInQuestionRated,
        rating: HookDiagnosisRating.yes,
      ),
    );
    final all = await store.loadAll();
    expect(all, hasLength(1));
    expect(all.first.type, HookDiagnosisEventType.checkInQuestionRated);
  });

  test('summary merges activation funnel counts', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = HookDiagnosisStore(AppServices.instance.prefs);
    final summary = await store.summary();
    expect(summary.likelyFailure, isNotEmpty);
  });

  test('tracker stores not-useful reason after Too vague', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    HookDiagnosisTracker.trackCheckInResultNotUsefulReason(
      checkInId: 'tci_test',
      reason: HookDiagnosisNotUsefulReason.tooVague,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final events = await HookDiagnosisStore(
      AppServices.instance.prefs,
    ).loadAll();
    expect(events, hasLength(1));
    expect(
      events.first.type,
      HookDiagnosisEventType.checkInResultNotUsefulReason,
    );
    expect(events.first.reason, HookDiagnosisNotUsefulReason.tooVague);
  });

  test('append not-useful reason event', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = HookDiagnosisStore(AppServices.instance.prefs);
    await store.append(
      _event(
        type: HookDiagnosisEventType.checkInResultNotUsefulReason,
        reason: HookDiagnosisNotUsefulReason.tooVague,
      ),
    );
    final summary = await store.summary();
    expect(
      summary.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.tooVague],
      1,
    );
  });

  test('clear removes events', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = HookDiagnosisStore(AppServices.instance.prefs);
    await store.append(_event(type: HookDiagnosisEventType.checkInConfusing));
    await store.clear();
    expect(await store.loadAll(), isEmpty);
  });
}