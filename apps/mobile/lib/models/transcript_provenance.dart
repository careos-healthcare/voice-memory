/// Where the text held in `JournalEntry.transcript` actually came from.
///
/// This exists because it cannot be reconstructed after the fact. Entries
/// written before this field existed were stamped `TranscriptStatus.final`
/// whether the text came from speech-to-text or was back-filled from model
/// output, so a contaminated row is byte-identical on disk to a genuine one.
/// Provenance is therefore recorded at write time or not at all.
///
/// The default is deliberately the *untrusted* value. `TranscriptStatus`
/// defaults a missing value to its most-trusted member, which is the single
/// reason the existing data cannot be recovered; this enum does the opposite,
/// so a row written by a build that did not know about provenance reads back
/// as unquotable rather than as the user's verbatim words.
enum TranscriptProvenance {
  /// Produced by speech-to-text from the user's own recording.
  speechToText('speech_to_text'),

  /// Typed or corrected by the user. `TranscriptCorrectionController` performs
  /// no AI rewrite, so the replacement text is authored by the user and stays
  /// as quotable as speech-to-text output.
  userEdited('user_edited'),

  /// Written before provenance was recorded. May be speech-to-text, may be
  /// model output back-filled by the old capture path; there is no way to
  /// tell, so it is treated as not the user's words.
  unknownLegacy('unknown_legacy');

  const TranscriptProvenance(this.storageValue);

  final String storageValue;

  /// Missing, empty, and unrecognised values all read back as
  /// [unknownLegacy]. There is no input to this function that yields a
  /// trusted value by accident.
  static TranscriptProvenance fromStorage(String? raw) {
    switch (raw) {
      case 'speech_to_text':
        return TranscriptProvenance.speechToText;
      case 'user_edited':
        return TranscriptProvenance.userEdited;
      case 'unknown_legacy':
        return TranscriptProvenance.unknownLegacy;
      default:
        return TranscriptProvenance.unknownLegacy;
    }
  }

  /// Whether the transcript may be shown back to the user as their own words.
  ///
  /// The evidence index consults this before minting a `SpokenTranscript`; a
  /// legacy entry contributes no evidence source, so a claim that would have
  /// cited it renders `UngroundedEvidenceNotice` instead of a quote.
  bool get isQuotable => this != TranscriptProvenance.unknownLegacy;

  bool get isLegacyUnknown => this == TranscriptProvenance.unknownLegacy;
}
