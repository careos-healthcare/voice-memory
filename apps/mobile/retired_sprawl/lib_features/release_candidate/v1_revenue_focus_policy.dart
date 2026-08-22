import 'package:archiveme_mobile/features/v1_interface/v1_core_product_sentence.dart';

/// V1 revenue focus policy — packaging, billing, wedge, and proof loop only.
abstract final class V1RevenueFocusPolicy {
  V1RevenueFocusPolicy._();

  static const manifestoLine =
      'The revenue increase now comes from sharper packaging, live billing, wedge '
      'acquisition, and a cleaner first proof journey — not more product surface.';

  static const String firstUserJourney = V1CoreProductSentence.line;

  static const allowedPillars = <String>[
    'record one real moment',
    'return later',
    'see what repeated, changed, faded, or corrected',
    'pro keeps the longer proof trail',
    'live billing must be verified before paid claims',
    'wedge acquisition points into record-return-proof loop',
  ];

  static const blockedSurfaces = <String>[
    'private reports as live headline',
    'exports as live pro promise',
    'referrals before proof',
    'safe sharing as viral loop before proof',
    'android before ios proof',
    'b2b before consumer paid proof',
    'loop packs before core pro conversion',
    'premium tiers before one pro plan converts',
    'generic ask or chat positioning',
    'clinical and medical positioning',
    'assistant-style ai positioning',
    'chatgpt replacement positioning',
  ];

  static const bannedLiveProClaims = <String>[
    'more ai',
    'better ai',
    'unlimited answers',
    'ai coach',
    'therapy',
    'diagnosis',
    'treatment',
    'mental-health scoring',
    'pro is active',
    'better than chatgpt',
    'chatgpt replacement',
  ];

  static const bannedOverclaimPhrases = <String>[
    'guaranteed repeat',
    'proof is ready',
    'pattern confirmed',
    'definitely repeats',
    'will always return',
  ];

  static bool hasNoBannedLiveProClaims(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    for (final phrase in bannedLiveProClaims) {
      if (phrase == 'pro is active' && blob.contains('not pro is active')) {
        continue;
      }
      if (blob.contains(phrase)) return false;
    }
    return true;
  }

  static bool hasNoOverclaims(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    for (final phrase in bannedOverclaimPhrases) {
      if (blob.contains(phrase)) return false;
    }
    return true;
  }

  static bool copyMentionsAllowedPillar(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    return blob.contains('save one real moment') ||
        blob.contains('compares it later') ||
        blob.contains('longer proof trail') ||
        blob.contains('first useful proof');
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield manifestoLine;
    yield firstUserJourney;
    yield* allowedPillars;
    yield* blockedSurfaces;
  }
}