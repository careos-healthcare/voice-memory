import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/activation/context_aware_archive_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// User-facing copy for the five-plus entry belief history surface.
abstract final class BeliefHistoryTimelineCopy {
  static const String titleChanged = VisibleArchiveProofCopy.beliefHistoryTitleChanged;

  static const String bodyChanged = VisibleArchiveProofCopy.beliefHistoryBodyChanged;

  static const String titleBuilding =
      VisibleArchiveProofCopy.beliefHistoryTitleBuilding;

  static const String bodyNotChanged =
      VisibleArchiveProofCopy.beliefHistoryBodyNotChanged;

  static const String earlierBeliefLabel =
      VisibleArchiveProofCopy.beliefHistoryEarlierBeliefLabel;

  static const String currentBeliefLabel =
      VisibleArchiveProofCopy.beliefHistoryCurrentBeliefLabel;

  static const String whatChangedLabel =
      VisibleArchiveProofCopy.beliefHistoryWhatChangedLabel;

  static const String evidenceLabel =
      VisibleArchiveProofCopy.beliefHistoryEvidenceLabel;
}

/// Cautious belief history when the archive reaches five or more usable moments.
class BeliefHistoryTimeline {
  const BeliefHistoryTimeline({
    required this.title,
    required this.body,
    required this.earlierBelief,
    required this.currentBelief,
    required this.whatChangedLine,
    required this.evidenceRows,
    required this.hasMeaningfulChange,
    required this.evidenceWeak,
    this.contextAwareSummaryLine,
    this.contextAwareDetailLine,
  });

  final String title;
  final String body;
  final String earlierBelief;
  final String currentBelief;
  final String whatChangedLine;
  final List<String> evidenceRows;
  final bool hasMeaningfulChange;
  final bool evidenceWeak;
  final String? contextAwareSummaryLine;
  final String? contextAwareDetailLine;
}

/// Deterministic belief history — grounded in saved words only.
abstract final class BeliefHistoryTimelineEngine {
  BeliefHistoryTimelineEngine._();

  static const _minEligibleCount = 5;
  static const _maxSnippetLength = 80;
  static const _heuristics = ArchiveEvidenceHeuristics();

  /// Returns null unless at least five eligible entries exist.
  static BeliefHistoryTimeline? build({required List<JournalEntry> entries}) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < _minEligibleCount) return null;

    final currentPayoff = BeliefUpdatePayoffEngine.build(entries: entries);
    if (currentPayoff == null) return null;

    final priorEntries = eligible.sublist(0, eligible.length - 1);
    final priorPayoff = BeliefUpdatePayoffEngine.build(entries: priorEntries);
    if (priorPayoff == null) return null;

    final fullAnalysis = _heuristics.analyze(entries);
    final priorAnalysis = _heuristics.analyze(priorEntries);

    final evidenceWeak = currentPayoff.evidenceWeak;
    final contextExpanded = _contextExpanded(
      priorEntries: priorEntries,
      allEntries: eligible,
    );
    final beliefsDiffer =
        _normalize(priorPayoff.currentBelief) !=
        _normalize(currentPayoff.currentBelief);

    final hasMeaningfulChange =
        !evidenceWeak &&
        (beliefsDiffer ||
            currentPayoff.beliefChanged ||
            contextExpanded ||
            _hasGroundedWhatChanged(fullAnalysis));

    final earlierBelief = _earlierBeliefLine(
      priorPayoff: priorPayoff,
      priorAnalysis: priorAnalysis,
      contextExpanded: contextExpanded,
      hasMeaningfulChange: hasMeaningfulChange,
    );
    final currentBelief = _currentBeliefLine(
      currentPayoff: currentPayoff,
      contextExpanded: contextExpanded,
      hasMeaningfulChange: hasMeaningfulChange,
    );

    return _applyContextAware(
      BeliefHistoryTimeline(
        title: hasMeaningfulChange
            ? BeliefHistoryTimelineCopy.titleChanged
            : BeliefHistoryTimelineCopy.titleBuilding,
        body: hasMeaningfulChange
            ? (contextExpanded
                  ? BeliefHistoryTimelineCopy.bodyChanged
                  : _bodyWhenChanged(currentPayoff))
            : BeliefHistoryTimelineCopy.bodyNotChanged,
        earlierBelief: earlierBelief,
        currentBelief: currentBelief,
        whatChangedLine: _whatChangedLine(
          currentPayoff: currentPayoff,
          fullAnalysis: fullAnalysis,
          hasMeaningfulChange: hasMeaningfulChange,
          evidenceWeak: evidenceWeak,
        ),
        evidenceRows: _changeEvidenceRows(eligible),
        hasMeaningfulChange: hasMeaningfulChange,
        evidenceWeak: evidenceWeak,
      ),
      entries,
    );
  }

  static BeliefHistoryTimeline _applyContextAware(
    BeliefHistoryTimeline timeline,
    List<JournalEntry> entries,
  ) {
    final contextCopy = ContextAwareArchiveCopyEngine.build(entries: entries);
    if (!contextCopy.showLines) return timeline;
    return BeliefHistoryTimeline(
      title: timeline.title,
      body: timeline.body,
      earlierBelief: timeline.earlierBelief,
      currentBelief: timeline.currentBelief,
      whatChangedLine: timeline.whatChangedLine,
      evidenceRows: timeline.evidenceRows,
      hasMeaningfulChange: timeline.hasMeaningfulChange,
      evidenceWeak: timeline.evidenceWeak,
      contextAwareSummaryLine: contextCopy.summaryLine,
      contextAwareDetailLine: contextCopy.detailLine,
    );
  }

  static bool _contextExpanded({
    required List<JournalEntry> priorEntries,
    required List<JournalEntry> allEntries,
  }) {
    final priorContexts = _contextsFor(priorEntries);
    final allContexts = _contextsFor(allEntries);
    if (priorContexts.length == 1 && allContexts.length >= 2) return true;

    final latest = allEntries.last;
    final latestText = _entryText(latest).toLowerCase();
    final priorText = priorEntries.map(_entryText).join(' ').toLowerCase();

    final latestContexts = _contextsInText(latestText);
    for (final context in latestContexts) {
      if (!priorText.contains(context)) return true;
    }
    return false;
  }

  static Set<String> _contextsFor(List<JournalEntry> entries) {
    final contexts = <String>{};
    for (final entry in entries) {
      if (entry.captureContextTag case final tag?) {
        contexts.add(tag);
      }
      contexts.addAll(_contextsInText(_entryText(entry).toLowerCase()));
    }
    return contexts;
  }

  static Set<String> _contextsInText(String text) {
    final contexts = <String>{};
    if (text.contains('work') ||
        text.contains('office') ||
        text.contains('deadline') ||
        text.contains('boss')) {
      contexts.add('work');
    }
    if (text.contains('home') ||
        text.contains('family') ||
        text.contains('partner') ||
        text.contains('parent')) {
      contexts.add('home');
    }
    if (text.contains('rest') ||
        text.contains('sleep') ||
        text.contains('tired') ||
        text.contains('exhausted')) {
      contexts.add('rest');
    }
    return contexts;
  }

  static bool _hasGroundedWhatChanged(ArchiveEvidenceAnalysis analysis) {
    final line = analysis.whatChangedLine?.trim() ?? '';
    if (line.isEmpty) return false;
    if (line ==
        'Your latest moment may sit differently from the one before it.') {
      return false;
    }
    return line.contains('Last time it was about') ||
        line.contains('This time it showed up around') ||
        line.contains('noticed it earlier') ||
        line.contains('different words');
  }

  static String _earlierBeliefLine({
    required BeliefUpdatePayoff priorPayoff,
    required ArchiveEvidenceAnalysis priorAnalysis,
    required bool contextExpanded,
    required bool hasMeaningfulChange,
  }) {
    if (contextExpanded && hasMeaningfulChange) {
      return VisibleArchiveProofCopy.beliefHistoryEarlierOneMoment;
    }
    return priorPayoff.currentBelief;
  }

  static String _currentBeliefLine({
    required BeliefUpdatePayoff currentPayoff,
    required bool contextExpanded,
    required bool hasMeaningfulChange,
  }) {
    if (contextExpanded && hasMeaningfulChange) {
      return VisibleArchiveProofCopy.beliefHistoryCurrentMultiContext;
    }
    return currentPayoff.currentBelief;
  }

  static String _bodyWhenChanged(BeliefUpdatePayoff currentPayoff) {
    if (currentPayoff.beliefChanged) {
      return BeliefUpdatePayoffCopy.bodyChanged;
    }
    return VisibleArchiveProofCopy.beliefHistoryBodyChanged;
  }

  static String _whatChangedLine({
    required BeliefUpdatePayoff currentPayoff,
    required ArchiveEvidenceAnalysis fullAnalysis,
    required bool hasMeaningfulChange,
    required bool evidenceWeak,
  }) {
    if (evidenceWeak || !hasMeaningfulChange) {
      return VisibleArchiveProofCopy.beliefHistoryWhatChangedStillThin;
    }

    final heuristic = fullAnalysis.whatChangedLine?.trim() ?? '';
    if (heuristic.contains('Last time it was about') &&
        heuristic.contains('This time it showed up around')) {
      return VisibleArchiveProofCopy.beliefUpdateChangeNewContext;
    }
    if (heuristic.contains('noticed it earlier')) {
      return heuristic;
    }
    if (currentPayoff.whatChangedLine ==
        VisibleArchiveProofCopy.beliefUpdateChangeDifferentWords) {
      return currentPayoff.whatChangedLine;
    }
    if (currentPayoff.whatChangedLine !=
            VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare &&
        currentPayoff.whatChangedLine.isNotEmpty) {
      return currentPayoff.whatChangedLine;
    }
    return VisibleArchiveProofCopy.beliefHistoryWhatChangedDefault;
  }

  static List<String> _changeEvidenceRows(List<JournalEntry> eligible) {
    final rows = <String>[];
    for (final entry in eligible.reversed) {
      final snippet = FactLedgerCitationService.resolvedSnippet(
        entryId: entry.id,
        fallbackText: _entryText(entry),
        maxLength: _maxSnippetLength,
      );
      if (snippet.isEmpty) continue;
      rows.add(snippet);
      if (rows.length >= 2) break;
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

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}