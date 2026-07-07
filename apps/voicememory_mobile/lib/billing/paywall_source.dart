import '../product/consumer_ui_copy.dart';

/// Where the paywall was opened from, so the copy can speak to the value the
/// user was just looking at instead of a generic pitch.
enum PaywallSource {
  pressurePatternHistory(id: 'pressure_pattern_history'),
  pressureReview(id: 'pressure_review'),
  askArchive(id: 'ask_archive'),
  dailySuggestion(id: 'daily_suggestion'),
  startHereToday(id: 'start_here_today'),
  valueMoment(id: 'value_moment'),
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

  static const unlockProCta = ConsumerUiCopy.paywallPrimaryCta;

  /// Pressure pattern history + full review share the pressure pitch.
  static const pressure = PaywallSourceCopy(
    headline: 'See more of your pressure pattern',
    subheadline:
        'See where this keeps repeating, what it may be costing you, '
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
    subheadline:
        'ArchiveMe uses your saved moments to show patterns with '
        'evidence, not generic advice.',
    bullets: [
      'Ask where this pressure repeats',
      'See the evidence behind the answer',
      'Track how the pattern changes',
      'Full pressure reviews over time',
    ],
    cta: unlockProCta,
  );

  /// Daily Return Suggestions + Start here today share the thread pitch:
  /// buyers say "threads connected" is why Pro makes sense, so the headline
  /// makes that the main promise — continuity over time, never "advanced AI"
  /// and never a generic Pro list. Free keeps today's save; Pro connects it.
  static const dailySuggestions = PaywallSourceCopy(
    headline: 'Keep the thread connected',
    subheadline:
        'Free keeps today\u2019s save. Pro connects what returns, '
        'fades, and changes over time.',
    bullets: [
      'See when a thread returns',
      'Notice when a pattern starts fading',
      'Track belief-like phrases that show up again',
      'Open the exact evidence behind each insight',
    ],
    cta: unlockProCta,
  );

  static const generalPro = PaywallSourceCopy(
    headline: ConsumerUiCopy.paywallHeadline,
    subheadline: ConsumerUiCopy.paywallSubhead,
    bullets: ConsumerUiCopy.paywallFallbackBullets,
    cta: ConsumerUiCopy.paywallPrimaryCta,
  );

  /// True for the daily-suggestion surfaces (Start here today / Daily
  /// Suggestion) that share the daily-prompt pitch. Suggestion-to-Pro funnel
  /// attribution keys off these two only.
  static bool isSuggestionSource(PaywallSource? source) =>
      source == PaywallSource.startHereToday ||
      source == PaywallSource.dailySuggestion;

  /// True for every source that gets the full continuity treatment (thread
  /// preview, proof checks, continuity confidence copy): the suggestion
  /// surfaces plus the value-moment Pro bridge.
  static bool isContinuitySource(PaywallSource? source) =>
      isSuggestionSource(source) || source == PaywallSource.valueMoment;

  static PaywallSourceCopy forSource(PaywallSource source) {
    switch (source) {
      case PaywallSource.pressurePatternHistory:
      case PaywallSource.pressureReview:
        return pressure;
      case PaywallSource.askArchive:
        return askArchive;
      case PaywallSource.dailySuggestion:
      case PaywallSource.startHereToday:
      // The value-moment bridge sells the same continuity promise.
      case PaywallSource.valueMoment:
        return dailySuggestions;
      case PaywallSource.generalPro:
        return generalPro;
    }
  }
}

/// One row of the "What Pro continues" preview.
/// Annual-value framing shown near the plan cards for suggestion sources.
/// Speaks to "didn't want another subscription" by framing Pro as a long-term
/// archive — no scarcity, no pressure.
class PaywallAnnualValueCopy {
  static const String longTermLine =
      'This works best as a long-term archive, not a one-off feature.';

  /// Plan-card helper lines for suggestion-sourced paywalls.
  static const String yearlyHelper =
      'Best if you want your archive to build over time.';
  static const String monthlyHelper = 'Try it month to month.';

  static bool showFor(PaywallSource? source) =>
      PaywallSourceCopy.isContinuitySource(source);
}

/// "Proof you can look for" — concrete checks the user can run themselves to
/// judge whether Pro is helping. Speaks to "still not enough proof it would
/// help" with observable signals instead of claims.
class PaywallProofPreview {
  static const String heading = 'Proof you can look for';

  static const List<String> rows = [
    'Do prompts get sharper after a few saves?',
    'Does the same thread return tomorrow?',
    'Does your archive show what changed?',
  ];

  static bool showFor(PaywallSource? source) =>
      PaywallSourceCopy.isContinuitySource(source);
}

/// Above-fold clarity block — the paid promise in plain words, shown
/// directly under the headline before plan cards or any CTA. One block for
/// every source, so value-moment copy is centralized rather than repeated.
abstract class PaywallAboveFoldClarity {
  PaywallAboveFoldClarity._();

  static const String title = 'What Pro continues';

  static const List<String> lines = [
    'What returned',
    'What faded',
    'What changed',
    'The exact evidence behind it',
  ];

  /// Free reassurance shown with the block — never lockout framing.
  static const String freeReassuranceLine =
      'Free keeps today\u2019s save. Pro keeps the thread connected over '
      'time.';
}

/// Plan-selection confidence near the plan selector — reduces hesitation at
/// the monthly-vs-yearly choice. Both plans are framed as fine choices;
/// there is no pressure toward yearly and no savings claim, because the
/// paywall does not calculate real savings from product pricing.
abstract class PaywallPlanSelectionConfidence {
  PaywallPlanSelectionConfidence._();

  static const String title = 'Choose how you want to continue';

  static const String monthlyHelper = 'Monthly keeps it flexible.';
  static const String yearlyHelper =
      'Yearly is for people who want ArchiveMe to keep connecting patterns '
      'over time.';

  /// Selected-plan reassurance — always visible with the helper.
  static const String manageLine =
      'You can manage or cancel this anytime through the App Store.';

  /// Stable plan ids, safe to log. Never user text.
  static const String monthlyPlanId = 'monthly';
  static const String yearlyPlanId = 'yearly';

  static String helperForPlanId(String planId) =>
      planId == yearlyPlanId ? yearlyHelper : monthlyHelper;
}

/// Price confidence near the plans and purchase CTA — reduces hesitation at
/// the App Store sheet by saying plainly who handles the money. The trial
/// handling line only ever renders when a real free trial was detected on a
/// loaded product.
abstract class PaywallPriceConfidenceCopy {
  PaywallPriceConfidenceCopy._();

  /// Shown immediately below the plan cards.
  static const String manageLine =
      'You can manage this anytime in the App Store.';

  /// Trial handling — only when a zero-price introductory offer is actually
  /// configured on a loaded App Store product.
  static const String trialHandlingLine =
      'Trial details are handled by the App Store before you confirm.';

  /// Final line directly before the purchase CTA.
  static const String confirmLine =
      'The App Store will confirm before anything is charged.';

  static List<String> planLines({required bool hasFreeTrial}) => [
    manageLine,
    if (hasFreeTrial) trialHandlingLine,
  ];
}

/// Calm trust copy near the purchase CTA. Reassuring, never defensive — and
/// never implying free users lose their saved recordings.
class PaywallConfidenceCopy {
  /// Final purchase reassurance — always visible immediately above the
  /// purchase CTA. Short and safety-first: what stays free, what Pro adds,
  /// how to leave.
  static const List<String> generic = [
    'Your saves stay free.',
    'Pro only adds continuity over time.',
    'Manage or cancel anytime in the App Store.',
  ];

  /// Subscription reassurance — explicitly leaves the decision with the user.
  static const String suggestionReassurance =
      'Upgrade only if you want the archive to keep building over time.';

  /// Suggestion and value-moment sources get the same reassurance plus the
  /// explicit no-pressure line. Free users are never locked out of their
  /// own saves.
  static const List<String> suggestion = [...generic, suggestionReassurance];

  /// Shown only when a zero-price introductory offer is actually configured
  /// on a loaded App Store product — never as a generic promise.
  static const String trialLine =
      'Try Pro free, then continue only if it feels useful.';

  static List<String> forSource(PaywallSource? source) =>
      PaywallSourceCopy.isContinuitySource(source) ? suggestion : generic;

  /// Confidence lines plus the trial line when a free trial was safely
  /// detected on the live products.
  static List<String> linesFor(
    PaywallSource? source, {
    required bool hasFreeTrial,
  }) => [...forSource(source), if (hasFreeTrial) trialLine];
}
