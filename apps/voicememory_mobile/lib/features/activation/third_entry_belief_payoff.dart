import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_evidence_threshold.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../timeline/timeline_entry_display.dart';
import '../voice_capture/voice_capture_copy.dart';

/// User-facing copy for the third-entry belief payoff.
abstract final class ThirdEntryBeliefPayoffCopy {
  static const title = VisibleArchiveProofCopy.threeEntryBeliefTitle;

  static const bodyIntro = VisibleArchiveProofCopy.threeEntryBeliefBodyIntro;

  static const bodySource = VisibleArchiveProofCopy.threeEntryBeliefBodySource;

  static const evidenceLabel =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceLabel;

  static const evidenceThin =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceThin;

  static const evidenceThinAction =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceThinAction;

  static const primaryCta = VisibleArchiveProofCopy.threeEntryBeliefPrimaryCta;

  static const secondaryCta =
      VisibleArchiveProofCopy.threeEntryBeliefViewArchiveCta;

  static const analysisDeferredFootnote =
      VoiceCaptureCopy.analysisUnavailableNote;
}

/// Cautious belief payoff when the archive reaches exactly three usable moments.
class ThirdEntryBeliefPayoff {
  const ThirdEntryBeliefPayoff({
    required this.title,
    required this.bodyIntro,
    required this.bodySource,
    required this.evidenceRows,
    required this.evidenceThin,
    required this.primaryCta,
    required this.secondaryCta,
    this.thinEvidenceNote,
    this.thinEvidenceAction,
    this.footnoteLine,
    this.stageLabel,
  });

  final String title;
  final String bodyIntro;
  final String bodySource;
  final List<String> evidenceRows;
  final bool evidenceThin;
  final String primaryCta;
  final String secondaryCta;
  final String? thinEvidenceNote;
  final String? thinEvidenceAction;
  final String? footnoteLine;
  final String? stageLabel;
}

/// Deterministic third-entry belief payoff — no invented diagnoses or certainty.
abstract final class ThirdEntryBeliefPayoffEngine {
  ThirdEntryBeliefPayoffEngine._();

  static const _maxSnippetLength = 80;
  static const _minDistinctSnippetLength = 36;

  static const _heuristics = ArchiveEvidenceHeuristics();

  /// Returns null unless exactly three eligible entries exist.
  static ThirdEntryBeliefPayoff? build({
    required List<JournalEntry> entries,
    bool analysisSucceeded = true,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 3) return null;

    final evidenceRows = _evidenceRows(eligible);
    final evidenceThin = _isEvidenceThin(eligible, evidenceRows);
    final analysis = _heuristics.analyze(entries);
    final threshold = ArchiveEvidenceThreshold.evaluate(
      entries,
      analysis: analysis,
      attachedSnippets: evidenceRows,
    );
    if (!threshold.canNameThread) return null;

    return ThirdEntryBeliefPayoff(
      title: ThirdEntryBeliefPayoffCopy.title,
      bodyIntro: ThirdEntryBeliefPayoffCopy.bodyIntro,
      bodySource: ThirdEntryBeliefPayoffCopy.bodySource,
      evidenceRows: evidenceRows,
      evidenceThin: evidenceThin,
      thinEvidenceNote: evidenceThin
          ? ThirdEntryBeliefPayoffCopy.evidenceThin
          : null,
      thinEvidenceAction: evidenceThin
          ? ThirdEntryBeliefPayoffCopy.evidenceThinAction
          : null,
      primaryCta: ThirdEntryBeliefPayoffCopy.primaryCta,
      secondaryCta: ThirdEntryBeliefPayoffCopy.secondaryCta,
      footnoteLine: analysisSucceeded
          ? null
          : ThirdEntryBeliefPayoffCopy.analysisDeferredFootnote,
      stageLabel: threshold.stage.label,
    );
  }

  static List<String> _evidenceRows(List<JournalEntry> eligible) {
    final rows = <String>[];
    for (final entry in eligible) {
      final snippet = _snippet(_entryText(entry));
      if (snippet.isEmpty) continue;
      rows.add(snippet);
    }
    if (rows.length <= 3) return rows;
    return rows.sublist(rows.length - 3);
  }

  static bool _isEvidenceThin(
    List<JournalEntry> eligible,
    List<String> evidenceRows,
  ) {
    if (_hasDuplicatedEvidence(eligible)) return true;
    if (eligible.every(
      (entry) => _entryText(entry).length < _minDistinctSnippetLength,
    )) {
      return true;
    }
    if (evidenceRows.length < 2) return true;
    return false;
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
