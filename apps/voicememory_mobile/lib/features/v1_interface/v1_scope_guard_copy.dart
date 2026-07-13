/// Consumer launch copy must not drift into broad journaling / assistant positioning.
abstract final class V1ScopeGuardCopy {
  V1ScopeGuardCopy._();

  /// Positioning claims ArchiveMe must not make in consumer-facing launch copy.
  static const bannedPositioningClaims = <String>[
    'generic journal',
    'diary dashboard',
    'therapy',
    'coach',
    'treatment',
    'diagnosis',
    'chatgpt replacement',
    'productivity dashboard',
    'life operating system',
  ];

  /// Sources scanned for launch positioning drift.
  static const launchCopyFilePaths = <String>[
    'lib/product/consumer_ui_copy.dart',
    'lib/product/archive_positioning_copy.dart',
    'lib/product/loop_acquisition_copy.dart',
    'lib/onboarding/onboarding_pages.dart',
    'lib/record/record_screen_framing_copy.dart',
    'lib/features/onboarding/first_session_onboarding_copy.dart',
    'lib/features/onboarding/first_proof_journey_copy.dart',
    'lib/features/paywall_alignment/paywall_alignment_copy.dart',
    'lib/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart',
    'lib/features/v1_interface/v1_core_product_sentence.dart',
    'docs/APP_STORE_COPY.md',
    'docs/PLAY_STORE_COPY.md',
  ];

  /// Live V1 revenue copy should emphasize proof trail, not AI volume.
  static const requiredLiveFocusPhrases = <String>[
    'first proof',
    'longer trail',
    'evidence over time',
  ];

  static const bannedLiveRevenuePhrases = <String>[
    'more ai',
    'better ai',
    'unlimited answers',
  ];
}
