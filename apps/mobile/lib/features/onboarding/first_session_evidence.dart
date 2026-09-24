import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';

/// Set when the onboarding importer finishes. The quote-back path stays
/// quiet for that session.
abstract final class FirstSessionEvidenceSession {
  static bool didImport = false;

  static void resetForTest() {
    didImport = false;
  }
}

class ImportedCitation {
  const ImportedCitation({
    required this.entryId,
    required this.quote,
    required this.recordedAt,
  });

  final String entryId;
  final String quote;
  final DateTime recordedAt;
}

class ImportedPatternCardModel {
  const ImportedPatternCardModel({
    required this.title,
    required this.citations,
  });

  final String title;
  final List<ImportedCitation> citations;

  List<String> get entryIds =>
      citations.map((citation) => citation.entryId).toList();
}

class VerbatimQuoteSpan {
  const VerbatimQuoteSpan({
    required this.text,
    required this.recordedAt,
  });

  final String text;
  final DateTime recordedAt;
}

/// Local pattern read over imported notes. Returns null unless
/// [ArchiveEvidenceGuard] accepts the entries and the heuristic finds a repeat.
abstract final class ImportedPatternPresenter {
  static ImportedPatternCardModel? fromEntries(List<JournalEntry> entries) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) return null;
    final analysis = const ArchiveEvidenceHeuristics().analyze(entries);
    if (!analysis.possibleRepeat || analysis.windowEntries.isEmpty) {
      return null;
    }
    final citations = <ImportedCitation>[];
    for (final entry in analysis.windowEntries) {
      final quote = resolveEntryDisplayText(entry).text.trim();
      if (quote.isEmpty) continue;
      citations.add(
        ImportedCitation(
          entryId: entry.id,
          quote: quote,
          recordedAt: entry.createdAt,
        ),
      );
    }
    if (citations.isEmpty) return null;
    return ImportedPatternCardModel(
      title: FirstSessionEvidenceCopy.importCardTitle,
      citations: citations,
    );
  }
}

/// One or two verbatim sentences from a speech-to-text transcript.
abstract final class FirstSaveQuotePresenter {
  static List<VerbatimQuoteSpan> quotesFor(JournalEntry entry) {
    if (entry.transcriptProvenance != TranscriptProvenance.speechToText) {
      return const [];
    }
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) return const [];
    final pieces = transcript
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((piece) => piece.trim())
        .where((piece) => piece.isNotEmpty)
        .take(2)
        .toList();
    final spans = pieces.isEmpty ? [transcript] : pieces;
    return [
      for (final text in spans)
        VerbatimQuoteSpan(text: text, recordedAt: entry.createdAt),
    ];
  }
}

String formatEvidenceTimestamp(DateTime recordedAt) {
  final local = recordedAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
