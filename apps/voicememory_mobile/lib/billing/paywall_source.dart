import '../product/consumer_ui_copy.dart';

/// Where the paywall was opened from, so the copy can speak to the value the
/// user was just looking at instead of a generic pitch.
enum PaywallSource {
  pressurePatternHistory(id: 'pressure_pattern_history'),
  pressureReview(id: 'pressure_review'),
  askArchive(id: 'ask_archive'),
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

  static const generalPro = PaywallSourceCopy(
    headline: 'Unlock ArchiveMe Pro',
    subheadline: 'Turn saved moments into patterns, reviews, and evidence you '
        'can come back to.',
    bullets: ConsumerUiCopy.paywallFallbackBullets,
    cta: ConsumerUiCopy.paywallPrimaryCta,
  );

  static PaywallSourceCopy forSource(PaywallSource source) {
    switch (source) {
      case PaywallSource.pressurePatternHistory:
      case PaywallSource.pressureReview:
        return pressure;
      case PaywallSource.askArchive:
        return askArchive;
      case PaywallSource.generalPro:
        return generalPro;
    }
  }
}
