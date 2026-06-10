import '../product/consumer_ui_copy.dart';

/// Where the paywall was opened from, so the copy can speak to the value the
/// user was just looking at instead of a generic pitch.
enum PaywallSource {
  pressurePatternHistory(id: 'pressure_pattern_history'),
  pressureReview(id: 'pressure_review'),
  askArchive(id: 'ask_archive'),
  dailySuggestion(id: 'daily_suggestion'),
  startHereToday(id: 'start_here_today'),
  generalPro(id: 'general_pro');

  const PaywallSource({required this.id});

  /// Stable id, safe to log/persist.
  final String id;

  static PaywallSource? fromId(String? id) {
    if (id == null) return null;
    for (final source in PaywallSource.values) {
      if (source.id == id) return source;
    }
    return null;
  }
}

/// Source-specific paywall copy. Pure lookup — deterministic and test-safe.
class PaywallSourceCopy {
  const PaywallSourceCopy({
    required this.headline,
    required this.subheadline,
    required this.bullets,
    required this.cta,
  });

  final String headline;
  final String subheadline;
  final List<String> bullets;
  final String cta;

  static const unlockProCta = 'Unlock ArchiveMe Pro';

  /// Pressure pattern history + full review share the pressure pitch.
  static const pressure = PaywallSourceCopy(
    headline: 'Unlock your full pressure pattern',
    subheadline: 'See where this keeps repeating, what it may be costing you, '
        'and what changed over time.',
    bullets: [
      'Full pressure pattern history',
      'Your first pressure review',
      'Evidence confidence',
      'Ask your archive where this repeats',
      'Return triggers for the real-life pressure moment',
    ],
    cta: unlockProCta,
  );

  static const askArchive = PaywallSourceCopy(
    headline: 'Ask your archive what keeps repeating',
    subheadline: 'ArchiveMe uses your saved moments to show patterns with '
        'evidence, not generic advice.',
    bullets: [
      'Ask where this pressure repeats',
      'See the evidence behind the answer',
      'Track how the pattern changes',
      'Unlock full pressure reviews',
    ],
    cta: unlockProCta,
  );

  /// Daily Return Suggestions + Start here today share the daily-prompt pitch:
  /// the user just experienced the prompts, so the pitch is about keeping them
  /// improving — not a generic Pro list.
  static const dailySuggestions = PaywallSourceCopy(
    headline: 'Keep your daily archive prompts improving',
    subheadline: 'ArchiveMe uses what you record to surface sharper things '
        'worth checking each day.',
    bullets: [
      'See the patterns behind your daily prompts',
      'Keep evidence from past recordings connected',
      'Ask your archive what keeps repeating',
    ],
    cta: 'Unlock Pro',
  );

  static const generalPro = PaywallSourceCopy(
    headline: 'Unlock ArchiveMe Pro',
    subheadline: 'Turn saved moments into patterns, reviews, and evidence you '
        'can come back to.',
    bullets: ConsumerUiCopy.paywallFallbackBullets,
    cta: ConsumerUiCopy.paywallPrimaryCta,
  );

  /// True for the daily-suggestion surfaces (Start here today / Daily
  /// Suggestion) that share the daily-prompt pitch.
  static bool isSuggestionSource(PaywallSource? source) =>
      source == PaywallSource.startHereToday ||
      source == PaywallSource.dailySuggestion;

  static PaywallSourceCopy forSource(PaywallSource source) {
    switch (source) {
      case PaywallSource.pressurePatternHistory:
      case PaywallSource.pressureReview:
        return pressure;
      case PaywallSource.askArchive:
        return askArchive;
      case PaywallSource.dailySuggestion:
      case PaywallSource.startHereToday:
        return dailySuggestions;
      case PaywallSource.generalPro:
        return generalPro;
    }
  }
}

/// Calm trust copy near the purchase CTA. Reassuring, never defensive — and
/// never implying free users lose their saved recordings.
class PaywallConfidenceCopy {
  /// Default lines for the generic paywall and non-suggestion sources.
  static const List<String> generic = [
    'Your archive is yours.',
    'Today\u2019s saves stay even if you don\u2019t upgrade.',
    'Cancel anytime through the App Store.',
    'Pro unlocks deeper continuity, not access to your basic saves.',
  ];

  /// Shorter continuity-focused lines for users arriving from a suggestion —
  /// the same framing the post-save receipt already used.
  static const List<String> suggestion = [
    'Today\u2019s save stays in your archive.',
    'Pro keeps the thread connected across future recordings.',
    'Cancel anytime through the App Store.',
  ];

  static List<String> forSource(PaywallSource? source) =>
      PaywallSourceCopy.isSuggestionSource(source) ? suggestion : generic;
}
