import '../../config/archive_me_demo_state.dart';
import '../../models/journal_entry.dart';
import '../../models/reflection.dart';
import '../../models/sync_status.dart';
import '../early_archive/early_evidence_timeline_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../archive_proof/archive_belief_surface.dart';
import '../comparison_engine/comparison_engine.dart';
import '../comparison_engine/comparison_engine_model.dart';
import '../tomorrow_return/watch_for_model.dart';

/// Synthetic three-moment archive for screenshot / video capture — never real
/// user data, never written to disk.
abstract final class ArchiveMeDemoArchive {
  ArchiveMeDemoArchive._();

  static const firstMomentBody =
      'I said yes again even though I was already tired from work today.';
  static const repeatedMomentBody =
      'I took responsibility again before asking anyone for help today.';
  static const confirmedRepeatBody =
      'I agreed to help again before checking whether I had capacity today.';

  static final demoNow = DateTime(2026, 6, 15, 10);

  static const _reflection = Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work', 'capacity'],
    exactLanguagePattern: 'I said yes again',
    concreteObservation: 'Saying yes showed up again before checking capacity.',
    repeatedSignal: 'saying yes before ready',
  );

  static List<JournalEntry> journalEntries({DateTime? now}) {
    final anchor = now ?? demoNow;
    JournalEntry entry({
      required String suffix,
      required int daysAgo,
      required String transcript,
    }) {
      return JournalEntry(
        id: '${ArchiveMeDemoState.entryIdPrefix}$suffix',
        createdAt: anchor.subtract(Duration(days: daysAgo, hours: 2)),
        transcript: transcript,
        durationSeconds: 24,
        reflection: _reflection,
        syncStatus: SyncStatus.localOnly,
      );
    }

    return [
      entry(suffix: 'first', daysAgo: 6, transcript: firstMomentBody),
      entry(suffix: 'repeat', daysAgo: 3, transcript: repeatedMomentBody),
      entry(suffix: 'confirmed', daysAgo: 0, transcript: confirmedRepeatBody),
    ];
  }

  static bool get hasConfirmedRepeat =>
      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(journalEntries());

  static bool get hasEvidenceTimeline =>
      EarlyEvidenceTimelineEngine.build(
        entries: journalEntries(),
        triggerCapturedMilestone: true,
        helpfulActionCapturedMilestone: true,
      ) !=
      null;

  static bool get hasBeliefProof =>
      const ArchiveBeliefSurfaceSource().resolve(journalEntries()).shouldShow;

  static bool get hasBeliefHeadline => const ArchiveBeliefSurfaceSource()
      .resolve(journalEntries())
      .headline
      .contains('believes');

  static WatchForItem reviewerWatchTarget({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final entries = journalEntries(now: clock);
    return WatchForItem(
      id: '${ArchiveMeDemoState.entryIdPrefix}watch_target',
      createdAt: clock,
      targetDate: WatchForItem.dateOnly(clock),
      sourceReflectionId: entries.last.id,
      text: 'saying yes before checking capacity',
      chips: const ['capacity', 'saying yes'],
      status: WatchForStatus.pending,
      result: WatchForResult.none,
      shortPrompt: 'saying yes before checking capacity',
      specificPrompt:
          'Notice whether you say yes before checking your capacity.',
      checkInQuestion: 'Did you notice the pressure before agreeing this time?',
      promptStrength: 'strong',
    );
  }

  static ComparisonEngineResult get reviewerComparison =>
      const ComparisonEngine().build(journalEntries());

  static bool get hasGeneratedComparison =>
      reviewerComparison.hasComparison &&
      reviewerComparison.isRelated &&
      reviewerComparison.output?.hasRequiredEvidenceQuotes == true;

  static bool get enginesReady =>
      hasConfirmedRepeat &&
      hasEvidenceTimeline &&
      hasBeliefProof &&
      hasGeneratedComparison;
}
