/// Canonical customer-language terms for the focused beta.
///
/// See `docs/product/CUSTOMER_LANGUAGE.md` for definitions, examples, and
/// prohibited overclaims. User-facing strings should prefer these constants.
abstract final class CustomerLanguage {
  CustomerLanguage._();

  static const brandName = 'Thoughtprint';
  static const logoInitials = 'AM';

  static const moment = 'Entry';
  static const momentLower = 'entry';
  static const archive = 'Archive';
  static const archiveLower = 'archive';
  static const possiblePattern = 'Possible pattern';
  static const possiblePatternLower = 'possible pattern';
  static const evidence = 'Evidence';
  static const evidenceLower = 'evidence';
  static const change = 'Change';

  static const feedbackCorrect = 'Correct';
  static const feedbackFits = 'Fits';
  static const feedbackPartlyFits = 'Partly fits';
  static const feedbackNotForMe = 'Not for me';
  static const feedbackHide = 'Hide';

  static const yourWordsLabel = 'Your words';
  static const archiveSuggestionLabel = 'Thoughtprint suggestion';

  static const onboardingHeadline = 'Record the entry. See what returns.';
  static const onboardingBody =
      'Record a voice or typed entry in your own words. Over time, Thoughtprint '
      'may show what repeats — with the entries behind it.';

  static const emptyArchiveTitle = 'Record a few real entries';
  static const emptyArchiveBody =
      'Record one real entry. Thoughtprint compares it later.';

  static const oneMomentTitle = 'First entry recorded';
  static const oneMomentBody =
      'Come back when this shows up again. Thoughtprint has one entry to compare later.';

  static const twoMomentsTitle = 'These entries may be related';
  static const twoMomentsBody =
      'Thoughtprint noticed similar wording across two recorded entries. '
      'This is not an established pattern yet.';

  static const threePlusTitle = possiblePattern;
  static const threePlusBody =
      'These entries may repeat a similar theme. Review the evidence '
      'before treating it as settled.';

  static const contactEmail = 'hello@thoughtprint.xyz';
  static const supportEmail = 'support@thoughtprint.xyz';
  static const privacyUrl = 'https://thoughtprint.xyz/privacy';
  static const supportUrl = 'https://thoughtprint.xyz/contact';

  /// Substrings banned in release-reachable UI literals (case-insensitive).
  static const bannedPrimaryUiTerms = [
    'VoiceMemory',
    'voice memory',
    'voicememory',
    'ChatGPT',
    'OpenAI processing',
    'Whisper',
    'belief',
    'proof',
    'theory',
    'diagnosis',
    'blind spot',
    'objective',
    'signal confidence',
    'pattern certainty',
    'archive intelligence',
  ];
}
