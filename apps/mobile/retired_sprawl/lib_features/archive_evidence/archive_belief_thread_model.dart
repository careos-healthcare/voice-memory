import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';

/// A repeated thread surfaced from the user's own saved evidence.
class ArchiveBeliefThread {
  const ArchiveBeliefThread({
    required this.hasEnoughData,
    required this.suggestionId,
    required this.currentBelief,
    required this.evidenceLine,
    required this.whatChanged,
    required this.whatToTest,
    required this.timeline,
    this.worthWatchingLine,
    this.previousBeliefLine,
    this.whatReturnedLine,
    this.whatFadedLine,
    this.confidenceBand,
    this.evidenceSnippets = const [],
    this.isProDepth = false,
  });

  final bool hasEnoughData;
  final String suggestionId;
  final String currentBelief;
  final String evidenceLine;
  final String whatChanged;
  final String whatToTest;
  final List<ArchiveEvidenceTimelineStep> timeline;
  final String? worthWatchingLine;
  final String? previousBeliefLine;
  final String? whatReturnedLine;
  final String? whatFadedLine;
  final ArchiveConfidenceBand? confidenceBand;
  final List<String> evidenceSnippets;
  final bool isProDepth;

  static const insufficient = ArchiveBeliefThread(
    hasEnoughData: false,
    suggestionId: '',
    currentBelief: '',
    evidenceLine: '',
    whatChanged: '',
    whatToTest: '',
    timeline: [],
  );
}

class ArchiveEvidenceTimelineStep {
  const ArchiveEvidenceTimelineStep({required this.label, required this.body});

  final String label;
  final String body;
}

/// Strongest evidence-backed moment for Patterns — show at most one.
class ArchiveOhWowMoment {
  const ArchiveOhWowMoment({
    required this.hasMoment,
    required this.kind,
    required this.title,
    required this.body,
    required this.suggestionId,
  });

  final bool hasMoment;
  final ArchiveOhWowKind kind;
  final String title;
  final String body;
  final String suggestionId;

  static const none = ArchiveOhWowMoment(
    hasMoment: false,
    kind: ArchiveOhWowKind.currentBelief,
    title: '',
    body: '',
    suggestionId: '',
  );
}

/// Weekly what-changed review built from journal evidence.
class WeeklyWhatChangedReview {
  const WeeklyWhatChangedReview({
    required this.hasReview,
    required this.whatKeptReturning,
    required this.whatChanged,
    required this.whatToTestNext,
    this.whatFaded,
    this.isProDepth = false,
  });

  final bool hasReview;
  final String whatKeptReturning;
  final String whatChanged;
  final String whatToTestNext;
  final String? whatFaded;
  final bool isProDepth;

  static const insufficient = WeeklyWhatChangedReview(
    hasReview: false,
    whatKeptReturning: '',
    whatChanged: '',
    whatToTestNext: '',
  );
}