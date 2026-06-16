import '../../config/archive_differentiation_preview.dart';
import '../../models/journal_entry.dart';
import '../activation/first_three_session_gates.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../first_session/first_session_pattern_engine.dart';
import '../retention/second_session_signal_engine.dart';
import 'archive_belief_thread_copy.dart';
import 'archive_belief_thread_model.dart';
import 'archive_evidence_heuristics.dart';
import 'archive_intelligence_tier.dart';

/// Builds the archive belief thread card from local journal evidence only.
class ArchiveBeliefThreadEngine {
  const ArchiveBeliefThreadEngine({ArchiveEvidenceHeuristics? heuristics})
    : _heuristics = heuristics ?? const ArchiveEvidenceHeuristics();

  final ArchiveEvidenceHeuristics _heuristics;
  static const _comparisonEngine = SecondSessionSignalEngine();
  static const _patternEngine = FirstSessionPatternEngine();

  ArchiveBeliefThread build(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    if (ArchiveDifferentiationPreview.forceArchiveBelief) {
      return _preview(tier);
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);

    if (eligible.length < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      final comparison = eligible.length >= 2
          ? _comparisonEngine.build(eligible)
          : null;
      if (comparison?.possibleRepeat != true ||
          comparison?.hasEnoughData != true) {
        return ArchiveBeliefThread.insufficient;
      }
    }

    final analysis = _heuristics.analyze(entries, tier: tier);
    if (!analysis.possibleRepeat && eligible.length < 3) {
      return ArchiveBeliefThread.insufficient;
    }

    final comparison = _comparisonEngine.build(eligible);
    if (!comparison.hasEnoughData && eligible.length < 3) {
      return ArchiveBeliefThread.insufficient;
    }

    final belief = analysis.beliefLine.isNotEmpty
        ? analysis.beliefLine
        : _beliefFallback(comparison, eligible.last);

    final whatChanged = analysis.whatChangedLine?.trim().isNotEmpty == true
        ? analysis.whatChangedLine!.trim()
        : (comparison.whatChanged?.trim().isNotEmpty == true
              ? comparison.whatChanged!.trim()
              : 'Your latest moment may sit differently from the one before it.');

    final whatToTest = analysis.whatToTestLine?.trim().isNotEmpty == true
        ? analysis.whatToTestLine!.trim()
        : (comparison.whatToTestNext?.trim().isNotEmpty == true
              ? comparison.whatToTestNext!.trim()
              : 'Record another ordinary moment and notice what feels different.');

    return ArchiveBeliefThread(
      hasEnoughData: true,
      suggestionId: _suggestionId(belief),
      currentBelief: belief,
      evidenceLine: analysis.evidenceLine ?? '${eligible.length} entries point toward this.',
      whatChanged: whatChanged,
      whatToTest: whatToTest,
      timeline: _timeline(analysis, tier),
      worthWatchingLine: tier == ArchiveIntelligenceTier.freeMedium
          ? analysis.worthWatchingLine
          : null,
      previousBeliefLine: analysis.previousBeliefLine,
      whatReturnedLine: tier == ArchiveIntelligenceTier.proMax
          ? analysis.whatReturnedLine
          : null,
      whatFadedLine: tier == ArchiveIntelligenceTier.proMax
          ? analysis.whatFadedLine
          : null,
      confidenceBand: analysis.confidenceBand,
      evidenceSnippets: analysis.evidenceSnippets,
      isProDepth: tier == ArchiveIntelligenceTier.proMax,
    );
  }

  ArchiveOhWowMoment buildOhWow(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    final analysis = _heuristics.analyze(entries, tier: tier);
    if (analysis.ohWowKind == null ||
        analysis.ohWowTitle == null ||
        analysis.ohWowBody == null) {
      return ArchiveOhWowMoment.none;
    }
    return ArchiveOhWowMoment(
      hasMoment: true,
      kind: analysis.ohWowKind!,
      title: analysis.ohWowTitle!,
      body: analysis.ohWowBody!,
      suggestionId: 'oh_wow_${analysis.ohWowKind!.name}',
    );
  }

  String _beliefFallback(dynamic comparison, JournalEntry latest) {
    final latestPattern = _patternEngine.build(latest);
    if (comparison.whatRepeated?.trim().isNotEmpty == true) {
      final repeated = comparison.whatRepeated!.trim();
      if (repeated.length <= 90) return 'You may be $repeated';
    }
    final watch = latestPattern.watchForText.trim();
    if (watch.isNotEmpty) return 'You may be noticing $watch.';
    return 'Something similar may be showing up across your recent moments.';
  }

  List<ArchiveEvidenceTimelineStep> _timeline(
    ArchiveEvidenceAnalysis analysis,
    ArchiveIntelligenceTier tier,
  ) {
    final window = analysis.windowEntries;
    if (window.isEmpty) return const [];

    if (tier == ArchiveIntelligenceTier.freeMedium) {
      return [
        ArchiveEvidenceTimelineStep(
          label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
          body: _momentLabel(window.first, fallback: 'first entry'),
        ),
        if (window.length >= 2)
          ArchiveEvidenceTimelineStep(
            label: ArchiveBeliefThreadCopy.timelineReturned,
            body: analysis.possibleRepeat
                ? _momentLabel(window[1], fallback: 'second entry')
                : 'A second moment was saved.',
          ),
        const ArchiveEvidenceTimelineStep(
          label: ArchiveBeliefThreadCopy.timelineCurrentSignal,
          body: ArchiveBeliefThreadCopy.timelineCurrentSignalBody,
        ),
      ];
    }

    final steps = <ArchiveEvidenceTimelineStep>[
      ArchiveEvidenceTimelineStep(
        label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
        body: _momentLabel(window.first, fallback: 'first entry'),
      ),
    ];
    if (window.length >= 2) {
      steps.add(
        ArchiveEvidenceTimelineStep(
          label: ArchiveBeliefThreadCopy.timelineReturned,
          body: analysis.possibleRepeat
              ? _momentLabel(window[1], fallback: 'second entry')
              : 'A second moment was saved.',
        ),
      );
    }
    if (window.length >= 3) {
      steps.add(
        ArchiveEvidenceTimelineStep(
          label: ArchiveBeliefThreadCopy.timelineChanged,
          body: _momentLabel(window.last, fallback: 'latest entry'),
        ),
      );
    }
    if (analysis.whatFadedLine != null) {
      steps.add(
        ArchiveEvidenceTimelineStep(
          label: ArchiveBeliefThreadCopy.timelineWhatFaded,
          body: analysis.whatFadedLine!,
        ),
      );
    }
    steps.add(
      const ArchiveEvidenceTimelineStep(
        label: ArchiveBeliefThreadCopy.timelineCurrentSignal,
        body: ArchiveBeliefThreadCopy.timelineCurrentSignalBody,
      ),
    );
    return steps;
  }

  String _momentLabel(JournalEntry entry, {required String fallback}) {
    final pattern = _patternEngine.build(entry);
    final title = pattern.title.trim();
    if (title.isNotEmpty && title.length <= 48) return title;
    return fallback;
  }

  String _suggestionId(String belief) {
    final normalized =
        belief.toLowerCase().replaceAll(RegExp(r'\s+'), '_').trim();
    if (normalized.isEmpty) return 'archive_belief';
    return normalized.length <= 48
        ? normalized
        : normalized.substring(0, 48);
  }

  ArchiveBeliefThread _preview(ArchiveIntelligenceTier tier) {
    return ArchiveBeliefThread(
      hasEnoughData: true,
      suggestionId: 'preview_archive_belief',
      currentBelief: 'You may be doing more to avoid feeling behind.',
      evidenceLine: tier == ArchiveIntelligenceTier.proMax
          ? '5 entries across your archive point toward this.'
          : '3 entries point toward this.',
      whatChanged: 'This time, it showed up around saying yes too quickly.',
      whatToTest: 'Before agreeing, check whether you actually have capacity.',
      worthWatchingLine: tier == ArchiveIntelligenceTier.freeMedium
          ? 'This may be worth watching.'
          : null,
      previousBeliefLine: tier == ArchiveIntelligenceTier.proMax
          ? 'Your archive used to point toward work.'
          : null,
      whatReturnedLine: tier == ArchiveIntelligenceTier.proMax
          ? 'The repeated thread may be avoid feeling behind.'
          : null,
      confidenceBand: tier == ArchiveIntelligenceTier.proMax
          ? ArchiveConfidenceBand.returningThread
          : null,
      evidenceSnippets: tier == ArchiveIntelligenceTier.proMax
          ? const ['I said yes again even though I was already tired.']
          : const [],
      isProDepth: tier == ArchiveIntelligenceTier.proMax,
      timeline: tier == ArchiveIntelligenceTier.freeMedium
          ? const [
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
                body: 'first entry',
              ),
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineReturned,
                body: 'second entry',
              ),
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineCurrentSignal,
                body: ArchiveBeliefThreadCopy.timelineCurrentSignalBody,
              ),
            ]
          : const [
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
                body: 'first entry',
              ),
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineReturned,
                body: 'second entry',
              ),
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineChanged,
                body: 'latest entry',
              ),
              ArchiveEvidenceTimelineStep(
                label: ArchiveBeliefThreadCopy.timelineCurrentSignal,
                body: ArchiveBeliefThreadCopy.timelineCurrentSignalBody,
              ),
            ],
    );
  }
}

/// Weekly what-changed card from journal entries — no AI, no pressure store required.
class WeeklyWhatChangedReviewEngine {
  const WeeklyWhatChangedReviewEngine({ArchiveEvidenceHeuristics? heuristics})
    : _heuristics = heuristics ?? const ArchiveEvidenceHeuristics();

  final ArchiveEvidenceHeuristics _heuristics;
  static const _comparisonEngine = SecondSessionSignalEngine();
  static const _patternEngine = FirstSessionPatternEngine();

  WeeklyWhatChangedReview build(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    if (ArchiveDifferentiationPreview.forceWeeklyReview) {
      return _preview(tier);
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);

    if (eligible.length < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return WeeklyWhatChangedReview.insufficient;
    }

    final analysis = _heuristics.analyze(entries, tier: tier);
    final comparison = _comparisonEngine.build(eligible);
    if (!comparison.hasEnoughData) return WeeklyWhatChangedReview.insufficient;

    final latestPattern = _patternEngine.build(eligible.last);
    final keptReturning = analysis.whatReturnedLine?.trim().isNotEmpty == true
        ? analysis.whatReturnedLine!.trim()
        : (comparison.whatRepeated?.trim().isNotEmpty == true
              ? comparison.whatRepeated!.trim()
              : (latestPattern.title.trim().isNotEmpty
                    ? latestPattern.title.trim()
                    : 'Similar themes may be showing up across your recent moments.'));

    final changed = analysis.whatChangedLine?.trim().isNotEmpty == true
        ? analysis.whatChangedLine!.trim()
        : (comparison.whatChanged?.trim().isNotEmpty == true
              ? comparison.whatChanged!.trim()
              : 'You caught the pressure earlier once.');

    final next = analysis.whatToTestLine?.trim().isNotEmpty == true
        ? analysis.whatToTestLine!.trim()
        : (comparison.whatToTestNext?.trim().isNotEmpty == true
              ? comparison.whatToTestNext!.trim()
              : 'Pause before agreeing to new requests.');

    if (tier == ArchiveIntelligenceTier.freeMedium) {
      return WeeklyWhatChangedReview(
        hasReview: true,
        whatKeptReturning: _shortenFree(keptReturning),
        whatChanged: _shortenFree(changed),
        whatToTestNext: _shortenFree(next),
        isProDepth: false,
      );
    }

    return WeeklyWhatChangedReview(
      hasReview: true,
      whatKeptReturning: keptReturning,
      whatChanged: changed,
      whatToTestNext: next,
      whatFaded: analysis.whatFadedLine,
      isProDepth: true,
    );
  }

  String _shortenFree(String value) {
    if (value.length <= 120) return value;
    return '${value.substring(0, 117)}…';
  }

  WeeklyWhatChangedReview _preview(ArchiveIntelligenceTier tier) =>
      WeeklyWhatChangedReview(
        hasReview: true,
        whatKeptReturning: 'Doing more to avoid feeling behind.',
        whatChanged: 'You caught the pressure earlier once.',
        whatToTestNext: 'Pause before agreeing to new requests.',
        whatFaded: tier == ArchiveIntelligenceTier.proMax
            ? 'This has not shown up in the latest entry.'
            : null,
        isProDepth: tier == ArchiveIntelligenceTier.proMax,
      );
}
