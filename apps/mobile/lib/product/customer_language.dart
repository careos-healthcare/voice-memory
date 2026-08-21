/// Canonical customer-language terms for the focused beta.
///
/// See `docs/product/CUSTOMER_LANGUAGE.md` for definitions, examples, and
/// prohibited overclaims. User-facing strings should prefer these constants.
abstract final class CustomerLanguage {
  CustomerLanguage._();

  static const brandName = 'ArchiveMe';
  static const logoInitials = 'AM';

  static const moment = 'Moment';
  static const momentLower = 'moment';
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
  static const archiveSuggestionLabel = 'ArchiveMe suggestion';

  static const onboardingHeadline = 'Save the moment. See what returns.';
  static const onboardingBody =
      'Save a voice or typed moment in your own words. Over time, ArchiveMe '
      'may show what repeats — with the moments behind it.';

  static const emptyArchiveTitle = 'Record a few real moments';
  static const emptyArchiveBody =
      'Save one real moment. ArchiveMe compares it later.';

  static const oneMomentTitle = 'First moment saved';
  static const oneMomentBody =
      'Come back when this shows up again. ArchiveMe has one moment to compare later.';

  static const twoMomentsTitle = 'These moments may be related';
  static const twoMomentsBody =
      'ArchiveMe noticed similar wording across two saved moments. '
      'This is not an established pattern yet.';

  static const threePlusTitle = possiblePattern;
  static const threePlusBody =
      'These moments may repeat a similar theme. Review the evidence '
      'before treating it as settled.';

  static const contactEmail = 'hello@archiveme.app';
  static const supportEmail = 'support@archiveme.app';
  static const privacyUrl = 'https://archiveme.app/privacy';
  static const supportUrl = 'https://archiveme.app/contact';

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
