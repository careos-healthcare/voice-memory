import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../timeline/timeline_entry_display.dart';
import 'belief_update_payoff.dart';
import 'context_aware_archive_copy.dart';

/// Route for the weekly archive review screen.
abstract final class WeeklyArchiveReviewNavigation {
  static const route = '/weekly-archive-review';
}

/// User-facing copy for the weekly archive review.
abstract final class WeeklyArchiveReviewCopy {
  static const title = VisibleArchiveProofCopy.weeklyArchiveReviewTitle;

  static const subtitle = VisibleArchiveProofCopy.weeklyArchiveReviewSubtitle;

  static const notConclusion =
      VisibleArchiveProofCopy.weeklyArchiveReviewNotConclusion;

  static const sourceLine =
      VisibleArchiveProofCopy.weeklyArchiveReviewSourceLine;

  static const insufficientBody =
      VisibleArchiveProofCopy.weeklyArchiveReviewInsufficientBody;

  static const strongestThreadLabel =
      VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadLabel;

  static const whatChangedLabel =
      VisibleArchiveProofCopy.weeklyArchiveReviewWhatChangedLabel;

  static const evidenceLabel =
      VisibleArchiveProofCopy.weeklyArchiveReviewEvidenceLabel;

  static const stillUncertainLabel =
      VisibleArchiveProofCopy.weeklyArchiveReviewStillUncertainLabel;

  static const addNextLabel =
      VisibleArchiveProofCopy.weeklyArchiveReviewAddNextLabel;

  static const evidenceStillThin =
      VisibleArchiveProofCopy.weeklyArchiveReviewStillThin;

  static const nextDefault =
      VisibleArchiveProofCopy.weeklyArchiveReviewNextDefault;

  static const nextWhenThin =
      VisibleArchiveProofCopy.weeklyArchiveReviewNextWhenThin;

  static const primaryCta =
      VisibleArchiveProofCopy.weeklyArchiveReviewPrimaryCta;

  static const viewEvidenceCta =
      VisibleArchiveProofCopy.weeklyArchiveReviewViewEvidenceCta;

  static const viewFullCta =
      VisibleArchiveProofCopy.weeklyArchiveReviewViewFullCta;
}

/// Weekly archive review content — summary surface, not belief history.
class WeeklyArchiveReview {
  const WeeklyArchiveReview({
    required this.hasEnoughEvidence,
    required this.title,
    this.subtitle,
    this.notConclusionLine,
    this.sourceLine,
    this.strongestThreadLine,
    this.whatChangedLine,
    this.evidenceRows = const [],
    this.uncertaintyLine,
    this.nextActionLine,
    this.primaryCta,
    this.secondaryCta,
    this.insufficientBody,
    this.evidenceWeak = false,
    this.contextAwareDetailLine,
  });

  final bool hasEnoughEvidence;
  final String title;
  final String? subtitle;
  final String? notConclusionLine;
  final String? sourceLine;
  final String? strongestThreadLine;
  final String? whatChangedLine;
  final List<String> evidenceRows;
  final String? uncertaintyLine;
  final String? nextActionLine;
  final String? primaryCta;
  final String? secondaryCta;
  final String? insufficientBody;
  final bool evidenceWeak;
  final String? contextAwareDetailLine;

  factory WeeklyArchiveReview.insufficient() {
    return const WeeklyArchiveReview(
      hasEnoughEvidence: false,
      title: WeeklyArchiveReviewCopy.title,
      insufficientBody: WeeklyArchiveReviewCopy.insufficientBody,
    );
  }
}

/// Builds a cautious weekly review from journal entries — no network.
abstract final class WeeklyArchiveReviewEngine {
  WeeklyArchiveReviewEngine._();

  static const _minEligibleCount = 5;
  static const _weekWindowDays = 7;
  static const _maxSnippetLength = 80;
  static const _heuristics = ArchiveEvidenceHeuristics();

  static WeeklyArchiveReview build({required List<JournalEntry> entries}) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < _minEligibleCount) {
      return WeeklyArchiveReview.insufficient();
    }

    final payoff = BeliefUpdatePayoffEngine.build(entries: entries);
    if (payoff == null) return WeeklyArchiveReview.insufficient();

    final weekEntries = _thisWeekEntries(eligible);
    final weekAnalysis = _heuristics.analyze(weekEntries);
    final fullAnalysis = _heuristics.analyze(entries);
    final evidenceWeak = payoff.evidenceWeak;
    final evidenceRows = _evidenceRows(
      weekEntries.isNotEmpty ? weekEntries : eligible,
    );
    final contextCopy = ContextAwareArchiveCopyEngine.build(entries: entries);

    return WeeklyArchiveReview(
      hasEnoughEvidence: true,
      title: WeeklyArchiveReviewCopy.title,
      subtitle: WeeklyArchiveReviewCopy.subtitle,
      notConclusionLine: WeeklyArchiveReviewCopy.notConclusion,
      sourceLine: WeeklyArchiveReviewCopy.sourceLine,
      strongestThreadLine: _strongestThreadLine(
        weekAnalysis: weekAnalysis,
        weekEntries: weekEntries,
        eligible: eligible,
      ),
      whatChangedLine: _whatChangedLine(
        payoff: payoff,
        fullAnalysis: fullAnalysis,
        evidenceWeak: evidenceWeak,
      ),
      evidenceRows: evidenceRows,
      uncertaintyLine: evidenceWeak
          ? WeeklyArchiveReviewCopy.evidenceStillThin
          : (contextCopy.showLines ? contextCopy.summaryLine : null),
      contextAwareDetailLine: evidenceWeak ? null : contextCopy.detailLine,
      nextActionLine: evidenceWeak
          ? WeeklyArchiveReviewCopy.nextWhenThin
          : WeeklyArchiveReviewCopy.nextDefault,
      primaryCta: WeeklyArchiveReviewCopy.primaryCta,
      secondaryCta: WeeklyArchiveReviewCopy.viewEvidenceCta,
      evidenceWeak: evidenceWeak,
    );
  }

  static List<JournalEntry> _thisWeekEntries(List<JournalEntry> eligible) {
    final anchor = eligible.last.createdAt;
    final weekStart = anchor.subtract(const Duration(days: _weekWindowDays));
    final weekEntries = eligible
        .where((e) => !e.createdAt.isBefore(weekStart))
        .toList();
    if (weekEntries.length >= 2) return weekEntries;
    final fallbackCount = eligible.length >= 3 ? 3 : eligible.length;
    return eligible.sublist(eligible.length - fallbackCount);
  }

  static String _strongestThreadLine({
    required ArchiveEvidenceAnalysis weekAnalysis,
    required List<JournalEntry> weekEntries,
    required List<JournalEntry> eligible,
  }) {
    final texts = weekEntries.map(_entryText).join(' ').toLowerCase();
    if (texts.contains('work') ||
        texts.contains('office') ||
        texts.contains('deadline') ||
        texts.contains('boss')) {
      return VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadWork;
    }

    final belief = weekAnalysis.beliefLine.trim();
    if (belief.contains('say yes') || belief.contains('capacity')) {
      return VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadSayYes;
    }
    if (belief.contains('behind')) {
      return VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadBehind;
    }
    if (belief.startsWith('You may ')) {
      final rest = belief.substring(8).replaceAll(RegExp(r'\.$'), '');
      return 'Your archive appears to be starting to notice you may $rest.';
    }

    final latestText = _entryText(eligible.last).toLowerCase();
    if (latestText.contains('work') || latestText.contains('office')) {
      return VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadWork;
    }

    return VisibleArchiveProofCopy.weeklyArchiveReviewStrongestThreadDefault;
  }

  static String _whatChangedLine({
    required BeliefUpdatePayoff payoff,
    required ArchiveEvidenceAnalysis fullAnalysis,
    required bool evidenceWeak,
  }) {
    if (evidenceWeak) {
      return VisibleArchiveProofCopy.weeklyArchiveReviewWhatChangedStillThin;
    }

    final heuristic = fullAnalysis.whatChangedLine?.trim() ?? '';
    if (heuristic.contains('Last time it was about') &&
        heuristic.contains('This time it showed up around')) {
      return VisibleArchiveProofCopy.beliefUpdateChangeNewContext;
    }
    if (heuristic.contains('noticed it earlier')) {
      return heuristic;
    }
    if (payoff.whatChangedLine ==
        VisibleArchiveProofCopy.beliefUpdateChangeDifferentWords) {
      return payoff.whatChangedLine;
    }
    if (payoff.whatChangedLine !=
            VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare &&
        payoff.whatChangedLine.isNotEmpty) {
      return payoff.whatChangedLine;
    }
    return VisibleArchiveProofCopy.weeklyArchiveReviewWhatChangedDefault;
  }

  static List<String> _evidenceRows(List<JournalEntry> entries) {
    final rows = <String>[];
    for (final entry in entries.reversed) {
      final snippet = _snippet(_entryText(entry));
      if (snippet.isEmpty) continue;
      rows.add(snippet);
      if (rows.length >= 3) break;
    }
    return rows.reversed.toList();
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String _snippet(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= _maxSnippetLength) return trimmed;
    return '${trimmed.substring(0, _maxSnippetLength - 1)}…';
  }
}
