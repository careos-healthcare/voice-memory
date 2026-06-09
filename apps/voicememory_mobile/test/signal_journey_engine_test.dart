import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_coordinator.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_engine.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_store.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_signal_journey_journal_$stamp.json',
    prefsPath: '/tmp/vm_signal_journey_prefs_$stamp.json',
  );
}

SignalJourneyAcceptInput _acceptInput({
  String signalId = 'sig1',
  String? entryId,
}) {
  return SignalJourneyAcceptInput(
    signalId: signalId,
    signalTitle: 'Saying yes before checking capacity',
    nextPrompt: 'When did you last say yes while already stretched?',
    readId: 'read_pressure',
    categoryId: 'pressure',
    entryId: entryId,
    wouldConfirm: 'Another moment where you say yes while already full.',
    wouldChallenge: 'Moments where you pause before answering.',
    evidenceSummary: 'You mentioned pressure and saying yes.',
  );
}

void main() {
  test('journey created when signal accepted', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final journey = await SignalJourneyCoordinator.onSignalAccepted(
      _acceptInput(entryId: 'e1'),
    );

    expect(journey, isNotNull);
    expect(journey!.signalTitle, contains('Saying yes'));
    expect(journey.supportingMomentIds, ['e1']);
    expect(journey.status, SignalJourneyStatus.collectingEvidence);
  });

  test('journey not created when Not me without existing journey', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final result = await SignalJourneyCoordinator.onSignalRejected(
      signalId: 'sig1',
      signalTitle: 'Saying yes before checking capacity',
      entryId: 'e1',
    );

    expect(result, isNull);
    expect(await SignalJourneyCoordinator.loadActive(), isNull);
  });

  test('evidence count increments on repeat accept', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalJourneyCoordinator.onSignalAccepted(_acceptInput(entryId: 'e1'));
    final updated = await SignalJourneyCoordinator.onSignalAccepted(
      _acceptInput(entryId: 'e2'),
    );

    expect(updated!.supportingCount, 2);
    expect(updated.status, SignalJourneyStatus.gettingClearer);
  });

  test('status moves 1/3 → 2/3 → 3/3', () async {
    const engine = SignalJourneyEngine();

    expect(
      engine.statusFor(supportingCount: 1, contradictionCount: 0, archived: false),
      SignalJourneyStatus.collectingEvidence,
    );
    expect(
      engine.statusFor(supportingCount: 2, contradictionCount: 0, archived: false),
      SignalJourneyStatus.gettingClearer,
    );
    expect(
      engine.statusFor(supportingCount: 3, contradictionCount: 0, archived: false),
      SignalJourneyStatus.confirmedPattern,
    );
  });

  test('contradiction changes status', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalJourneyCoordinator.onSignalAccepted(_acceptInput(entryId: 'e1'));
    await SignalJourneyCoordinator.onSignalRejected(
      signalId: 'sig1',
      readId: 'read_pressure',
      categoryId: 'pressure',
      signalTitle: 'Saying yes before checking capacity',
      entryId: 'c1',
    );
    final journey = await SignalJourneyCoordinator.onSignalRejected(
      signalId: 'sig1',
      readId: 'read_pressure',
      categoryId: 'pressure',
      signalTitle: 'Saying yes before checking capacity',
      entryId: 'c2',
    );

    expect(journey!.status, SignalJourneyStatus.contradicted);
    expect(journey.contradictionCount, 2);
  });

  test('paywall gates long-term archive after one completed journey', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalJourneyCoordinator.shouldGateLongTermArchive(entitlements: null),
      isFalse,
    );

    await SignalJourneyCoordinator.onSignalAccepted(_acceptInput(entryId: 'e1'));
    await SignalJourneyCoordinator.onSignalAccepted(_acceptInput(entryId: 'e2'));
    await SignalJourneyCoordinator.onSignalAccepted(_acceptInput(entryId: 'e3'));

    final store = SignalJourneyStore.instance();
    await store.archiveToHistory(
      (await SignalJourneyCoordinator.loadActive())!,
    );

    expect(
      await SignalJourneyCoordinator.shouldGateLongTermArchive(entitlements: null),
      isTrue,
    );
  });

  test('copy constants avoid banned phrases', () {
    const banned = ['diagnosis', 'therapy', 'coach', 'AI friend', 'VoiceMemory'];
    final copy = [
      ConsumerUiCopy.signalJourneyTitle,
      ConsumerUiCopy.signalJourneyCompletionTitle,
      ConsumerUiCopy.signalJourneyStatusConfirmed,
    ].join(' ').toLowerCase();
    for (final phrase in banned) {
      expect(copy, isNot(contains(phrase.toLowerCase())));
    }
  });
}
