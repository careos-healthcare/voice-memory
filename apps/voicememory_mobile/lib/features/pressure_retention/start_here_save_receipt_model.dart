import '../../billing/paywall_source.dart';

/// The compact "Saved to your archive" receipt shown after a recording that
/// started from Start here today or a Daily Suggestion. Frames Pro as a
/// continuation of the value the user just experienced — never a hard sell.
class StartHereSaveReceipt {
  const StartHereSaveReceipt({
    this.title = defaultTitle,
    this.explanation = defaultExplanation,
    this.connectedTerms = const [],
    this.returnCueLine = defaultReturnCueLine,
    this.freeValueLine = defaultFreeValueLine,
    this.proContinuationLine = defaultProContinuationLine,
    this.proPreviewBullets = defaultProPreviewBullets,
    this.proCtaLabel = defaultProCtaLabel,
    this.dismissLabel = defaultDismissLabel,
    required this.paywallSource,
  });

  static const String defaultTitle = 'Saved to your archive';
  static const String defaultExplanation =
      'This connects to what your archive has already noticed.';

  /// Why tomorrow is worth a return visit — deliberately cautious ("can
  /// check", "whether") so it never promises a pattern will be found.
  static const String defaultReturnCueLine =
      'Come back tomorrow and your archive can check whether this thread '
      'appears again.';

  /// What free users keep — stated first, so Pro never reads as a threat to
  /// the recording the user just saved.
  static const String defaultFreeValueLine =
      'Today\u2019s save stays in your archive.';

  /// What continues with Pro — a continuation of value, never scarcity.
  static const String defaultProContinuationLine =
      'Pro keeps this thread connected across future recordings.';

  static const List<String> defaultProPreviewBullets = [
    'Track when this pattern returns',
    'See how the evidence changes',
    'Ask what keeps repeating',
  ];

  static const String defaultProCtaLabel = 'See Pro';
  static const String defaultDismissLabel = 'Not now';

  final String title;
  final String explanation;

  /// Up to three personal, phrase-like labels this recording connects to,
  /// e.g. "work pressure" or "stopping felt unsafe". May be empty.
  final List<String> connectedTerms;

  /// Next-day return cue, shown after the terms and before the Pro incentive.
  final String returnCueLine;

  /// Shown before [proContinuationLine].
  final String freeValueLine;
  final String proContinuationLine;

  /// Compact preview of what Pro continues; may be empty.
  final List<String> proPreviewBullets;

  final String proCtaLabel;
  final String dismissLabel;

  /// Which suggestion surface the recording came from — drives paywall
  /// source attribution when the CTA is tapped.
  final PaywallSource paywallSource;
}
