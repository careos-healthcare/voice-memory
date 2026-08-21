import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';

/// One fact-ledger-backed transcript snippet for display on insight cards.
class FactLedgerResolvedCitation {
  const FactLedgerResolvedCitation({
    required this.entryId,
    required this.quote,
    this.label,
    this.recordedAt,
  });

  final String entryId;
  final String quote;
  final String? label;
  final DateTime? recordedAt;

  static FactLedgerResolvedCitation fromLine(InsightEvidenceLine line) {
    final resolved = FactLedgerCitationService.resolve(
      entryId: line.entryId,
      fallback: line.quote,
    ).trim();
    return FactLedgerResolvedCitation(
      entryId: line.entryId,
      quote: resolved,
      label: line.label,
      recordedAt: line.recordedAt,
    );
  }

  static FactLedgerResolvedCitation fromEntryQuote({
    required String entryId,
    required String quote,
    String? label,
    DateTime? recordedAt,
  }) {
    final resolved = FactLedgerCitationService.resolve(
      entryId: entryId,
      fallback: quote,
    ).trim();
    return FactLedgerResolvedCitation(
      entryId: entryId,
      quote: resolved,
      label: label,
      recordedAt: recordedAt,
    );
  }

  static List<FactLedgerResolvedCitation> fromLines(
    Iterable<InsightEvidenceLine> lines,
  ) {
    return lines
        .map(fromLine)
        .where((citation) => citation.quote.length >= 8)
        .toList();
  }

  static List<FactLedgerResolvedCitation> fromEntryQuotes({
    required Iterable<({String entryId, String quote, String? label})> items,
  }) {
    return items
        .map(
          (item) => fromEntryQuote(
            entryId: item.entryId,
            quote: item.quote,
            label: item.label,
          ),
        )
        .where((citation) => citation.quote.length >= 8)
        .toList();
  }
}
