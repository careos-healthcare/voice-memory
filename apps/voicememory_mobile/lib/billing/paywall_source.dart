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

  /// Daily Return Suggestions + Start here today share the thread pitch:
  /// buyers say "threads connected" is why Pro makes sense, so the headline
  /// makes that the main promise — a continuation of the value the user just
  /// experienced, not a generic Pro list.
  static const dailySuggestions = PaywallSourceCopy(
    headline: 'Keep the thread connected',
    subheadline: 'ArchiveMe uses what you record to connect today\u2019s '
        'pressure with what shows up again later.',
    bullets: [
      'Track when this pattern returns',
      'See how the evidence changes',
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

/// One row of the "What Pro continues" preview.
class PaywallProThreadPreviewRow {
  const PaywallProThreadPreviewRow({required this.title, required this.body});

  final String title;
  final String body;
}

/// Compact paywall preview of what Pro continues — only shown to users who
/// arrived from a suggestion surface, so it always refers to a thread they
/// just experienced. Never implies free users lose anything.
class PaywallProThreadPreview {
  static const String heading = 'What Pro continues';

  static const List<PaywallProThreadPreviewRow> rows = [
    PaywallProThreadPreviewRow(
      title: 'This thread',
      body: 'Keep today\u2019s save connected to future recordings.',
    ),
    PaywallProThreadPreviewRow(
      title: 'Pattern returns',
      body: 'See when the same pressure shows up again.',
    ),
    PaywallProThreadPreviewRow(
      title: 'Evidence changes',
      body: 'Notice if the story is getting stronger or fading.',
    ),
  ];

  static bool showFor(PaywallSource? source) =>
      PaywallSourceCopy.isSuggestionSource(source);
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
