import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_threshold.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// User-facing copy for the third-entry belief payoff.
abstract final class ThirdEntryBeliefPayoffCopy {
  static const String title = VisibleArchiveProofCopy.threeEntryBeliefTitle;

  static const String bodyIntro =
      VisibleArchiveProofCopy.threeEntryBeliefBodyIntro;

  static const String bodySource =
      VisibleArchiveProofCopy.threeEntryBeliefBodySource;

  static const String evidenceLabel =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceLabel;

  static const String evidenceThin =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceThin;

  static const String evidenceThinAction =
      VisibleArchiveProofCopy.threeEntryBeliefEvidenceThinAction;

  static const String primaryCta =
      VisibleArchiveProofCopy.threeEntryBeliefPrimaryCta;

  static const String secondaryCta =
      VisibleArchiveProofCopy.threeEntryBeliefViewArchiveCta;

  static const String analysisDeferredFootnote =
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
    this.sourceEntryIds = const [],
    this.thinEvidenceNote,
    this.thinEvidenceAction,
    this.footnoteLine,
    this.stageLabel,
  });

  final String title;
  final String bodyIntro;
  final String bodySource;
  final List<String> evidenceRows;
  final List<String> sourceEntryIds;
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

    final evidence = _evidenceCitations(eligible);
    final evidenceRows = evidence.rows;
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
      sourceEntryIds: evidence.ids,
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

  static ({List<String> rows, List<String> ids}) _evidenceCitations(
    List<JournalEntry> eligible,
  ) {
    final rows = <String>[];
    final ids = <String>[];
    for (final entry in eligible) {
      final snippet = FactLedgerCitationService.resolvedSnippet(
        entryId: entry.id,
        fallbackText: _entryText(entry),
        maxLength: _maxSnippetLength,
      );
      if (snippet.isEmpty) continue;
      rows.add(snippet);
      ids.add(entry.id);
    }
    if (rows.length <= 3) return (rows: rows, ids: ids);
    return (
      rows: rows.sublist(rows.length - 3),
      ids: ids.sublist(ids.length - 3),
    );
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
