import 'package:archiveme_mobile/features/activation/first_three_journey_model.dart';
import 'package:archiveme_mobile/features/activation/first_three_session_copy.dart';
import 'package:archiveme_mobile/features/activation/first_three_session_gates.dart';
import 'package:archiveme_mobile/features/activation/second_session_payoff.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Builds copy and step state for the first-three reflections journey.
class FirstThreeJourneyEngine {
  const FirstThreeJourneyEngine();

  FirstThreeJourneyModel build({
    required int reflectionCount,
    List<JournalEntry> entries = const [],
    ActivePatternThread? activeThread,
    ReturnComparison? latestComparison,
  }) {
    final count = reflectionCount.clamp(0, 99);
    if (count >= FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return _complete(
        count,
        entries: entries,
        activeThread: activeThread,
        latestComparison: latestComparison,
      );
    }
    if (count == 2) {
      return _stepTwo(count, entries: entries);
    }
    if (count == 1) {
      return _stepOne(count);
    }
    return _stepZero(count);
  }

  int journeyStepIndexForCount(int reflectionCount) {
    if (reflectionCount <= 0) return 0;
    if (reflectionCount < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return 1;
    }
    return 2;
  }

  bool hasRepeatMatch({
    required List<JournalEntry> entries,
    ActivePatternThread? activeThread,
  }) {
    if (entries.length < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return false;
    }
    if (activeThread != null && activeThread.title.trim().isNotEmpty) {
      return true;
    }

    const engine = SecondSessionSignalEngine();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return false;

    final windowStart = eligible.length >= 3 ? eligible.length - 3 : 0;
    for (var i = windowStart; i < eligible.length - 1; i++) {
      if (engine.hasGroundedRepeatMatch(eligible.sublist(i, i + 2))) {
        return true;
      }
    }
    return false;
  }

  FirstThreeJourneyModel _stepZero(int count) {
    return const FirstThreeJourneyModel(
      reflectionCount: 0,
      currentStep: FirstThreeJourneyStep.one,
      title: FirstThreeSessionCopy.session0Title,
      body: ConsumerUiCopy.patternsEarlyStateBody,
      progressLabel: FirstThreeSessionCopy.journeyStep1,
      nextAction: 'Record one moment',
      completed: false,
    );
  }

  FirstThreeJourneyModel _stepOne(int count) {
    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.two,
      title: FirstThreeSessionCopy.session1CardTitle,
      body: FirstThreeSessionCopy.session1CardBody,
      progressLabel: FirstThreeSessionCopy.journeyStep2,
      nextAction: FirstThreeSessionCopy.session1NextAction,
      completed: false,
      journeyStepIndex: 1,
    );
  }

  FirstThreeJourneyModel _stepTwo(
    int count, {
    List<JournalEntry> entries = const [],
  }) {
    final payoff = SecondSessionPayoffEngine.build(entries: entries);
    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.three,
      title:
          payoff?.title ?? FirstThreeSessionCopy.session2StartingToNoticeTitle,
      body: payoff?.body ?? FirstThreeSessionCopy.session2StartingToNoticeBody,
      progressLabel: FirstThreeSessionCopy.journeyStep2,
      nextAction: FirstThreeSessionCopy.session2NextAction,
      completed: false,
      journeyStepIndex: 1,
    );
  }

  FirstThreeJourneyModel _complete(
    int count, {
    required List<JournalEntry> entries,
    ActivePatternThread? activeThread,
    ReturnComparison? latestComparison,
  }) {
    final repeatMatch = hasRepeatMatch(
      entries: entries,
      activeThread: activeThread,
    );

    var title = FirstThreeSessionCopy.session3Title;
    var body = FirstThreeSessionCopy.session3HonestMoment;

    if (repeatMatch) {
      title = FirstThreeSessionCopy.session2RepeatTitle;
      final signal = const SecondSessionSignalEngine().build(entries);
      if (signal.body.trim().isNotEmpty) {
        body = signal.body.trim();
      } else {
        body = ConsumerUiCopy.secondSessionSoundsClose;
      }
    } else if (activeThread != null && activeThread.title.trim().isNotEmpty) {
      body =
          '${FirstThreeSessionCopy.session3KeepsReturning} '
          '“${activeThread.title.trim()}” may keep showing up across your moments.';
    } else if (latestComparison != null &&
        latestComparison.body.trim().isNotEmpty) {
      body = latestComparison.body.trim();
    }

    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.complete,
      title: title,
      body: body,
      progressLabel: FirstThreeSessionCopy.journeyStep3,
      nextAction: 'View archive',
      completed: true,
      journeyStepIndex: 2,
    );
  }
}