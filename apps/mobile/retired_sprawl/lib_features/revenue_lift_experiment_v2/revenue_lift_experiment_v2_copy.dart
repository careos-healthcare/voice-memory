/// Revenue lift experiment v2 copy — metadata-safe, no journal text.
abstract final class RevenueLiftExperimentV2Copy {
  RevenueLiftExperimentV2Copy._();

  // A) First save sharpen
  static const firstSaveTitle = 'Save the moment that keeps pulling at you';
  static const firstSaveBody =
      'One sentence is enough. ArchiveMe needs one real moment before it can show what comes back.';
  static const firstSavePrimaryCta = 'Type one sentence';
  static const firstSaveSecondaryCta = 'Record instead';

  // B) Second save return reason
  static const returnReasonLine =
      'Come back only if it happens again. That is what lets ArchiveMe tell whether this is a one-off or a pattern.';

  // C) Proof payoff sharpen
  static const proofPayoffTitle = 'This is the part ArchiveMe keeps tracking';
  static const proofPayoffBody =
      'You have the first proof now. The next return shows whether it is getting louder, softer, or fading.';

  // D) Pro visibility sharpen
  static const proVisibilityTitle = 'Keep the longer trail';
  static const proVisibilityBody =
      'Free shows the first useful proof. Pro keeps tracking whether this pattern '
      'returns, changes, fades, or needs correcting.';
  static const proVisibilityPrimaryCta = 'See Pro timeline';
  static const proVisibilitySecondaryCta = 'Not now';

  // E) Paywall CTA sharpen
  static const paywallCtaTitle = 'Keep the evidence trail';
  static const paywallCtaBody =
      'The proof you just saw is only the start. Pro keeps the longer proof trail as more moments return, change, or fade.';
  static const paywallCtaSupportLine =
      'Not more chat. The longer record behind the pattern.';
  static const paywallPurchaseCtaLine =
      'Keep the timeline before it disappears into separate moments.';

  // G) Dashboard lift focus
  static const liftFocusSectionTitle = 'Current lift focus';
  static const liftFocusPaywallCta =
      'Sharpen paywall CTA copy and purchase line';
  static const liftFocusFirstSave = 'Sharpen first save lift copy';
  static const liftFocusUsefulProof =
      'Sharpen proof payoff copy after useful proof';
  static const liftFocusProVisibility = 'Sharpen Pro visibility bridge copy';
  static const liftFocusReturnAfterProof =
      'Sharpen return-after-proof reason copy';
  static const liftFocusReadyForMoreTesters = 'Ready for more testers';

  static const bannedPrivateMarkers = [
    'transcript',
    'journal_entry',
    'concreteObservation',
    'Maria said',
  ];

  static String liftFocusLabelFor(RevenueLiftExperimentV2Focus focus) =>
      switch (focus) {
        RevenueLiftExperimentV2Focus.paywallCta => liftFocusPaywallCta,
        RevenueLiftExperimentV2Focus.firstSave => liftFocusFirstSave,
        RevenueLiftExperimentV2Focus.usefulProof => liftFocusUsefulProof,
        RevenueLiftExperimentV2Focus.proVisibility => liftFocusProVisibility,
        RevenueLiftExperimentV2Focus.returnAfterProof =>
          liftFocusReturnAfterProof,
        RevenueLiftExperimentV2Focus.readyForMoreTesters =>
          liftFocusReadyForMoreTesters,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield firstSaveTitle;
    yield firstSaveBody;
    yield firstSavePrimaryCta;
    yield firstSaveSecondaryCta;
    yield returnReasonLine;
    yield proofPayoffTitle;
    yield proofPayoffBody;
    yield proVisibilityTitle;
    yield proVisibilityBody;
    yield proVisibilityPrimaryCta;
    yield proVisibilitySecondaryCta;
    yield paywallCtaTitle;
    yield paywallCtaBody;
    yield paywallCtaSupportLine;
    yield paywallPurchaseCtaLine;
    yield liftFocusSectionTitle;
    yield liftFocusPaywallCta;
    yield liftFocusFirstSave;
    yield liftFocusUsefulProof;
    yield liftFocusProVisibility;
    yield liftFocusReturnAfterProof;
    yield liftFocusReadyForMoreTesters;
  }
}

enum RevenueLiftExperimentV2Area {
  firstSave,
  returnReason,
  proofPayoff,
  proVisibility,
  paywallCta,
}

extension RevenueLiftExperimentV2AreaStorage on RevenueLiftExperimentV2Area {
  String get analyticsValue => switch (this) {
    RevenueLiftExperimentV2Area.firstSave => 'first_save',
    RevenueLiftExperimentV2Area.returnReason => 'return_reason',
    RevenueLiftExperimentV2Area.proofPayoff => 'proof_payoff',
    RevenueLiftExperimentV2Area.proVisibility => 'pro_visibility',
    RevenueLiftExperimentV2Area.paywallCta => 'paywall_cta',
  };
}

enum RevenueLiftExperimentV2Focus {
  paywallCta,
  firstSave,
  usefulProof,
  proVisibility,
  returnAfterProof,
  readyForMoreTesters,
}

extension RevenueLiftExperimentV2FocusStorage on RevenueLiftExperimentV2Focus {
  String get analyticsValue => switch (this) {
    RevenueLiftExperimentV2Focus.paywallCta => 'paywall_cta',
    RevenueLiftExperimentV2Focus.firstSave => 'first_save',
    RevenueLiftExperimentV2Focus.usefulProof => 'useful_proof',
    RevenueLiftExperimentV2Focus.proVisibility => 'pro_visibility',
    RevenueLiftExperimentV2Focus.returnAfterProof => 'return_after_proof',
    RevenueLiftExperimentV2Focus.readyForMoreTesters =>
      'ready_for_more_testers',
  };
}