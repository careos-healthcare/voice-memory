/// Visible first-run / proof-layer copy — cautious, evidence-based.
abstract final class VisibleArchiveProofCopy {
  // First-run framing — shared across Record and Archive Home.
  static const firstRunBuildingLine =
      'ArchiveMe is building from your saved words.';

  static const firstRunCompareLine =
      'It needs more than one moment to compare.';

  static const firstRunBeliefsNotConclusionsLine =
      'Beliefs are not conclusions.';

  // Record screen top hero (zero entries) — matches Archive Home empty promise.
  static const recordHeroTitle = 'Your archive starts with one moment.';

  static const recordHeroBody =
      '$firstRunBuildingLine Record one honest moment to begin your private archive.';

  static const recordHeroChipReturned = 'What returned';
  static const recordHeroChipSoftened = 'What softened';
  static const recordHeroChipChanged = 'What changed';

  // First save on Record screen.
  static const firstSaveTitle = 'Your archive has started.';

  static const firstSaveBody =
      '$firstRunBuildingLine $firstRunCompareLine';

  static const firstSaveSecondary =
      'No conclusion yet — just one moment saved so far.';

  static const firstSavePrimaryCta = 'Add one more moment';
  static const firstSaveViewArchiveCta = 'View archive';

  // Patterns zero-entry preview.
  static const patternsEmptyPreviewTitle = 'What ArchiveMe will show over time';

  static const patternsEmptyPreviewBody =
      'Once you record a few moments, ArchiveMe compares your own words and '
      'shows what keeps returning, what changes, and the evidence behind it.';

  static const patternsEmptyPreviewBadge =
      'Preview — not a conclusion yet';

  static const patternsEmptyPreviewBeliefRow = 'Not enough evidence yet';
  static const patternsEmptyPreviewEvidenceRow =
      'Your own words across recordings';
  static const patternsEmptyPreviewChangedRow =
      'Whether the same thread gets lighter, stronger, or disappears';

  static const patternsEmptyPreviewCta = 'Record one moment';

  // Patterns one-entry state.
  static const patternsOneEntryTitle =
      'Your archive has one piece of evidence.';

  static const patternsOneEntryBody =
      'Add one more moment and ArchiveMe can start comparing your own words.';

  static const patternsOneEntryBeliefRow = 'Not enough evidence yet';
  static const patternsOneEntryEvidenceRow = '1 saved moment';
  static const patternsOneEntryChangedRow =
      'A second moment can show whether the same thread returns.';

  static const patternsOneEntryCta = 'Add one more moment';

  // Early repeat / two-entry payoff (cautious).
  static const earlyRepeatTitle =
      'ArchiveMe is starting to compare your moments.';

  static const earlyRepeatBody =
      'If the same words or situations keep returning, this is where your '
      'archive will show the thread.';

  static const earlyRepeatEvidenceLine =
      'You now have more than one moment to compare.';

  static const earlyRepeatNextAction =
      'Record once more to strengthen the signal.';

  // Two-entry comparison payoff (second session).
  static const twoEntryCompareTitle =
      'ArchiveMe has two moments to compare.';

  static const twoEntryBodyUngrounded =
      'No clear repeat yet. One more moment will make the thread easier to see.';

  static const twoEntryBodyGrounded =
      'These two moments may be related. ArchiveMe is keeping the evidence '
      'separate until there is more to compare.';

  static const twoEntryPrimaryCta = firstSavePrimaryCta;

  static const twoEntryViewArchiveCta = firstSaveViewArchiveCta;

  static const twoEntryNextAction =
      'Add one more moment to make the thread clearer.';

  // Three-entry belief payoff (cautious, evidence-based).
  static const threeEntryBeliefTitle =
      'ArchiveMe is starting to form a belief.';

  static const threeEntryBeliefBodyIntro =
      'This is not a conclusion yet. It is the first version of what your '
      'archive can compare.';

  static const threeEntryBeliefBodySource =
      'ArchiveMe is using your saved words, not guessing.';

  static const threeEntryBeliefEvidenceLabel = 'Evidence from your archive';

  static const threeEntryBeliefEvidenceThin =
      'The evidence is still thin.';

  static const threeEntryBeliefEvidenceThinAction =
      'Add one more moment to make this clearer.';

  static const threeEntryBeliefPrimaryCta = firstSavePrimaryCta;

  static const threeEntryBeliefViewArchiveCta = firstSaveViewArchiveCta;

  // Four-plus entry belief update — cautious evolution hook.
  static const beliefUpdateTitle = 'Your archive updated its belief.';

  static const beliefUpdateBodyChanged =
      'Something shifted in your saved words.';

  static const beliefUpdateBodyStillBuilding =
      'Your archive is still building evidence.';

  static const beliefUpdateCurrentBeliefLabel = 'Current belief';

  static const beliefUpdateEvidenceLabel = 'Evidence';

  static const beliefUpdateWhatChangedLabel = 'What changed';

  static const beliefUpdateChangeNewContext =
      'This showed up in a new context.';

  static const beliefUpdateChangeDifferentWords =
      'The same feeling appeared again, but with different words.';

  static const beliefUpdateChangeEasierCompare =
      'The evidence is still thin, but it is becoming easier to compare.';

  static const beliefUpdateDefaultBelief =
      'Your archive is beginning to notice similar pressure across your '
      'saved moments.';

  static const beliefUpdateWorkBelief =
      'Your archive is beginning to associate this with pressure around work.';

  static const beliefUpdatePrimaryCta = firstSavePrimaryCta;

  static const beliefUpdateViewEvidenceCta = 'View evidence';

  // Belief evidence drilldown — proof trail behind belief updates.
  static const beliefEvidenceTrailTitle = 'Evidence behind this belief';

  static const beliefEvidenceNotConclusion = 'This is not a conclusion.';

  static const beliefEvidenceSourceLine =
      'ArchiveMe is using your saved words, not guessing.';

  static const beliefEvidenceInsufficientBody =
      'Your archive needs more moments before it can show an evidence trail.';

  static const beliefEvidenceCurrentBeliefLabel = 'Current belief';

  static const beliefEvidenceWhatChangedLabel = 'What changed';

  static const beliefEvidenceArchiveLabel = 'Evidence from your archive';

  static const beliefEvidenceStillUncertainLabel = 'Still uncertain';

  static const beliefEvidenceStillThin = 'The evidence is still thin.';

  static const beliefEvidenceAddNextLabel = 'Add one more moment';

  static const beliefEvidenceNextWhenThin =
      'Add one more distinct moment to make this belief clearer.';

  static const beliefEvidenceNextDefault =
      'Add another moment when this shows up again.';

  // Five-plus entry belief history — cautious change-over-time surface.
  static const beliefHistoryTitleChanged = 'Your archive belief changed.';

  static const beliefHistoryBodyChanged =
      'Earlier, your archive was mostly seeing pressure around one moment. '
      'Now it is seeing that pressure across more than one context.';

  static const beliefHistoryTitleBuilding = 'Belief history';

  static const beliefHistoryBodyNotChanged =
      'Your archive belief has not clearly changed yet.';

  static const beliefHistoryNotEnoughChange =
      'Your archive belief has not clearly changed yet.';

  static const beliefHistoryEarlierBeliefLabel = 'Earlier belief';

  static const beliefHistoryCurrentBeliefLabel = 'Current belief';

  static const beliefHistoryWhatChangedLabel = 'What changed';

  static const beliefHistoryEvidenceLabel = 'Evidence that changed it';

  static const beliefHistoryEarlierOneMoment =
      'Your archive was mostly seeing pressure around one moment.';

  static const beliefHistoryCurrentMultiContext =
      'Your archive appears to see that pressure across more than one context.';

  static const beliefHistoryWhatChangedDefault =
      'A newer moment may have widened what your archive can compare.';

  static const beliefHistoryWhatChangedStillThin =
      'The evidence is still thin, but it is becoming easier to compare.';

  // Five-plus entry weekly archive review — summary retention hook.
  static const weeklyArchiveReviewTitle = 'Your archive review';

  static const weeklyArchiveReviewSubtitle =
      'What your saved words are starting to show.';

  static const weeklyArchiveReviewNotConclusion = 'This is not a conclusion.';

  static const weeklyArchiveReviewSourceLine =
      'ArchiveMe is using your saved words, not guessing.';

  static const weeklyArchiveReviewInsufficientBody =
      'Your archive needs more moments before it can create a review.';

  static const weeklyArchiveReviewStrongestThreadLabel =
      'This week\'s strongest thread';

  static const weeklyArchiveReviewWhatChangedLabel = 'What changed';

  static const weeklyArchiveReviewEvidenceLabel = 'Evidence from your archive';

  static const weeklyArchiveReviewStillUncertainLabel = 'Still uncertain';

  static const weeklyArchiveReviewAddNextLabel = 'What to add next';

  static const weeklyArchiveReviewStillThin = 'The evidence is still thin.';

  static const weeklyArchiveReviewNextDefault =
      'Add one more moment when this shows up again.';

  static const weeklyArchiveReviewNextWhenThin =
      'Add one more distinct moment to make this review clearer.';

  static const weeklyArchiveReviewPrimaryCta = firstSavePrimaryCta;

  static const weeklyArchiveReviewViewEvidenceCta = 'View evidence';

  static const weeklyArchiveReviewViewFullCta = 'View review';

  static const weeklyArchiveReviewStrongestThreadWork =
      'Pressure around work may be the strongest thread in your recent moments.';

  static const weeklyArchiveReviewStrongestThreadDefault =
      'Similar pressure may be the strongest thread in your recent moments.';

  static const weeklyArchiveReviewWhatChangedDefault =
      'Your latest moments may be widening what your archive can compare.';

  static const weeklyArchiveReviewWhatChangedStillThin =
      'The evidence is still thin, but it is becoming easier to compare.';

  // Day-two / return loop — calm next-return framing (no streaks or pressure).
  static const returnLoopOneEntryBody =
      'Come back when this shows up again.';

  static const returnLoopTwoEntryBody =
      'One more moment can make the thread clearer.';

  static const returnLoopThreeEntryBody =
      'Your archive is starting a cautious belief. '
      'Add one more moment to strengthen the evidence.';

  static const returnLoopPrimaryCta = firstSavePrimaryCta;

  static const returnLoopViewArchiveCta = firstSaveViewArchiveCta;

  // One-entry post-save — evidence only, no loop/repeat claims yet.
  static const oneEntryAddedTodayLine = 'You added one piece today.';
  static const oneEntryArchiveLine =
      'ArchiveMe has one moment to compare later.';
  static const oneEntryTomorrowLine =
      'Tomorrow, check whether this shows up again.';
  static const oneEntryAddMoreInvite =
      'Add one more moment when it happens again.';
  static const oneEntryShareableLine =
      'I recorded one moment for my archive.';

  // Share-safe proof — privacy-first growth copy (counts only, never snippets).
  static const shareProofTitle = 'Share-safe proof';

  static const shareProofSubtitle =
      'Share ArchiveMe without exposing private entries.';

  static const shareProofVariantA =
      'I\'m building evidence about what keeps repeating in my life.';

  static const shareProofVariantB =
      'My archive is starting to show what keeps coming back.';

  static const shareProofVariantC =
      'ArchiveMe is helping me notice what repeats — with evidence, not guesses.';

  static const shareProofVariantD =
      'I saved moments. My archive started showing the thread.';

  static const shareProofPrivacyFooter = 'No private entries shared.';

  static const shareProofProductLine =
      'ArchiveMe — your private evidence-based life archive.';

  // Archive Home command center — one surface across the entry ladder.
  static const archiveHomeEmptyTitle = 'Your archive starts with one moment.';

  static const archiveHomeEmptyBody =
      '$firstRunBuildingLine Record one honest moment to begin your private archive.';

  static const archiveHomeOneBody =
      '$firstRunBuildingLine $firstRunCompareLine';

  static const archiveHomeRecordCta = 'Record a moment';

  static const archiveHomeTypeInsteadCta = 'Type instead';

  static const archiveHomeOneTitle = 'Your archive has one piece of evidence.';

  static const archiveHomeBeliefLabel = 'Current belief';

  static const archiveHomeWhatChangedLabel = 'What changed';

  static const archiveHomeEvidenceLabel = 'Evidence from your archive';

  static const archiveHomeNextActionLabel = 'What to add next';

  static const archiveHomeNotEnoughBelief = 'Not enough evidence yet';

  static const archiveHomeNotEnoughChanged =
      'A second moment can show whether the same thread returns.';

  static const archiveHomeViewReviewCta = 'View review';

  // Returning-user Today card on Record (open/return state, not post-save).
  static const returningUserTodaySectionLabel = 'Today';

  static const returningUserOneTitle = 'Add one more moment.';

  static const returningUserOneBody =
      'Your archive has one piece. Come back when this shows up again.';

  static const returningUserTwoTitle =
      'One more moment can make the thread clearer.';

  static const returningUserTwoBody =
      'ArchiveMe has two moments to compare. '
      'A third can help it form a cautious first belief.';

  static const returningUserThreeTitle =
      'Your archive is starting to form a belief.';

  static const returningUserThreeBody =
      'Add one more moment to test whether the evidence holds.';

  static const returningUserFourTitle = 'Your archive updated its belief.';

  static const returningUserFourBody =
      'Review what changed, then add another moment when it shows up again.';

  static const returningUserFivePlusTitle = 'Your archive review is ready.';

  static const returningUserFivePlusBody =
      'See what your saved words are starting to show this week.';

  static const returningUserAddMomentCta = firstSavePrimaryCta;

  static const returningUserViewArchiveCta = firstSaveViewArchiveCta;

  static const returningUserViewEvidenceCta = beliefUpdateViewEvidenceCta;

  static const returningUserViewReviewCta = archiveHomeViewReviewCta;

  // Personalized next-moment prompts — what to capture next (curiosity, not pressure).
  static const nextMomentPromptSectionLabel = archiveHomeNextActionLabel;

  static const nextMomentOneTitle = 'Add one more moment like this.';

  static const nextMomentOneBody =
      'Your archive needs another saved moment before it can compare.';

  static const nextMomentTwoTitle = 'Add the moment that makes this clearer.';

  static const nextMomentTwoBody =
      'ArchiveMe has two moments to compare. '
      'A third can help it form a cautious first belief.';

  static const nextMomentThreeTitle = 'Test this belief with one more moment.';

  static const nextMomentThreeBody =
      'Your archive is starting to form a belief. '
      'Another example can show whether the evidence holds.';

  static const nextMomentFourTitle =
      'Add the moment that would change the evidence.';

  static const nextMomentFourBody =
      'Your archive updated its belief. '
      'Save the next moment when this shows up in a new context.';

  static const nextMomentFivePlusTitle = 'Help your archive review the week.';

  static const nextMomentFivePlusBody =
      'Save the next moment that confirms, weakens, or changes '
      'this week\u2019s strongest thread.';

  static const nextMomentAddCta = firstSavePrimaryCta;

  static const nextMomentViewEvidenceCta = beliefUpdateViewEvidenceCta;

  static const nextMomentViewReviewCta = archiveHomeViewReviewCta;

  // Correction-informed next-moment prompts — user context, not facts.
  static const correctionNextGenericTitle =
      'Add a moment that clarifies your correction.';

  static const correctionNextGenericBody =
      'You marked an archive insight as not quite right. '
      'Save the next example that shows what ArchiveMe missed.';

  static const correctionNextFourTitle = 'Help ArchiveMe retest this belief.';

  static const correctionNextFourBody =
      'Your note says this insight missed something. '
      'Add the next moment that supports, weakens, or changes the evidence.';

  static const correctionNextFiveReviewTitle =
      'Help your review learn from your correction.';

  static const correctionNextFiveReviewBody =
      'Save the next moment that shows whether your correction '
      'holds across more than one example.';

  static const correctionNextThinEvidenceSuffix =
      'The evidence is still thin, so one more saved moment helps.';

  // Archive insight feedback — local trust controls on belief/review surfaces.
  static const insightFeedbackFeelsRight = 'Feels right';

  static const insightFeedbackNotQuite = 'Not quite';

  static const insightFeedbackHideThis = 'Hide this';

  static const insightFeedbackWhySeeing = 'Why am I seeing this?';

  static const insightFeedbackWhySource =
      'ArchiveMe is using your saved words, not guessing.';

  static const insightFeedbackWhyNotConclusion = 'This is not a conclusion.';

  static const insightFeedbackWhyHide =
      'You can hide this if it does not feel useful.';

  // Archive insight feedback adaptation — cautious copy after local Not quite.
  static const insightAdaptationStillTestingBelief =
      'Your archive is still testing this belief.';

  static const insightAdaptationMayNotBeQuiteRight =
      'This may not be quite right yet.';

  static const insightAdaptationNeedsAnotherMoment =
      'The evidence needs another moment before this is useful.';

  static const insightAdaptationSavedUsefulFeedback =
      'Saved as useful feedback.';

  // Private correction notes — local only, never shared.
  static const insightCorrectionAffordance = 'Tell ArchiveMe what it missed';

  static const insightCorrectionPlaceholder = 'Add a private note\u2026';

  static const insightCorrectionSaveCta = 'Save note';

  static const insightCorrectionSkipCta = 'Skip';

  static const insightCorrectionMarkedNotQuite =
      'You marked this as not quite right.';

  static const insightCorrectionYourNotePrefix = 'Your note:';

  // Insight quality dashboard — local feedback review and control.
  static const insightQualityTitle = 'Insight quality';

  static const insightQualitySubtitle =
      'Control what ArchiveMe learns from your feedback. This stays on this device.';

  static const insightQualitySettingsTitle = 'Insight quality';

  static const insightQualitySettingsSubtitle = 'Manage feedback';

  static const insightQualityArchiveLink = 'Manage feedback';

  static const insightQualitySummaryHeading = 'Feedback summary';

  static const insightQualityFeelsRightLabel = 'Feels right';

  static const insightQualityNotQuiteLabel = 'Not quite';

  static const insightQualityHiddenLabel = 'Hidden insights';

  static const insightQualityCorrectionNotesLabel = 'Correction notes';

  static const insightQualityNotQuiteHeading = 'Insights marked Not quite';

  static const insightQualityHiddenHeading = 'Hidden insights';

  static const insightQualityNotesHeading = 'Correction notes';

  static const insightQualityEmptyHeading = 'No local feedback yet';

  static const insightQualityEmptyBody =
      'When you respond to archive insights, your feedback will appear here.';

  static const insightQualityPrivacyHeading = 'Privacy';

  static const insightQualityPrivacyDevice =
      'Your feedback stays on this device.';

  static const insightQualityPrivacyNotes =
      'Correction notes are not shared.';

  static const insightQualityPrivacyShareSafe =
      'Share-safe proof never includes your private notes.';

  static const insightQualityEditNoteCta = 'Edit note';

  static const insightQualityClearFeedbackCta = 'Clear feedback';

  static const insightQualityUnhideCta = 'Unhide';

  static const insightQualityDeleteNoteCta = 'Delete note';

  static const insightQualityCautionMild = 'More cautious copy is active.';

  static const insightQualityCautionElevated =
      'ArchiveMe is still testing this insight.';

  static const insightQualityLabelArchiveHome = 'Archive Home';

  static const insightQualityLabelArchiveHomeThree =
      'Archive Home (three moments)';

  static const insightQualityLabelArchiveHomeFour =
      'Archive Home (four moments)';

  static const insightQualityLabelArchiveHomeFivePlus =
      'Archive Home (weekly review stage)';

  static const insightQualityLabelWeeklyReview = 'Weekly archive review';

  static const insightQualityLabelBeliefEvidence = 'Belief evidence trail';

  static const insightQualityLabelBeliefUpdate = 'Belief update';

  // Archive health — local evidence quality indicator.
  static const archiveHealthTitle = 'Archive health';

  static const archiveHealthSubtitle =
      'Based on usable saved moments on this device.';

  static const archiveHealthUsableMomentsLabel = 'Usable moments';

  static const archiveHealthQualityLabel = 'Evidence quality';

  static const archiveHealthNeedsMoreLabel = 'What needs more evidence';

  static const archiveHealthAddNextLabel = 'What to add next';

  static const archiveHealthThinStatus = 'Evidence is still thin.';

  static const archiveHealthThinBody =
      'Your archive needs another saved moment before it can compare.';

  static const archiveHealthStartingStatus =
      'Your archive is starting to compare.';

  static const archiveHealthStartingBody =
      'One more moment can make the thread clearer.';

  static const archiveHealthFirstBeliefStatus =
      'Your archive has enough to form a cautious first belief.';

  static const archiveHealthFirstBeliefBody = 'Beliefs are not conclusions.';

  static const archiveHealthBeliefUpdateStatus =
      'Your archive has enough evidence to update a belief.';

  static const archiveHealthBeliefUpdateBody =
      'Your archive is getting clearer.';

  static const archiveHealthReviewStatus =
      'Your archive has enough to create a review.';

  static const archiveHealthReviewBody =
      'Evidence is stronger when moments appear across more than one context.';

  static const archiveHealthQualityGettingClearer =
      'Your archive is getting clearer.';

  static const archiveHealthQualityEnoughToReview =
      'Your archive has enough to review.';

  static const archiveHealthExcludedLine =
      'saved moments were too short or unclear to count';

  static const archiveHealthDuplicateLine =
      'Some saved moments look very similar.';

  static const archiveHealthNearDuplicateLine =
      'Some saved moments look nearly the same.';

  static const archiveHealthNotQuiteLine =
      'Some insights were marked not quite right.';

  static const archiveHealthCorrectionLine =
      'Correction notes are active on this device.';

  static const archiveHealthCautionFeedback =
      'Local feedback suggests staying cautious.';

  static const archiveHealthAddNextOne = 'Save one more ordinary moment.';

  static const archiveHealthAddNextTwo =
      'Add one more moment from a different part of your day.';

  static const archiveHealthAddNextThree =
      'Add a moment that tests the first cautious belief.';

  static const archiveHealthAddNextFour =
      'Add a moment that might change what the archive notices.';

  static const archiveHealthAddNextFive =
      'Add a moment from a different context to strengthen the review.';

  static const archiveHealthAddNextWhenDuplicates =
      'Add a moment with different words or context.';

  static const archiveHealthAddNextWhenThin =
      'Add one more distinct saved moment.';

  // Archive health action plan — concrete next steps from health status.
  static const archiveHealthActionPlanTitle = 'Improve your archive';

  static const archiveHealthActionPlanSubtitle =
      'Small steps that make your archive more useful.';

  static const archiveHealthActionPlanItemsLabel = 'What would help next';

  static const archiveHealthActionPlanPrimaryCta = firstSavePrimaryCta;

  static const archiveHealthActionOneEntry =
      'Add one more moment before ArchiveMe compares anything.';

  static const archiveHealthActionTwoEntries =
      'Add a third moment to help form a cautious first belief.';

  static const archiveHealthActionThreeEntries =
      'Add a moment that tests the first cautious belief.';

  static const archiveHealthActionFourEntries =
      'Add a moment that might change what the archive notices.';

  static const archiveHealthActionFivePlus =
      'Add the next moment that confirms, weakens, or changes this week\'s strongest thread.';

  static const archiveHealthActionDuplicates =
      'Add a moment from a different context.';

  static const archiveHealthActionExcluded =
      'Add text to recorded moments that were too unclear.';

  static const archiveHealthActionCorrection =
      'Add a moment that clarifies your correction.';

  // Optional capture context tags — local only, never shared.
  static const captureContextTagTitle = 'Where did this show up?';

  static const captureContextTagHelper =
      'Tags stay on this device and help your archive compare moments.';

  static const captureContextTagSkip = 'Skip';

  static const captureContextTagSave = 'Save tag';

  static const captureContextTagWork = 'Work';

  static const captureContextTagHome = 'Home';

  static const captureContextTagFamily = 'Family';

  static const captureContextTagMoney = 'Money';

  static const captureContextTagHealth = 'Health';

  static const captureContextTagDecision = 'Decision';

  static const captureContextTagRelationship = 'Relationship';

  static const captureContextTagOther = 'Other';

  static const entryContextTagNone = 'No context tag';

  static String entryContextTagPresent(String label) => 'Context: $label';

  static const entryContextTagEdit = 'Edit context';

  static const entryContextTagEditTitle = 'Edit context tag';

  static const entryContextTagClear = 'Clear tag';

  static const entryContextTagCancel = 'Cancel';

  static const archiveHealthSingleContextTagLine =
      'Tagged moments so far share one context.';

  static const archiveHealthVariedContextTagLine =
      'Tagged moments may span more than one context.';

  static const weeklyArchiveReviewVariedContextNote =
      'Tagged moments may span more than one context.';

  // Context insights — local tag distribution readout.
  static const contextInsightsTitle = 'Where this shows up';

  static const contextInsightsSubtitle =
      'Based on optional tags saved on this device.';

  static const contextInsightsOneTagged =
      'Your archive has one tagged moment.';

  static const contextInsightsAddAnotherTagged =
      'Add another tagged moment to compare contexts.';

  static String contextInsightsMostlyIn(String label) =>
      'This is mostly showing up in $label.';

  static const contextInsightsAddDifferentContext =
      'Add a moment from a different context to see whether it travels.';

  static const contextInsightsAcrossContexts =
      'This is showing up across more than one context.';

  static const contextInsightsStillThin =
      'The context evidence is still thin.';

  static const contextInsightsTopContextsLabel = 'Tagged moments by context';

  // Context-aware supporting copy — subtle lines outside Context Insights card.
  static const contextAwareStillThin = contextInsightsStillThin;

  static String contextAwareMostlyAt(String tagId) {
    switch (tagId) {
      case 'work':
        return 'This is mostly showing up at work.';
      case 'home':
        return 'This is mostly showing up at home.';
      default:
        return 'This is mostly showing up around ${_captureContextLabelForId(tagId)}.';
    }
  }

  static String _captureContextLabelForId(String tagId) {
    switch (tagId) {
      case 'work':
        return captureContextTagWork;
      case 'home':
        return captureContextTagHome;
        return captureContextTagFamily;
      case 'money':
        return captureContextTagMoney;
      case 'health':
        return captureContextTagHealth;
      case 'decision':
        return captureContextTagDecision;
      case 'relationship':
        return captureContextTagRelationship;
      case 'other':
        return captureContextTagOther;
      default:
        return tagId;
    }
  }

  static const contextAwareAddDifferentContext = contextInsightsAddDifferentContext;

  static const contextAwareAcrossContexts =
      'This has shown up in more than one context.';

  static String contextAwareCompareAcross(String first, String second) =>
      'Your archive is beginning to compare this across $first and $second.';

  // Archive evidence map — local context distribution readout.
  static const archiveEvidenceMapTitle = 'Evidence map';

  static const archiveEvidenceMapSubtitle =
      'Where your saved moments are showing up on this device.';

  static const archiveEvidenceMapNotEnough =
      'Your archive needs a saved moment before it can map evidence.';

  static const archiveEvidenceMapOneTagged =
      'Your evidence map has one tagged moment.';

  static const archiveEvidenceMapAddAnother =
      'Add another moment to compare contexts.';

  static String archiveEvidenceMapMostEvidenceIn(String label) =>
      'Most evidence is currently in $label.';

  static const archiveEvidenceMapAddDifferentContext =
      'Add a moment from a different context to see whether it travels.';

  static const archiveEvidenceMapSpansContexts =
      'Your evidence spans more than one context.';

  static const archiveEvidenceMapUntaggedSuggest =
      'Add context tags to make your evidence map clearer.';

  static const archiveEvidenceMapExcludedNote =
      'Unclear recordings are excluded from evidence quality.';

  static const archiveEvidenceMapStrongestLabel = 'Strongest context';

  static const archiveEvidenceMapThinLabel = 'Thin contexts';

  static const archiveEvidenceMapUntaggedLabel = 'Untagged moments';

  static const archiveEvidenceMapNextLabel = 'What to add next';

  static const archiveEvidenceMapUntaggedRow = 'Untagged';

  static String archiveEvidenceMapUntaggedCount(int count) =>
      count == 1
          ? '1 moment does not have a context tag yet.'
          : '$count moments do not have a context tag yet.';

  static String archiveEvidenceMapThinContexts(List<String> labels) {
    if (labels.length == 1) {
      return '${labels.first} still has only one moment.';
    }
    if (labels.length == 2) {
      return '${labels[0]} and ${labels[1]} still have only one moment each.';
    }
    final head = labels.sublist(0, labels.length - 1).join(', ');
    return '$head, and ${labels.last} still have only one moment each.';
  }

  static String archiveEvidenceContextTitle(String label) =>
      'Evidence in $label';

  static const archiveEvidenceContextUntaggedTitle = 'Untagged evidence';

  static const archiveEvidenceContextSubtitle =
      'Saved moments counted in your evidence map.';

  static const archiveEvidenceContextEmpty =
      'No saved moments are counted in this context right now.';

  static const archiveEvidenceContextOpenEntry = 'Open entry';

  static const evidenceAttentionFiltersTitle = 'Needs attention';

  static const evidenceAttentionFilterUntagged = 'Untagged';

  static const evidenceAttentionFilterThinContexts = 'Thin contexts';

  static const evidenceAttentionFilterSameContext = 'Same context';

  static const evidenceAttentionFilterCorrections = 'Corrections';

  static const evidenceAttentionFilterHidden = 'Hidden';

  static const archiveWorkspaceNeedsAttentionHeading = 'Needs attention';

  static const archiveWorkspaceEvidenceQualityHeading = 'Evidence quality';

  static const archiveWorkspaceReviewHistoryHeading = 'Review and history';

  static const archiveWorkspaceControlsHeading = 'Controls';

  static const archiveWorkspaceQuickActionsTitle = 'Next best actions';

  static const archiveWorkspaceQuickActionAddMoment = 'Add one more moment';

  static const archiveWorkspaceQuickActionTagUntagged = 'Tag untagged entries';

  static const archiveWorkspaceQuickActionReviewCorrections =
      'Review corrections';

  static const archiveWorkspaceQuickActionViewEvidenceMap =
      'View evidence map';

  static const archiveWorkspaceQuickActionViewWeeklyReview =
      'View weekly review';

  static const archiveWorkspaceQuickActionShareProofSafely =
      'Share proof safely';

  // Static empty belief proof rows (Archive/Patterns proof card).
  static const emptyProofBelief = patternsEmptyPreviewBeliefRow;
  static const emptyProofEvidence = patternsEmptyPreviewEvidenceRow;
  static const emptyProofChanged = patternsEmptyPreviewChangedRow;
}
