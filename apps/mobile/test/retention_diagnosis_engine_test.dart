import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/retention/retention_diagnosis_engine.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_engine.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_retention_journal_$stamp.json',
    prefsPath: '/tmp/vm_retention_prefs_$stamp.json',
  );
}

void main() {
  test('identifies didNotReturn when return rate is low', () {
    final diagnosis = diagnoseRetentionFromEvents(
      ActivationEventCounts.fromMap({'firstReflectionSaved': 10, 'tomorrowCheckInCreated': 10, 'returnedNextDay': 2, 'tomorrowCheckInCompleted': 2, 'resultNextCheckUsed': 2,}),
    );
    expect(
      diagnosis.weakestRetentionBucket,
      RetentionWeakestBucket.didNotReturn,
    );
    expect(diagnosis.nextDayReturnRate, 0.2);
  });

  test('identifies didNotChooseNextCheck when next check rate is low', () {
    final diagnosis = diagnoseRetentionFromEvents(
      ActivationEventCounts.fromMap({'firstReflectionSaved': 10, 'tomorrowCheckInCreated': 10, 'returnedNextDay': 10, 'tomorrowCheckInCompleted': 10, 'resultNextCheckUsed': 2,}),
    );
    expect(
      diagnosis.weakestRetentionBucket,
      RetentionWeakestBucket.didNotChooseNextCheck,
    );
    expect(diagnosis.nextCheckChoiceRate, 0.2);
  });

  test('trial summary includes retention counts', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);
    await store.write(
      ActivationEventCounts.fromMap({'retentionStateShown': 3, 'retentionDueShown': 1, 'retentionCheckSetShown': 2, 'retentionLoopClosedShown': 1, 'retentionPrimaryCtaTapped': 2, 'retentionNextCheckReady': 1, 'retentionMissedCheck': 1, 'reminderScheduledFromRetention': 1,}),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.retentionStateShownCount, 3);
    expect(summary.retentionDueShownCount, 1);
    expect(summary.retentionCheckSetShownCount, 2);
    expect(summary.retentionLoopClosedShownCount, 1);
    expect(summary.retentionPrimaryCtaTappedCount, 2);
    expect(summary.retentionNextCheckReadyCount, 1);
    expect(summary.retentionMissedCheckCount, 1);
    expect(summary.reminderScheduledFromRetentionCount, 1);
  });
}