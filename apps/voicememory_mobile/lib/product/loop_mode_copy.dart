/// Consumer copy for Loop Mode — no banned language.
abstract class LoopModeCopy {
  LoopModeCopy._();

  // ——— Onboarding ———
  static const String onboardingTitle =
      'What loop do you want ArchiveMe to help you catch first?';
  static const String onboardingStartCta = 'Start this loop';
  static const String onboardingSkip = 'Not sure yet';

  // ——— capacity_yes handoff ———
  static const String capacityHandoffTitle = 'Catch your first yes';
  static const String capacityHandoffBody =
      'Record a moment where you agreed, helped, or took something on before checking whether you had room.';
  static const String capacityHandoffPrompt =
      'When did you say yes before checking your capacity?';
  static const String capacityHandoffCta = 'Record this moment';

  // ——— Interpretation unsupported ———
  static const String capacityUnsupportedTitle =
      'ArchiveMe did not see the capacity loop clearly yet.';
  static const String capacityUnsupportedPrompt =
      'Try recording what you agreed to, what it cost, and what you felt afterward.';

  // ——— Post-save ———
  static const String capacityPostSaveTitle =
      'ArchiveMe is checking the yes-before-capacity loop';
  static const String capacityPostSaveSubtitle =
      'This is not treated as true yet. Your next moments will test whether it repeats.';
  static const String postSavePossibleLoop = 'Possible loop';
  static const String postSaveEvidenceUsed = 'Evidence ArchiveMe used';
  static const String postSaveWouldConfirm = 'What would confirm it';
  static const String postSaveWouldChallenge = 'What would challenge it';
  static const String postSaveRecordNext = 'Record this next';

  static const String capacityWouldConfirm =
      'Saying yes quickly, feeling pressure afterward, agreeing before checking time or energy, or avoiding disappointing someone.';
  static const String capacityWouldChallenge =
      'Choosing freely, having enough capacity, or no guilt or pressure afterward.';

  // ——— Journey ———
  static const String capacityJourneyTitle = 'Yes-before-capacity journey';
  static String capacityProgress(int count) => '$count of 3 yes moments';
  static const String capacityRecordCardTitle = 'Record the next yes moment';
  static const String capacityRecordCardBody =
      'ArchiveMe is watching whether you agree before checking capacity.';
  static const List<String> capacityNextPrompts = [
    'When did you next agree before checking whether you had room?',
    'What did saying yes cost you this time?',
    'What did you avoid by saying yes?',
    'Did you actually have capacity, or did you override it?',
  ];

  // ——— Reminder ———
  static const String capacityReminderPrePromptTitle =
      'Want a reminder to catch the next yes?';
  static const String capacityReminderPrePromptBody =
      'ArchiveMe can remind you tomorrow to record the next moment you agree before checking capacity.';
  static const String capacityReminderNotificationTitle = 'Catch the next yes';
  static const String capacityReminderNotificationBody =
      'Record whether you had capacity before you agreed.';

  // ——— Review ———
  static const String capacityReviewTitle =
      'ArchiveMe reviewed your yes-before-capacity loop';
  static const String capacityReviewSubtitle =
      'So far, this looks like a loop worth watching.';
  static const String reviewWhatRepeated = 'What repeated';
  static const String reviewWhatItCost = 'What it seemed to cost';
  static const String reviewWhatTriggeredYes = 'What triggered the yes';
  static const String reviewWhatChanged = 'What changed';
  static const String reviewEvidenceSoFar = 'Evidence so far';
  static const String reviewProveWrong = 'What would prove this wrong';
  static const String reviewRecordNext = 'Record this next';
  static const String reviewWatchNext = 'What to watch next';
  static const String reviewFeelsRight = 'This feels right';
  static const String reviewCorrect = 'Correct this';
  static const String reviewKeepWatchingLoop = 'Keep watching this loop';
  static const String reviewRecordNextYes = 'Record next yes moment';
  static const String reviewConfirmSaved = 'Saved as a loop to watch.';
  static const String reviewKeepWatchingSaved =
      'ArchiveMe will keep watching this loop.';
  static const String reviewCostFallback =
      'ArchiveMe needs clearer future moments to understand the cost.';
  static const String reviewProveWrongCapacity =
      'You freely chose it, had capacity, and did not feel pressure or guilt afterward.';
  static const String reviewConfidenceEarly = 'Early';
  static const String reviewConfidenceGettingClearer = 'Getting clearer';
  static const String reviewConfidenceWorthWatching = 'Worth watching';
  static const List<String> capacityCorrectionAlternatives = [
    'This is more about not disappointing someone',
    'This is more about taking responsibility automatically',
    'This is more about avoiding saying no',
  ];
  static const List<String> capacityReviewNextPrompts = [
    'When did you next agree before checking whether you had room?',
    'What did saying yes cost you this time?',
    'Did you have capacity, or did you override it?',
    'What would have happened if you paused before saying yes?',
  ];

  // ——— Progress card ———
  static const String progressLooking = 'Looking for first evidence';
  static const String progressEarlySignal = 'Early signal';
  static const String progressGettingClearer = 'Getting clearer';
  static const String progressReadyToReview = 'Ready to review';
  static const String progressRecordNextCta = 'Record next yes moment';
  static const String progressViewLoopCta = 'View loop';

  // ——— Loop detail ———
  static const String detailPromise = 'Promise';
  static const String detailProgress = 'Progress';
  static const String detailEvidence = 'Evidence so far';
  static const String detailNextPrompt = 'Next prompt';
  static const String detailConfirms = 'What confirms it';
  static const String detailChallenges = 'What challenges it';
  static const String detailJourneyLink = 'View signal journey';
  static const String detailReviewLink = 'View loop review';

  // ——— Paywall after loop review ———
  static const String paywallAfterLoopHeadline =
      'Keep tracking this loop over time';
  static const String paywallAfterLoopBody =
      'ArchiveMe can keep the full evidence trail and show whether this loop fades, gets stronger, or changes.';
  static const List<String> paywallAfterLoopBullets = [
    'Track future yes-before-capacity moments',
    'Keep the full evidence trail',
    'See what confirms or challenges the loop',
    'Export monthly pattern reviews',
  ];
  static const String paywallAfterLoopSeePro = 'See Pro';
  static const String paywallAfterLoopNotNow = 'Not now';
  static const String paywallPurchasesUnavailable =
      'Purchases are not available in this build yet.';

  // ——— prove_enough handoff ———
  static const String proveEnoughTitle = 'Trying to prove I am doing enough';
  static const String proveEnoughPromise =
      'Catch the moment you do more because stopping makes you feel behind.';
  static const String proveEnoughHandoffTitle = 'Catch your first proving loop';
  static const String proveEnoughHandoffBody =
      'Record a moment where you kept doing more because stopping made you feel behind, guilty, or not enough.';
  static const String proveEnoughHandoffPrompt =
      'When did you feel pressure to do more to feel okay?';
  static const String proveEnoughHandoffCta = 'Record this moment';

  // ——— prove_enough interpretation unsupported ———
  static const String proveEnoughUnsupportedTitle =
      'ArchiveMe did not see the proving-enough loop clearly yet.';
  static const String proveEnoughUnsupportedPrompt =
      'Try recording what you kept doing, what you were afraid would happen if you stopped, and what felt not enough.';

  // ——— prove_enough post-save ———
  static const String proveEnoughPostSaveTitle =
      'ArchiveMe is checking the proving-enough loop';
  static const String proveEnoughPostSaveSubtitle =
      'This is not treated as true yet. Your next moments will test whether it repeats.';
  static const String proveEnoughWouldConfirm =
      'Doing more to feel okay, feeling behind when stopping, pressure to be productive, measuring enoughness through output, or guilt around rest.';
  static const String proveEnoughWouldChallenge =
      'Choosing effort freely, feeling satisfied, resting without guilt, or working from interest rather than pressure.';

  // ——— prove_enough journey ———
  static const String proveEnoughJourneyTitle = 'Proving-enough journey';
  static String proveEnoughProgress(int count) => '$count of 3 proving moments';
  static const String proveEnoughRecordCardTitle =
      'Record the next proving moment';
  static const String proveEnoughRecordCardBody =
      'ArchiveMe is watching whether you do more because stopping feels unsafe.';
  static const List<String> proveEnoughNextPrompts = [
    'When did you next feel pressure to do more to feel okay?',
    'What did stopping feel like it would cost you?',
    'Where did you feel behind even after doing enough?',
    'Did the extra effort come from choice or pressure?',
  ];

  // ——— prove_enough reminder ———
  static const String proveEnoughReminderPrePromptTitle =
      'Want a reminder to catch the next proving loop?';
  static const String proveEnoughReminderPrePromptBody =
      'ArchiveMe can remind you tomorrow to record the next moment you do more because stopping feels unsafe.';
  static const String proveEnoughReminderNotificationTitle =
      'Catch the next proving loop';
  static const String proveEnoughReminderNotificationBody =
      'Record whether the extra effort came from choice or pressure.';

  // ——— prove_enough review ———
  static const String proveEnoughReviewTitle =
      'ArchiveMe reviewed your proving-enough loop';
  static const String proveEnoughReviewSubtitle =
      'So far, this looks like a loop worth watching.';
  static const String reviewWhatTriggeredEffort =
      'What triggered the extra effort';
  static const String reviewRecordNextProve = 'Record next proving moment';
  static const String reviewProveWrongProveEnough =
      'You chose the effort freely, felt satisfied afterward, and could stop or rest without guilt.';
  static const List<String> proveEnoughCorrectionAlternatives = [
    'This is more about feeling behind when stopping',
    'This is more about needing to feel productive',
    'This is more about measuring worth through output',
  ];
  static const List<String> proveEnoughReviewNextPrompts = [
    'When did you next do more because stopping felt unsafe?',
    'What did the extra effort cost you this time?',
    'Did you feel satisfied afterward, or still behind?',
    'What would have happened if you stopped earlier?',
  ];
  static const String proveEnoughPaywallHeadline =
      'Keep tracking the loop over time';
  static const String proveEnoughPaywallBody =
      'ArchiveMe can keep the full evidence trail and show whether the proving-enough loop fades, gets stronger, or changes.';
  static const List<String> proveEnoughPaywallBullets = [
    'Track future proving-enough moments',
    'See whether effort comes from choice or pressure',
    'Keep the full evidence trail',
    'Export monthly pattern reviews',
  ];
  static const String proveEnoughProgressRecordNextCta =
      'Record next proving moment';

  // ——— Secondary loop stubs (selection only) ———
  static const String relationshipReplayTitle =
      'Replaying relationship moments';
  static const String relationshipReplayPromise =
      'Catch interactions that keep replaying in your head.';
  static const String avoidConversationTitle = 'Avoiding direct conversations';
  static const String avoidConversationPromise =
      'Catch what you avoid saying directly.';
  static const String repeatingHabitTitle = 'Repeating the same habit';
  static const String repeatingHabitPromise =
      'Catch habits you notice but repeat anyway.';
  static const String notSureTitle = 'Not sure yet';
  static const String notSurePromise =
      'Start with one honest moment and see what repeats.';

  static String paywallHeadlineForLoop(String? loopModeId) {
    if (loopModeId == 'prove_enough') return proveEnoughPaywallHeadline;
    return paywallAfterLoopHeadline;
  }

  static String paywallBodyForLoop(String? loopModeId) {
    if (loopModeId == 'prove_enough') return proveEnoughPaywallBody;
    return paywallAfterLoopBody;
  }

  static List<String> paywallBulletsForLoop(String? loopModeId) {
    if (loopModeId == 'prove_enough') {
      return proveEnoughPaywallBullets;
    }
    return paywallAfterLoopBullets;
  }

  static String progressRecordCtaForLoop(String? loopModeId) {
    if (loopModeId == 'capacity_yes') return progressRecordNextCta;
    if (loopModeId == 'prove_enough') return proveEnoughProgressRecordNextCta;
    return 'Record next moment';
  }
}
