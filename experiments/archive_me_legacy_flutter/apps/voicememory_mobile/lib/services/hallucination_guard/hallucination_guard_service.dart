import '../../features/ai_engines/models/ai_explainability.dart';
import '../../models/journal_entry.dart';

enum CitationVerificationState { verifiedQuote, paraphrased, flagged }

extension CitationVerificationLabel on CitationVerificationState {
  String get label => switch (this) {
    CitationVerificationState.verifiedQuote => 'Verified Quote',
    CitationVerificationState.paraphrased => 'Paraphrased',
    CitationVerificationState.flagged => 'Flagged',
  };
}

typedef LocalEntryLoader = Future<JournalEntry?> Function(String entryId);

class CitationVerification {
  const CitationVerification({
    required this.citation,
    required this.state,
    this.sourceEntry,
    this.surroundingContext,
  });

  final VerifiableCitation citation;
  final CitationVerificationState state;
  final JournalEntry? sourceEntry;
  final String? surroundingContext;
}

/// Fail-closed local verification for all user-visible AI citations.
class HallucinationGuardService {
  const HallucinationGuardService({required this.loadEntry});

  final LocalEntryLoader loadEntry;

  Future<CitationVerification> verify(VerifiableCitation citation) async {
    final entry = await loadEntry(citation.sourceEntryId);
    final transcript = entry?.transcript ?? '';
    final quote = citation.exactQuote.trim();
    if (entry == null || transcript.isEmpty || quote.isEmpty) {
      return CitationVerification(
        citation: citation,
        state: CitationVerificationState.flagged,
        sourceEntry: entry,
      );
    }

    final exactStart = transcript.indexOf(quote);
    if (exactStart >= 0) {
      return CitationVerification(
        citation: citation,
        state: CitationVerificationState.verifiedQuote,
        sourceEntry: entry,
        surroundingContext: _context(transcript, exactStart, quote.length),
      );
    }

    final normalizedTranscript = _normalize(transcript);
    final normalizedQuote = _normalize(quote);
    final quoteTokens = _tokens(normalizedQuote);
    final transcriptTokens = _tokens(normalizedTranscript);
    final overlap = quoteTokens.isEmpty
        ? 0.0
        : quoteTokens.where(transcriptTokens.contains).length /
              quoteTokens.length;
    if ((normalizedQuote.length >= 8 &&
            normalizedTranscript.contains(normalizedQuote)) ||
        (quoteTokens.length >= 3 && overlap >= .65)) {
      return CitationVerification(
        citation: citation,
        state: CitationVerificationState.paraphrased,
        sourceEntry: entry,
        surroundingContext: transcript,
      );
    }

    return CitationVerification(
      citation: citation,
      state: CitationVerificationState.flagged,
      sourceEntry: entry,
    );
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9\\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _tokens(String value) =>
      value.split(' ').where((token) => token.length > 2).toSet();

  static String _context(String transcript, int start, int quoteLength) {
    const radius = 120;
    final contextStart = (start - radius).clamp(0, transcript.length);
    final contextEnd = (start + quoteLength + radius).clamp(
      contextStart,
      transcript.length,
    );
    return transcript.substring(contextStart, contextEnd);
  }
}
