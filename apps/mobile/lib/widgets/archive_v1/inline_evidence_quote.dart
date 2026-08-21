import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One verbatim fact-ledger quote rendered inside an inline evidence drawer.
class InlineEvidenceQuote {
  const InlineEvidenceQuote({
    required this.entryId,
    required this.recordedAt,
    required this.verbatimText,
    this.roleLabel,
  });

  final String entryId;
  final DateTime recordedAt;
  final String verbatimText;
  final String? roleLabel;

  static List<InlineEvidenceQuote> fromCitedEntries(List<CitedEntry> entries) {
    return [
      for (final entry in entries)
        InlineEvidenceQuote(
          entryId: entry.entryId,
          recordedAt: entry.createdAt,
          verbatimText: entry.rawText.trim().isEmpty
              ? 'Quote unavailable'
              : _quoteWrap(entry.rawText.trim()),
        ),
    ];
  }

  static List<InlineEvidenceQuote> fromTrailSources(
    List<EvidenceTrailSource> sources,
  ) {
    return [
      for (final source in sources)
        InlineEvidenceQuote(
          entryId: source.entryId,
          recordedAt: source.recordedAt,
          verbatimText: source.excerpt,
          roleLabel: switch (source.role) {
            EvidenceSourceRole.supporting => 'Supporting',
            EvidenceSourceRole.contradicting => 'Counter-evidence',
            EvidenceSourceRole.related => 'Related',
          },
        ),
    ];
  }

  static List<InlineEvidenceQuote> fromJournalEntries(
    List<JournalEntry> entries,
  ) {
    final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final entry in sorted.take(12))
        InlineEvidenceQuote(
          entryId: entry.id,
          recordedAt: entry.createdAt,
          verbatimText: _excerpt(entry),
        ),
    ];
  }

  static String _excerpt(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) {
      final observation = entry.reflection.concreteObservation.trim();
      if (observation.isNotEmpty) return '"$observation"';
      return '(No transcript)';
    }
    final line = transcript.length > 180
        ? '${transcript.substring(0, 180).trim()}…'
        : transcript;
    return '"$line"';
  }

  static String _quoteWrap(String text) {
    if (text.startsWith('"') && text.endsWith('"')) return text;
    return '"$text"';
  }
}