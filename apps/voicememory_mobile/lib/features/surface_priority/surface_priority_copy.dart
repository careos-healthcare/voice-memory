/// Copy for surface priority audit — calm framing, no journal text.
abstract final class SurfacePriorityCopy {
  SurfacePriorityCopy._();

  static const coreRule =
      'Record screen is capture-first. Patterns screen is timeline-first. Paywall has one reason.';

  static const paidReason = 'Pro keeps the longer proof trail over time.';

  static const debugSummaryTitle = 'Surface priority';

  static const hiddenReasonGuidanceCap = 'guidance_cap_one';
  static const hiddenReasonProofCap = 'proof_cap_one';
  static const hiddenReasonCorrectionCap = 'correction_cap_one';
  static const hiddenReasonReportWithMultipleProof =
      'report_with_multiple_proof';
  static const hiddenReasonProCap = 'pro_cap_one';
  static const hiddenReasonProofFloorBlocksPro =
      'proof_floor_rescue_blocks_pro';
  static const hiddenReasonPostSaveGuidance = 'post_save_no_guidance';
  static const hiddenReasonPostSaveFirstProofWins =
      'post_save_first_proof_wins';
  static const hiddenReasonPostSaveWhatChangedWins =
      'post_save_what_changed_wins';
  static const hiddenReasonPostSaveReturnPayoffWins =
      'post_save_return_payoff_wins';
  static const hiddenReasonPatternsDetailCap = 'patterns_detail_cap_one';
  static const hiddenReasonPatternsDuplicateTimeline =
      'patterns_duplicate_timeline_message';
  static const hiddenReasonPatternsProBeforeTimeline =
      'patterns_pro_after_timeline';
  static const hiddenReasonPaywallDuplicateReason = 'paywall_one_paid_reason';
  static const hiddenReasonFirstRunEducationCap =
      'first_run_education_slot_blocked';

  static List<String> allVisibleStrings() => [
    coreRule,
    paidReason,
    debugSummaryTitle,
  ];
}
