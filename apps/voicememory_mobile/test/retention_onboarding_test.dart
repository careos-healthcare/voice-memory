import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/retention/next_evidence_reminder_service.dart';
import 'package:voicememory_mobile/features/retention/reminder_pre_prompt_coordinator.dart';
import 'package:voicememory_mobile/features/retention/return_day_journey_engine.dart';
import 'package:voicememory_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _FakeReminderBackend implements CheckInReminderBackend {
  String? lastBody;
  String? lastTitle;

  @override
  bool get isAvailable => true;

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    lastTitle = title;
    lastBody = body;
  }
}

SignalJourney _journey({DateTime? started}) {
  return SignalJourney(
    id: 'j1',
    signalId: 'sig1',
    signalTitle: 'Saying yes before checking capacity',
    status: SignalJourneyStatus.gettingClearer,
    evidenceCount: 1,
    targetEvidenceCount: 3,
    acceptedReadCount: 1,
    rejectedReadCount: 0,
    contradictionCount: 0,
    startedAt: started ?? DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
    nextPrompt: 'When did you last say yes while already stretched?',
    supportingMomentIds: const ['e1'],
  );
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_retention_journal_$stamp.json',
    prefsPath: '/tmp/vm_retention_prefs_$stamp.json',
  );
}

void main() {
  test('return-day card appears with active journey on next day', () {
    const engine = ReturnDayJourneyEngine();
    final decision = engine.evaluate(
      journey: _journey(started: DateTime(2026, 6, 1)),
      reflectionCount: 2,
      now: DateTime(2026, 6, 2, 10),
      lastReflectionAt: DateTime(2026, 6, 1, 18),
    );
    expect(decision.showCard, isTrue);
    expect(decision.recordedToday, isFalse);
  });

  test('recorded-today state changes copy decision', () {
    const engine = ReturnDayJourneyEngine();
    final decision = engine.evaluate(
      journey: _journey(started: DateTime(2026, 6, 1)),
      reflectionCount: 2,
      now: DateTime(2026, 6, 2, 10),
      lastReflectionAt: DateTime(2026, 6, 2, 9),
    );
    expect(decision.showCard, isTrue);
    expect(decision.recordedToday, isTrue);
  });

  test('no return-day card on journey start day', () {
    const engine = ReturnDayJourneyEngine();
    final decision = engine.evaluate(
      journey: _journey(started: DateTime(2026, 6, 2)),
      reflectionCount: 1,
      now: DateTime(2026, 6, 2, 10),
    );
    expect(decision.showCard, isFalse);
  });

  test('reminder pre-prompt not offered without value moment gate', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    expect(
      await ReminderPrePromptCoordinator.shouldShow(
        ReminderPrePromptTrigger.signalAccepted,
      ),
      isTrue,
    );
    await ReminderPrePromptCoordinator.markDismissed();
    expect(
      await ReminderPrePromptCoordinator.shouldShow(
        ReminderPrePromptTrigger.signalAccepted,
      ),
      isFalse,
    );
  });

  test('next evidence reminder body does not include transcript', () {
    const long =
        'Today I said yes to another project even though I was already stretched thin and carrying too much.';
    final body = NextEvidenceReminderService.bodyFor(prompt: long);
    expect(body, contains('ArchiveMe is watching:'));
    expect(body.length, lessThan(long.length));
    expect(body, isNot(contains('stretched thin and carrying')));
  });

  test('next evidence reminder schedules with safe copy', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final fake = _FakeReminderBackend();
    CheckInReminderService.setBackendForTest(fake);

    final outcome = await NextEvidenceReminderService.schedule(
      journeyId: 'j1',
      prompt: 'Notice whether you pause before answering.',
    );

    expect(outcome, ReminderScheduleOutcome.scheduled);
    expect(fake.lastTitle, ConsumerUiCopy.nextEvidenceReminderTitle);
    expect(fake.lastBody, contains('Notice whether you pause'));
    CheckInReminderService.resetBackendForTest();
  });

  test('retention metrics increment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.onboardingCompleted,
    );
    final count = await RetentionMetricsStore.instance().count(
      RetentionMetricsTracker.onboardingCompleted,
    );
    expect(count, 1);
  });

  test('onboarding copy avoids banned terms', () {
    const banned = ['therapy', 'coach', 'diagnosis', 'AI friend', 'VoiceMemory'];
    for (final s in [
      ConsumerUiCopy.onboardingPositioningHeadline,
      ConsumerUiCopy.firstRecordingHandoffBody,
      ConsumerUiCopy.reminderPrePromptBody,
      ConsumerUiCopy.returnDayJourneyTitle,
    ]) {
      for (final word in banned) {
        expect(s.toLowerCase(), isNot(contains(word.toLowerCase())));
      }
    }
  });
}
