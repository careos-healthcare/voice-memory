/// Copy for the always-visible evidence citation surfaces.
///
/// Every string here describes where words came from. None of it makes a
/// storage, transport, or protection promise, so the sensitive claims stay in
/// `PrivacyCopyPolicy` where they can be reviewed in one place.
abstract final class EvidenceCitationCopy {
  EvidenceCitationCopy._();

  /// Header on a grounded quote. Deliberately possessive: the point of the
  /// card is that the words are the user's, not a generated restatement.
  static const String quoteLabel = 'Your words';

  /// Sits under a quote to say the text was not rewritten for display.
  static const String verbatimHelper =
      'Quoted from your saved entry, word for word.';

  static const String expandQuote = 'Show full quote';
  static const String collapseQuote = 'Show less';

  /// Shown when the words behind a claim could not be found in a saved entry.
  static const String ungroundedTitle = 'No supporting quote found';
  static const String ungroundedHelper =
      'This is not quoted, because nothing in your saved entries matches it '
      'word for word.';

  /// Shown when the entry exists but its text was not loaded to check against.
  static const String sourceUnavailableTitle = 'Quote not loaded';
  static const String sourceUnavailableHelper =
      'Open the entry to read the saved words behind this.';

  static const String openEntry = 'Open entry';

  static String recordedOn(String date) => 'Recorded $date';

  /// Screen-reader wording so a quote is announced as a quotation with the
  /// date attached, rather than running into the surrounding claim text.
  static String quotationSemantics({
    required String quote,
    required String recorded,
  }) => 'Quote from your entry, $recorded. Quote: $quote. End of quote.';

  static String truncatedQuotationSemantics({
    required String quote,
    required String recorded,
  }) =>
      'Shortened quote from your entry, $recorded. Quote: $quote. '
      'End of shown text. Activate to read the full quote.';

  static const List<String> all = [
    quoteLabel,
    verbatimHelper,
    expandQuote,
    collapseQuote,
    ungroundedTitle,
    ungroundedHelper,
    sourceUnavailableTitle,
    sourceUnavailableHelper,
    openEntry,
  ];
}
