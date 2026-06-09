import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_engine.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

JournalEntry entry(String id, String text) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 1),
    transcript: text,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: text,
      repeatedSignal: '',
    ),
  );
}

SignalJourney journey({int supporting = 3, List<String>? contradicting}) {
  return SignalJourney(
    id: 'j1',
    signalId: 'sig1',
    signalTitle: 'Saying yes before checking capacity',
    status: SignalJourneyStatus.confirmedPattern,
    evidenceCount: supporting,
    targetEvidenceCount: 3,
    acceptedReadCount: supporting,
    rejectedReadCount: 0,
    contradictionCount: contradicting?.length ?? 0,
    startedAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 3),
    nextPrompt: 'When did you last say yes while already stretched?',
    supportingMomentIds: List.generate(supporting, (i) => 'e$i'),
    contradictingMomentIds: contradicting ?? const [],
    wouldConfirm: 'Another moment where you say yes while already full.',
    wouldChallenge: 'Moments where you pause before answering.',
    evidenceSummary: 'You mentioned pressure and saying yes.',
  );
}

SelectedSignalRecord _signal() {
  return SelectedSignalRecord(
    id: 'sig1',
    title: 'Saying yes before checking capacity',
    categoryId: 'pressure',
    strengthLabel: 'Possible repeat',
    nextPrompt: 'When did you last say yes while already stretched?',
    savedAt: DateTime(2026, 6, 1),
    wouldContradict: 'Moments where you pause before answering.',
  );
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_signal_review_journal_$stamp.json',
    prefsPath: '/tmp/vm_signal_review_prefs_$stamp.json',
  );
}

void main() {
  const engine = SignalReviewEngine();

  test('no review below 3 evidence items', () {
    final review = engine.build(
      journey: journey(supporting: 2),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
      ],
    );
    expect(review, isNull);
  });

  test('review created at 3 supporting evidence items', () {
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
      selectedSignal: _signal(),
    );

    expect(review, isNotNull);
    expect(review!.reviewStatus, SignalReviewStatus.ready);
    expect(review.evidenceCount, 3);
    expect(review.evidenceLines.length, greaterThanOrEqualTo(2));
  });

  test('review uses journey evidence excerpts', () {
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
    );

    expect(review!.evidenceLines.any((l) => l.contains('stretched')), isTrue);
    expect(review.whatRepeated, contains('Saying yes'));
  });

  test('weak evidence does not overclaim', () {
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'short'),
        entry('e1', 'tiny'),
        entry('e2', 'x'),
      ],
    );

    expect(review!.needsMoreEvidence, isTrue);
    expect(review.reviewStatus, SignalReviewStatus.draft);
    expect(review.whatRepeated, isEmpty);
  });

  test('correction alternatives come from feedback', () {
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
    )!;

    final alts = engine.correctionAlternatives(
      review: review,
      feedback: [
        PostSaveSignalFeedback(
          id: 'f1',
          signalId: 'sig1',
          signalTitle: 'Carrying responsibility alone',
          action: PostSaveSignalAction.rejected,
          createdAt: DateTime(2026, 6, 2),
        ),
      ],
    );

    expect(alts, contains('Carrying responsibility alone'));
    expect(alts, isNot(contains(review.signalTitle)));
  });

  test('confirm pattern saves status', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final store = SignalReviewStore.instance();
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
    )!;
    await store.saveActive(review);

    final confirmed = await SignalReviewCoordinator.confirm(reviewId: review.id);
    expect(confirmed!.reviewStatus, SignalReviewStatus.confirmed);
    expect(await store.confirmedReviewCount(), 1);
  });

  test('correct this saves correction', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final store = SignalReviewStore.instance();
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
    )!;
    await store.saveActive(review);

    final corrected = await SignalReviewCoordinator.correct(
      reviewId: review.id,
      alternativeTitle: 'Carrying responsibility alone',
    );
    expect(corrected!.reviewStatus, SignalReviewStatus.corrected);
    expect(corrected.signalTitle, 'Carrying responsibility alone');
  });

  test('keep watching generates next prompt', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final store = SignalReviewStore.instance();
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes again even though I was already stretched thin.'),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
    )!;
    await store.saveActive(review);

    final watching = await SignalReviewCoordinator.keepWatching(reviewId: review.id);
    expect(watching!.reviewStatus, SignalReviewStatus.watching);
    expect(watching.nextEvidencePrompt.trim(), isNotEmpty);
  });

  test('paywall gates after first confirmed review', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalReviewCoordinator.shouldGatePremiumArchive(entitlements: null),
      isFalse,
    );

    final store = SignalReviewStore.instance();
    await store.incrementConfirmedCount();

    expect(
      await SignalReviewCoordinator.shouldGatePremiumArchive(entitlements: null),
      isTrue,
    );
  });

  test('no banned copy in signal review strings', () {
    const banned = ['therapy', 'coach', 'diagnosis', 'VoiceMemory Pro'];
    for (final s in [
      ConsumerUiCopy.signalReviewCardTitle,
      ConsumerUiCopy.signalReviewSavedCorrection,
      ConsumerUiCopy.signalReviewSavedPattern,
      ConsumerUiCopy.signalReviewWatchingSaved,
    ]) {
      for (final word in banned) {
        expect(s.toLowerCase(), isNot(contains(word)));
      }
    }
  });
}
