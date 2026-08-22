/// Copy for the developer-only Proof of Value bottleneck playbook.
abstract final class ProofValueBottleneckPlaybookCopy {
  ProofValueBottleneckPlaybookCopy._();

  static const cardTitle = 'Bottleneck playbook';

  static const cardSubtitle = 'Fix only the current Proof of Value bottleneck.';

  static const sectionMeaning = 'Meaning';

  static const sectionFixArea = 'Fix area';

  static const sectionInspect = 'Inspect';

  static const sectionGuardrail = 'Guardrail';

  static const sectionSuggestedTests = 'Suggested test suite';

  static const activeRecommendationPrefix = 'Current bottleneck:';

  // A — Run more testers
  static const runMoreTestersMeaning =
      'There is not enough tester evidence yet.';

  static const runMoreTestersFixArea =
      'Do not change product yet. Run 5–10 testers.';

  static const runMoreTestersInspectBetaReportExport = 'Beta Report Export';

  static const runMoreTestersInspectProofOfValue = 'Proof of Value';

  static const runMoreTestersInspectActivationDropoff =
      'Activation Drop-off Review';

  static const runMoreTestersGuardrail =
      'No product changes until tester data exists.';

  static const runMoreTestersTestReleaseCandidateSmoke =
      'release_candidate_smoke_test.dart';

  static const runMoreTestersTestBetaReportExport =
      'beta_report_export_test.dart';

  static const runMoreTestersTestProofOfValue = 'proof_of_value_test.dart';

  // B — Fix first-use clarity
  static const fixFirstUseMeaning = 'Testers are not saving the first moment.';

  static const fixFirstUseFixArea = 'First-use / capture copy';

  static const fixFirstUseInspectRecordCapture = 'Record first-use capture';

  static const fixFirstUseInspectJourneyExplainer =
      'Archive Journey compact explainer';

  static const fixFirstUseInspectSaveCta = 'Save one moment CTA';

  static const fixFirstUseInspectMicCopy = 'Microphone permission copy';

  static const fixFirstUseInspectEmptyState = 'Record empty state';

  static const fixFirstUseGuardrail =
      'Keep Record capture-first. Do not add new cards or CTAs.';

  static const fixFirstUseTestRecordFraming =
      'record_screen_framing_copy_test.dart';

  static const fixFirstUseTestJourneyExplainer =
      'archive_journey_explainer_test.dart';

  static const fixFirstUseTestTrustReliability =
      'trust_recording_reliability_test.dart';

  // C — Fix return loop
  static const fixReturnLoopMeaning =
      'Testers save once but do not return for the second moment.';

  static const fixReturnLoopFixArea = 'Post-save handoff / return prompts';

  static const fixReturnLoopInspectPostSaveHandoff =
      'PostSaveReturnHandoffCopy';

  static const fixReturnLoopInspectEarlyRepeat = 'EarlyRepeatProgressCopy';

  static const fixReturnLoopInspectTesterMissionEntry1 =
      'TesterMissionCopy entry 1';

  static const fixReturnLoopInspectFirstWeekLoop = 'FirstWeekLoopCopy';

  static const fixReturnLoopGuardrail =
      'No notifications yet. Strengthen in-app return guidance only.';

  static const fixReturnLoopTestEarlyRepeat = 'early_repeat_progress_test.dart';

  static const fixReturnLoopTestTesterMission = 'tester_mission_test.dart';

  static const fixReturnLoopTestFirstWeekLoop = 'first_week_loop_test.dart';

  static const fixReturnLoopTestRecordFraming =
      'record_screen_framing_copy_test.dart';

  // D — Fix first proof activation
  static const fixFirstProofMeaning =
      'Testers are not reaching the first proof.';

  static const fixFirstProofFixArea = '1→2→3 journey';

  static const fixFirstProofInspectTesterMission = 'Tester mission';

  static const fixFirstProofInspectEntryProgress = 'Entry 1/2 progress';

  static const fixFirstProofInspectConfirmedRepeat =
      'Confirmed repeat matching';

  static const fixFirstProofInspectFirstProofGates = 'FirstProofMoment gates';

  static const fixFirstProofGuardrail =
      'Do not lower proof quality just to show proof earlier.';

  static const fixFirstProofTestFirstThreeSession =
      'first_three_session_loop_test.dart';

  static const fixFirstProofTestConfirmedRepeatPhrase =
      'confirmed_repeat_evidence_phrase_test.dart';

  static const fixFirstProofTestTesterMission = 'tester_mission_test.dart';

  static const fixFirstProofTestProofCopyDedup =
      'archive_proof_copy_dedup_test.dart';

  // E — Fix evidence specificity
  static const fixEvidenceMeaning =
      'First proof is reached, but it feels generic.';

  static const fixEvidenceFixArea = 'Extraction / chips / proof copy';

  static const fixEvidenceInspectPhraseEngine =
      'ConfirmedRepeatEvidencePhraseEngine';

  static const fixEvidenceInspectFirstProofCopy = 'FirstProofMomentCopy';

  static const fixEvidenceInspectCurrentBelief = 'ArchiveCurrentBeliefEngine';

  static const fixEvidenceInspectBeliefChips = 'Archive belief evidence chips';

  static const fixEvidenceGuardrail =
      'Prefer possible-repeat fallback over overclaiming.';

  static const fixEvidenceTestConfirmedRepeatPhrase =
      'confirmed_repeat_evidence_phrase_test.dart';

  static const fixEvidenceTestFirstThreeSession =
      'first_three_session_loop_test.dart';

  static const fixEvidenceTestCurrentBelief =
      'archive_current_belief_test.dart';

  static const fixEvidenceTestProofCopyDedup =
      'archive_proof_copy_dedup_test.dart';

  // F — Strengthen retention value
  static const strengthenRetentionMeaning =
      'Users see value but do not want to keep tracking.';

  static const strengthenRetentionFixArea = 'Timeline / report / weekly loop';

  static const strengthenRetentionInspectTimeline = 'Evidence timeline';

  static const strengthenRetentionInspectWhatChanged =
      'WhatChangedSinceLastTimeCard';

  static const strengthenRetentionInspectWeeklyReview =
      'WeeklyArchiveReviewCopy';

  static const strengthenRetentionInspectPrivateReport =
      'PrivateArchiveReportCopy';

  static const strengthenRetentionInspectFirstWeekLoop = 'FirstWeekLoopCopy';

  static const strengthenRetentionGuardrail =
      'Do not add new insight cards. Make existing value clearer.';

  static const strengthenRetentionTestTimelineCard =
      'archive_change_timeline_card_test.dart';

  static const strengthenRetentionTestWhatChanged =
      'what_changed_since_last_time_test.dart';

  static const strengthenRetentionTestWeeklyReview =
      'weekly_archive_review_test.dart';

  static const strengthenRetentionTestPrivateReport =
      'private_archive_report_test.dart';

  // G — Strengthen Pro value
  static const strengthenProMeaning =
      'Users see value but do not understand why they would pay.';

  static const strengthenProFixArea = 'Pro boundary / full archive value';

  static const strengthenProInspectProBridge = 'Pro bridge copy';

  static const strengthenProInspectPrivateReportPreview =
      'Private report preview';

  static const strengthenProInspectWeeklyPro = 'Weekly review Pro copy';

  static const strengthenProInspectPaywallEntry = 'Paywall entry copy';

  static const strengthenProInspectRestoreVisibility =
      'Restore purchases visibility';

  static const strengthenProGuardrail =
      'Do not change RevenueCat, entitlements, product IDs, restore, '
      'or purchase logic.';

  static const strengthenProTestFullArchiveHistory =
      'full_archive_history_pro_test.dart';

  static const strengthenProTestPaywallTiming =
      'paywall_timing_gates_test.dart';

  static const strengthenProTestPrivateReport =
      'private_archive_report_test.dart';

  static const strengthenProTestReleaseCandidateSmoke =
      'release_candidate_smoke_test.dart';

  // H — Widen beta
  static const widenBetaMeaning = 'Early proof of value is healthy.';

  static const widenBetaFixArea = 'Invite more testers.';

  static const widenBetaInspectBetaReportExport = 'Beta Report Export';

  static const widenBetaInspectSmokeChecklist = 'TestFlight smoke checklist';

  static const widenBetaInspectProofOfValue = 'Proof of Value';

  static const widenBetaGuardrail =
      'No product changes. Increase tester count.';

  static const widenBetaTestReleaseCandidateSmoke =
      'release_candidate_smoke_test.dart';

  static const widenBetaTestBetaReportExport = 'beta_report_export_test.dart';

  static const widenBetaTestProofOfValue = 'proof_of_value_test.dart';
}