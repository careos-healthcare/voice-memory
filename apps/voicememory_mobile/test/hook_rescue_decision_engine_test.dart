import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:voicememory_mobile/features/trial/hook_rescue_decision_engine.dart';
import 'package:voicememory_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_engine.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_rescue_journal_$stamp.json',
    prefsPath: '/tmp/vm_rescue_prefs_$stamp.json',
  );
}

HookDiagnosisEvent _missed(String reason, String id) => HookDiagnosisEvent(
      id: id,
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInMissedReason,
      reason: reason,
    );

HookDiagnosisEvent _questionRated(String rating, String id) =>
    HookDiagnosisEvent(
      id: id,
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInQuestionRated,
      rating: rating,
    );

HookDiagnosisEvent _resultRated(String rating, String id) => HookDiagnosisEvent(
      id: id,
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInResultRated,
      rating: rating,
    );

HookDiagnosisEvent _notUsefulReason(String reason, String id) =>
    HookDiagnosisEvent(
      id: id,
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInResultNotUsefulReason,
      reason: reason,
    );

void main() {
  const engine = HookRescueDecisionEngine();

  test('confusing high → guidedCheckIn primary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 2,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c1'));
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.guidedCheckIn);
    expect(decision.reason, 'People are confused by the check-in.');
  });

  test('result not useful high → betterResult primary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 2,
        tomorrowCheckInCompleted: 2,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_resultRated(HookDiagnosisRating.notReally, 'r1'));
    await hook.append(_resultRated(HookDiagnosisRating.notReally, 'r2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.betterResult);
    expect(decision.reason,
        'People return but do not find the result useful.');
  });

  test('did not care high → sharperQuestion primary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 2,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.sharperQuestion);
    expect(decision.reason, 'People do not care enough about the question.');
  });

  test('reminder ready → reminder action', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 0,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_questionRated(HookDiagnosisRating.yes, 'q1'));
    await hook.append(_questionRated(HookDiagnosisRating.sortOf, 'q2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.reminder);
    expect(decision.includes(HookRescueAction.reminder), isTrue);
    expect(decision.reason, 'People care about the question but do not return.');
  });

  test('low first save → betterFirstRecord action', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        trialRecordingStarted: 2,
        firstReflectionSaved: 0,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.betterFirstRecord);
    expect(decision.reason, 'People struggle to save the first moment.');
  });

  test('did-not-care 0.25 → sharper elevated', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 4,
        tomorrowCheckInDueShown: 4,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.sharperQuestion),
      HookRescueIntensity.elevated,
    );
  });

  test('did-not-care 0.40 → sharper aggressive', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 5,
        tomorrowCheckInDueShown: 5,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.sharperQuestion),
      HookRescueIntensity.aggressive,
    );
  });

  test('question-not-useful 0.40 → sharper aggressive', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 4,
        tomorrowCheckInDueShown: 4,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    // Triggers sharper via did-not-care 0.25, escalates via question rate 0.40.
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));
    await hook.append(_questionRated(HookDiagnosisRating.notReally, 'q1'));
    await hook.append(_questionRated(HookDiagnosisRating.notReally, 'q2'));
    await hook.append(_questionRated(HookDiagnosisRating.yes, 'q3'));
    await hook.append(_questionRated(HookDiagnosisRating.yes, 'q4'));
    await hook.append(_questionRated(HookDiagnosisRating.sortOf, 'q5'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.sharperQuestion),
      HookRescueIntensity.aggressive,
    );
  });

  test('result-not-useful 0.25 → betterResult elevated', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 4,
        tomorrowCheckInDueShown: 4,
        tomorrowCheckInCompleted: 4,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_resultRated(HookDiagnosisRating.notReally, 'r1'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.betterResult),
      HookRescueIntensity.elevated,
    );
  });

  test('result-not-useful 0.40 → betterResult aggressive', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 5,
        tomorrowCheckInDueShown: 5,
        tomorrowCheckInCompleted: 5,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_resultRated(HookDiagnosisRating.notReally, 'r1'));
    await hook.append(_resultRated(HookDiagnosisRating.notReally, 'r2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.betterResult),
      HookRescueIntensity.aggressive,
    );
  });

  test('top not-useful reason >= 2 → betterResult aggressive', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 4,
        tomorrowCheckInDueShown: 4,
        tomorrowCheckInCompleted: 4,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_notUsefulReason(HookDiagnosisNotUsefulReason.tooVague, 'n1'));
    await hook.append(_notUsefulReason(HookDiagnosisNotUsefulReason.tooVague, 'n2'));

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(
      decision.intensityFor(HookRescueAction.betterResult),
      HookRescueIntensity.aggressive,
    );
  });

  test('no signals → none', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 1,
        tomorrowCheckInDueShown: 1,
        tomorrowCheckInCompleted: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    final decision = engine.decide(summary);

    expect(decision.primaryAction, HookRescueAction.none);
  });
}
