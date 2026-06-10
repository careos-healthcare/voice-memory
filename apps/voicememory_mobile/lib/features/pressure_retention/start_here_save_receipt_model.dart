import '../../billing/paywall_source.dart';

/// The compact "Saved to your archive" receipt shown after a recording that
/// started from Start here today or a Daily Suggestion. Frames Pro as a
/// continuation of the value the user just experienced — never a hard sell.
class StartHereSaveReceipt {
  const StartHereSaveReceipt({
    this.title = defaultTitle,
    this.explanation = defaultExplanation,
    this.connectedTerms = const [],
    this.proCtaLabel = defaultProCtaLabel,
    this.dismissLabel = defaultDismissLabel,
    required this.paywallSource,
  });

  static const String defaultTitle = 'Saved to your archive';
  static const String defaultExplanation =
      'This connects to what your archive has already noticed.';
  static const String defaultProCtaLabel = 'See what Pro unlocks';
  static const String defaultDismissLabel = 'Not now';

  final String title;
  final String explanation;

  /// Up to three personal, phrase-like labels this recording connects to,
  /// e.g. "work pressure" or "stopping felt unsafe". May be empty.
  final List<String> connectedTerms;

  final String proCtaLabel;
  final String dismissLabel;

  /// Which suggestion surface the recording came from — drives paywall
  /// source attribution when the CTA is tapped.
  final PaywallSource paywallSource;
}
