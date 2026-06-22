import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../timeline/timeline_entry_display.dart';
import '../voice_capture/voice_capture_copy.dart';

/// User-facing copy for the four-plus entry belief update payoff.
abstract final class BeliefUpdatePayoffCopy {
  static const title = VisibleArchiveProofCopy.beliefUpdateTitle;

  static const bodyChanged = VisibleArchiveProofCopy.beliefUpdateBodyChanged;

  static const bodyStillBuilding =
      VisibleArchiveProofCopy.beliefUpdateBodyStillBuilding;

  static const currentBeliefLabel =
      VisibleArchiveProofCopy.beliefUpdateCurrentBeliefLabel;

  static const evidenceLabel = VisibleArchiveProofCopy.beliefUpdateEvidenceLabel;

  static const whatChangedLabel =
      VisibleArchiveProofCopy.beliefUpdateWhatChangedLabel;

  static const primaryCta = VisibleArchiveProofCopy.beliefUpdatePrimaryCta;

  static const secondaryCta = VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta;

  static const analysisDeferredFootnote = VoiceCaptureCopy.analysisUnavailableNote;
}

/// Cautious belief-update payoff when the archive reaches four or more usable moments.
class BeliefUpdatePayoff {
  const BeliefUpdatePayoff({
    required this.title,
    required this.body,
    required this.currentBelief,
    required this.evidenceRows,
    required this.whatChangedLine,
    required this.beliefChanged,
    required this.evidenceWeak,
    required this.primaryCta,
    required this.secondaryCta,
    this.footnoteLine,
  });

  final String title;
  final String body;
  final String currentBelief;
  final List<String> evidenceRows;
  final String whatChangedLine;
  final bool beliefChanged;
  final bool evidenceWeak;
  final String primaryCta;
  final String secondaryCta;
  final String? footnoteLine;
}

/// Deterministic belief-update payoff — grounded in saved words only.
abstract final class BeliefUpdatePayoffEngine {
  BeliefUpdatePayoffEngine._();

  static const _minEligibleCount = 4;
  static const _maxSnippetLength = 80;
  static const _minDistinctSnippetLength = 36;
  static const _heuristics = ArchiveEvidenceHeuristics();

  /// Returns null unless at least four eligible entries exist.
  static BeliefUpdatePayoff? build({
    required List<JournalEntry> entries,
    bool analysisSucceeded = true,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < _minEligibleCount) return null;

    final analysis = _heuristics.analyze(entries);
    if (analysis.beliefLine.trim().isEmpty) return null;

    final evidenceRows = _evidenceRows(eligible);
    if (evidenceRows.length < 2) return null;

    final evidenceWeak = _isEvidenceWeak(eligible, evidenceRows);
    final beliefChanged = _beliefChanged(
      analysis: analysis,
      eligible: eligible,
      evidenceWeak: evidenceWeak,
    );

    return BeliefUpdatePayoff(
      title: BeliefUpdatePayoffCopy.title,
      body: beliefChanged
          ? BeliefUpdatePayoffCopy.bodyChanged
          : BeliefUpdatePayoffCopy.bodyStillBuilding,
      currentBelief: _currentBeliefLine(analysis, eligible),
      evidenceRows: evidenceRows,
      whatChangedLine: _whatChangedLine(
        analysis: analysis,
        eligible: eligible,
        beliefChanged: beliefChanged,
        evidenceWeak: evidenceWeak,
      ),
      beliefChanged: beliefChanged,
      evidenceWeak: evidenceWeak,
      primaryCta: BeliefUpdatePayoffCopy.primaryCta,
      secondaryCta: BeliefUpdatePayoffCopy.secondaryCta,
      footnoteLine:
          analysisSucceeded ? null : BeliefUpdatePayoffCopy.analysisDeferredFootnote,
    );
  }

  static List<String> _evidenceRows(List<JournalEntry> eligible) {
    final rows = <String>[];
    for (final entry in eligible.reversed) {
      final snippet = _snippet(_entryText(entry));
      if (snippet.isEmpty) continue;
      rows.add(snippet);
      if (rows.length >= 3) break;
    }
    return rows.reversed.toList();
  }

  static bool _isEvidenceWeak(
    List<JournalEntry> eligible,
    List<String> evidenceRows,
  ) {
    if (_hasDuplicatedEvidence(eligible)) return true;
    if (evidenceRows.length < 2) return true;
    if (eligible.every(
      (entry) => _entryText(entry).length < _minDistinctSnippetLength,
    )) {
      return true;
    }
    return false;
  }

  static bool _beliefChanged({
    required ArchiveEvidenceAnalysis analysis,
    required List<JournalEntry> eligible,
    required bool evidenceWeak,
  }) {
    if (evidenceWeak) return false;

    if (eligible.length >= _minEligibleCount) {
      final prior = eligible.sublist(0, eligible.length - 1);
      final priorAnalysis = _heuristics.analyze(prior);
      if (_normalize(priorAnalysis.beliefLine) !=
          _normalize(analysis.beliefLine)) {
        return true;
      }
    }

    final whatChanged = analysis.whatChangedLine?.trim() ?? '';
    if (whatChanged.isNotEmpty &&
        whatChanged !=
            'Your latest moment may sit differently from the one before it.') {
      return true;
    }

    return analysis.possibleRepeat;
  }

  static String _currentBeliefLine(
    ArchiveEvidenceAnalysis analysis,
    List<JournalEntry> eligible,
  ) {
    final latest = eligible.last;
    final lower = latest.transcript.toLowerCase();
    if (lower.contains('work') ||
        lower.contains('office') ||
        lower.contains('deadline') ||
        lower.contains('boss')) {
      return VisibleArchiveProofCopy.beliefUpdateWorkBelief;
    }

    final belief = analysis.beliefLine.trim();
    if (belief.contains('say yes') || belief.contains('capacity')) {
      return 'Your archive is beginning to associate this with pressure '
          'around saying yes.';
    }
    if (belief.contains('behind')) {
      return 'Your archive is beginning to associate this with pressure '
          'around not falling behind.';
    }
    if (belief.startsWith('You may ')) {
      final rest = belief.substring(8).replaceAll(RegExp(r'\.$'), '');
      return 'Your archive is beginning to notice you may $rest.';
    }
    if (belief.startsWith('The pressure may return')) {
      return 'Your archive is beginning to notice ${belief[0].toLowerCase()}'
          '${belief.substring(1)}';
    }
    return VisibleArchiveProofCopy.beliefUpdateDefaultBelief;
  }

  static String _whatChangedLine({
    required ArchiveEvidenceAnalysis analysis,
    required List<JournalEntry> eligible,
    required bool beliefChanged,
    required bool evidenceWeak,
  }) {
    if (evidenceWeak || !beliefChanged) {
      return VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare;
    }

    final heuristic = analysis.whatChangedLine?.trim() ?? '';
    if (heuristic.contains('Last time it was about') &&
        heuristic.contains('This time it showed up around')) {
      return VisibleArchiveProofCopy.beliefUpdateChangeNewContext;
    }
    if (heuristic.contains('echo') ||
        heuristic.contains('different') ||
        _latestUsesDifferentWords(eligible)) {
      return VisibleArchiveProofCopy.beliefUpdateChangeDifferentWords;
    }
    if (heuristic.isNotEmpty &&
        heuristic !=
            'Your latest moment may sit differently from the one before it.') {
      return heuristic;
    }
    return VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare;
  }

  static bool _latestUsesDifferentWords(List<JournalEntry> eligible) {
    if (eligible.length < 2) return false;
    final prior = _normalize(_entryText(eligible[eligible.length - 2]));
    final latest = _normalize(_entryText(eligible.last));
    if (prior.isEmpty || latest.isEmpty) return false;
    final priorTokens = prior.split(' ').where((w) => w.length > 4).toSet();
    final latestTokens = latest.split(' ').where((w) => w.length > 4).toSet();
    if (priorTokens.isEmpty || latestTokens.isEmpty) return false;
    final overlap = priorTokens.intersection(latestTokens).length /
        priorTokens.union(latestTokens).length;
    return overlap >= 0.15 && overlap < 0.55;
  }

  static bool _hasDuplicatedEvidence(List<JournalEntry> eligible) {
    final seen = <String>{};
    for (final entry in eligible) {
      final normalized = _normalize(_entryText(entry));
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) return true;
    }
    return false;
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
