/// Consumer-facing UI copy — calm, human, App Store-ready.
abstract class ConsumerUiCopy {
  ConsumerUiCopy._();

  // ——— ArchiveMe competitive positioning ———
  static const String archivePositioningHeadline =
      'Catch the loop where doing more never feels like enough.';
  static const String archivePositioningSubhead =
      'Record short moments. ArchiveMe helps you test whether pressure, productivity, and enoughness keep repeating.';
  static const String archiveMemoryPromise =
      'ArchiveMe helps you catch the proving loop earlier next time.';
  static const String archiveLoopPromise =
      'Record one moment. Test whether the loop repeats.';
  static const String archiveNotChatLine =
      'Not a chat. A memory for your patterns.';
  static const String archivePatternOverTimeLine =
      'See what changed across days and weeks.';
  static const String archiveMomentsMatterLine =
      'Find the moments that mattered.';
  static const String archiveClearerEachCheckLine =
      'Every check makes the pattern clearer.';
  static const String archiveBasedOnMomentsLine =
      'Based on moments across days and weeks.';
  static const String archiveTimelineSubtitle =
      'See how this has changed over time.';
  static const String patternsEarlyStateBody =
      'Record short moments. ArchiveMe looks for loops where pressure, productivity, and enoughness keep repeating.';
  static const String onboardingPositioningHeadline =
      'Notice the pressure loops that keep repeating';
  static const String onboardingPositioningBody =
      'Three quick steps. Then you start seeing what comes back.';

  // ——— Launch onboarding (promise + 3 steps) ———
  static const String onboardingStep1Title = 'Record one small moment';
  static const String onboardingStep1Body =
      'Say what happened in your own words. A few sentences is enough.';
  static const String onboardingStep2Title = 'ArchiveMe notices what repeats';
  static const String onboardingStep2Body =
      'After a second moment, ArchiveMe shows what looks similar.';
  static const String onboardingStep3Title =
      'Return tomorrow to see what changed';
  static const String onboardingStep3Body =
      'Come back and compare what stayed, shifted, or faded.';
  static const String onboardingPage2Title = onboardingStep1Title;
  static const String onboardingPage2Body = onboardingStep1Body;
  static const String onboardingPage3Title = onboardingStep2Title;
  static const String onboardingPage3Body = onboardingStep2Body;
  static const String onboardingPage4Title = onboardingStep3Title;
  static const String onboardingPage4Body = onboardingStep3Body;
  static const String onboardingPage5Title = onboardingPage4Title;
  static const String onboardingPage5Body = onboardingPage4Body;
  static const String onboardingFinalCta = 'Start my archive';
  static const String onboardingContinueCta = 'Continue';
  static const String recordOneMomentCta = 'Record one moment';
  static const String recordMomentCta = 'Record moment';
  static const String stopRecordingCta = 'Stop recording';
  static const String doneCta = 'Done';
  static const String recordAnotherCta = 'Record another';

  // ——— First-run record handoff (prove default when no loop) ———
  static const String firstRecordingHandoffTitle =
      'Catch your first proving loop';
  static const String firstRecordingHandoffBody =
      'Record a moment where you kept doing more because stopping made you feel behind, guilty, or not enough.';
  static const String firstRecordingHandoffPromptLabel = 'Start with this:';
  static const String firstRecordingHandoffDefaultPrompt =
      'When did you feel pressure to do more to feel okay?';
  static const String firstRecordingHandoffCta = 'Record this moment';

  // ——— Reminder pre-prompt ———
  static const String reminderPrePromptTitle = 'Want a reminder to test this?';
  static const String reminderPrePromptBody =
      'ArchiveMe can remind you to record the next evidence moment.';
  static const String reminderPrePromptAllowCta = 'Remind me tomorrow';
  static const String reminderPrePromptDismissCta = 'Not now';

  // ——— Post-save read micro feedback ———
  static const String readMicroFeedbackQuestion = 'Was this read useful?';
  static const String readMicroFeedbackUseful = 'Useful';
  static const String readMicroFeedbackNotQuite = 'Not quite';

  // ——— First-use sharpness check ———
  static const String firstInsightSharpnessQuestion =
      'Did this feel specific to what you recorded?';
  static const String firstInsightSharpnessYes = 'Yes, specific';
  static const String firstInsightSharpnessTooGeneric = 'Too generic';
  static const String firstInsightSharpnessWrongAngle = 'Wrong angle';
  static const String firstInsightDisclaimer =
      'Do not treat this as true yet. Use the next moment to test it.';
  static const String firstInsightTooGenericPrompt =
      'Try one more moment with what happened, what you did, and what felt heavy.';
  static const List<String> firstInsightChoiceTitles = [
    'This may be the loop to watch',
    'ArchiveMe found a possible decision loop',
    'This could be the pattern starting to show',
  ];
  static String firstInsightChoiceTitleFor(int seed) =>
      firstInsightChoiceTitles[seed.abs() % firstInsightChoiceTitles.length];
  static const String firstInsightChoiceLead =
      'Pick the read that feels closest. ArchiveMe sharpens from what you choose.';
  static const String firstInsightPossibleLoop = 'Possible loop';
  static const String firstInsightEvidenceUsed = 'Evidence used';
  static const String firstInsightWouldConfirm = 'What would confirm it';
  static const String firstInsightWouldContradict = 'What would prove it wrong';
  static const String firstInsightNextEvidence = 'Next evidence prompt';

  // ——— Onboarding audience wedge ———
  static const String acquisitionIntentQuestion =
      'What pressure loop do you want to catch?';
  static const String acquisitionIntentSkip = 'Skip';
  static const String reminderNotAvailableInBuild =
      'Reminder not available in this build.';

  // ——— Next evidence reminder ———
  static const String nextEvidenceReminderTitle = 'Record next evidence';
  static const String nextEvidenceReminderBodyDefault =
      'ArchiveMe is watching whether this signal repeats.';
  static const String nextEvidenceReminderBodyWithPrompt =
      'ArchiveMe is watching: {prompt}';

  // ——— Return-day signal journey ———
  static const String returnDayJourneyTitle = 'Continue the signal journey';
  static const String returnDayJourneyBodyTemplate =
      'ArchiveMe is watching: {title}. Record one more moment to test whether it repeats.';
  static const String returnDayJourneyRecordCta = 'Record next evidence';
  static const String returnDayJourneyViewCta = 'View journey';
  static const String returnDayEvidenceSavedTitle = 'Evidence saved for today';
  static const String returnDayEvidenceSavedCta = 'View what changed';

  // ——— Positioning comprehension rescue ———
  static const String firstRecordPositioningLine =
      'Each moment helps ArchiveMe remember the pattern.';
  static const String archiveMemoryDemoTitle =
      'ArchiveMe remembers what repeats';
  static const List<String> archiveMemoryDemoRows = [
    'Day 1: “I said yes before checking what I needed.”',
    'Day 3: “It showed up again before a work message.”',
    'Day 7: “It felt lighter after I paused.”',
  ];
  static const String archiveMemoryDemoRememberLine =
      'ArchiveMe remembers: You often carry pressure before saying yes.';
  static const String archiveMemoryDemoCta = recordOneMomentCta;
  static const String archiveMemoryPreviewTitle =
      'What ArchiveMe will remember';
  static const String archiveMemoryPreviewBody =
      'After a few moments, ArchiveMe will show what repeats, what changes, and what helps.';
  static const List<String> archiveMemoryPreviewBullets = [
    'What keeps showing up',
    'What feels lighter or heavier',
    'What to check next',
  ];
  static const String archiveMemoryPreviewCta = 'Record one moment';

  /// Legacy aliases — prefer the archive* constants above in new copy.
  static const String positioningRemembersRepeating =
      'ArchiveMe remembers what keeps repeating.';
  static const String positioningRecordAndCheck = archiveLoopPromise;
  static const String positioningNotAChat = archiveNotChatLine;
  static const String positioningBasedOnMoments = archiveBasedOnMomentsLine;
  static const String positioningClearerEachCheck = archiveClearerEachCheckLine;
  static const String recordNextMomentCta = 'Record next moment';

  // ——— Patterns tab ———
  static const String patternsTabLabel = 'Patterns';
  static const String patternsHeroHeading = 'WHAT KEEPS REPEATING IN YOUR LIFE';
  static const String patternsShiftingHeading = 'WHAT MAY BE CHANGING';
  static const String patternsEvolutionHeading = 'CHANGING OVER TIME';
  static const String patternsTensionsHeading = 'WHEN PATTERNS CONFLICT';
  static const String patternsWhatMayComeNextHeading = 'WHAT MAY HAPPEN NEXT';
  static const String patternsWorthNoticingHeading = 'SOMETHING WORTH NOTICING';
  static const String patternsRecordCta = 'Record another moment';

  static const String patternsEmptyPageTitle =
      'Your archive starts with one moment.';
  static const String patternsFirstEntrySavedTitle =
      'Your first moment is saved.';
  static const String patternsFirstEntrySavedBody =
      'ArchiveMe needs one more moment before it can compare what repeats.';
  static const String patternsFirstEntrySavedHelper =
      'Come back tomorrow or record another moment when something feels familiar.';
  static const String patternsFirstEntrySavedCta = 'Add another moment';
  static const String patternsFirstEntryViewSavedCta = 'View saved entry';

  /// Legacy alias — prefer [patternsFirstEntrySavedTitle].
  static const String patternsOneMomentTitle = patternsFirstEntrySavedTitle;

  /// Legacy alias — prefer [patternsFirstEntrySavedBody].
  static const String patternsOneMomentBody = patternsFirstEntrySavedBody;

  /// Legacy alias — prefer [patternsFirstEntrySavedCta].
  static const String patternsOneMomentCta = patternsFirstEntrySavedCta;
  static const String patternsEmptyTitle = patternsEmptyPageTitle;
  static const String patternsEmptySubtitle = patternsEarlyStateBody;
  static const String patternsHeroCardTitle = patternsEmptyPageTitle;
  static const String patternsHeroCardBody = patternsEarlyStateBody;
  static const String patternsEmptyCta = 'Record one moment';
  static const String patternsExamplesLead =
      'Examples of patterns you may notice later';
  static const List<String> patternsScreenshotExamples = [
    'A moment that keeps showing up',
    'What felt lighter today',
    'What changed after you paused',
  ];
  static const String patternsHowItWorksTitle = 'How it works';
  static const List<String> patternsHowItWorksSteps = [
    'Record one clear moment',
    'ArchiveMe connects moments that keep showing up',
    'You see what is strengthening, fading, or changing',
  ];
  static const String patternsPrivacyReassurance =
      'No judgement. No public feed. Your reflections stay private.';
  static const String viewAllPatterns = 'See all patterns';
  static const String seeWhatChanged = 'See what changed';

  // ——— All patterns list ———
  static const String allPatternsTitle = 'All patterns';
  static const String allPatternsLead =
      'Patterns and themes ArchiveMe keeps noticing in your reflections.';
  static const String patternsSectionCurrent = 'Patterns that keep repeating';
  static const String patternsSectionEmerging = 'A pattern is forming';
  static const String patternsSectionChanging = 'This seems to be changing';
  static const String patternsSectionHidden = 'Quiet patterns';

  // ——— What is changing ———
  static const String changesScreenTitle = 'What is changing';
  static const String changesScreenLead =
      'Stories about patterns getting stronger, fading, or shifting.';
  static const String changesEmptyLead =
      'When you have enough reflections, you will see stories here — not charts.';

  // ——— Pattern detail ———
  static const String patternDetailTitle = 'Pattern';
  static const String labelPattern = 'Pattern';
  static const String labelConfidence = 'Confidence';
  static const String labelBasedOn = 'Based on your reflections';
  static const String labelWhy = 'Why you may be seeing this';
  static const String labelWhyItMatters = 'Why it matters';
  static const String labelPatternNote = 'In your own words';
  static const String labelWhat = 'What';
  static const String labelMoments = 'Moments you mentioned';
  static const String labelWhatThisMeans = 'What this may mean';
  static const String detailMomentsSection = 'Moments from your reflections';
  static const String detailWhatThisMeans = 'What this may mean for you';
  static const String basedOnReflectionsCount =
      'Based on your recent reflections';

  // ——— Pattern cards (hero + insights) ———
  static const String addReflectionTitle = 'Add a reflection';
  static const String addReflectionLead =
      'Each new moment helps surface what keeps repeating.';

  // ——— Record ———
  static const String recordTitle = 'What is on your mind?';
  static const String recordSubtitle = 'Say one small thing from today.';
  static const String trySayingOneOfThese = 'Try saying one of these';
  static const String trySayingLabel = 'Try saying:';
  static const String showMorePromptIdeas = 'Show more prompt ideas';
  static const String recordHelpSheetTitle = 'Pick a prompt';
  static const String recordHelpSheetHelper =
      'Choose one, then record one sentence.';
  static const String startRecording = 'Start recording';
  static const String continueBuildingPatterns =
      'Keep adding reflections to sharpen your patterns.';
  static const List<String> recordTopicChips = [
    'Work',
    'Relationships',
    'Health',
    'Something repeating',
  ];
  static const List<String> recordStarterPrompts = [
    'What has been looping in your head today?',
    'What felt heavy or unresolved this week?',
    'What moment showed up again today?',
    'What would feel like a relief if it changed?',
  ];
  static const List<String> recordHelpSheetPrompts = [
    'What has been looping in your head today?',
    'What decision are you avoiding?',
    'What did you react strongly to recently?',
    'What are you worried might happen?',
    'What keeps repeating in this situation?',
  ];
  static const String reflectionSavedTitle = 'Reflection saved';
  static const String possiblePatternForming = 'A pattern may be forming';
  static const String postSaveConfidence = 'How clear it feels';
  static const String postSaveBasedOn = 'How often it shows up';
  static const String postSaveRecordAnother = 'Record another moment';
  static const String firstSignalSavedTitle = 'First signal saved';
  static const String firstSignalSavedBody =
      'Record one more clear moment and ArchiveMe can compare what repeats.';
  static const String firstSignalSavedSecondary =
      'Record once more tomorrow to make the pattern clearer.';
  static const String viewPatternsCta = 'View patterns';
  static const String back = 'Back';

  // ——— Post-save possible signals ———
  static const String postSaveInsightChoiceTitle =
      'ArchiveMe noticed possible signals';
  static const String postSaveInsightChoiceLead =
      'Pick the one that feels closest. ArchiveMe gets sharper from what you choose.';
  static const String postSaveInsightFeelsTrue = 'This feels true';
  static const String postSaveInsightNotMe = 'Not me';
  static const String postSaveInsightNotQuite = postSaveInsightNotMe;
  static const String postSaveInsightGoDeeper = 'Go deeper';
  static const String postSaveInsightMightMean = 'What this might mean';
  static const String postSaveInsightWouldConfirm = 'What would confirm it';
  static const String postSaveInsightWouldContradict =
      'What would contradict it';
  static const String postSaveInsightRecordNext =
      'A better question to record next';
  static const String postSaveInsightRecordNextEvidence =
      'Record next evidence';
  static const String postSaveInsightSaveSignal = 'Save signal';
  static const String postSaveInsightAnotherAngle = 'Show another angle';
  static const String postSaveInsightAlternativeTitle =
      'Another way to read this';
  static const String postSaveInsightAlternativeLead =
      'ArchiveMe can look at the same moment from a different angle.';
  static const String postSaveInsightSavedAck = 'Saved as evidence.';
  static const String postSaveInsightEvidenceFromMoment = 'From your moment';
  static const String postSaveInsightWhySuggested =
      'Why ArchiveMe suggested this';
  static const String postSaveInsightEvidenceUsed = 'Evidence ArchiveMe used';
  static const String postSaveInsightNeedsClearerMoment =
      'ArchiveMe needs one clearer moment';
  static const String postSaveInsightNeedsClearerLead =
      'Say what happened, what you did, and what felt heavy. ArchiveMe works best with one concrete moment.';
  static const String postSaveInsightAbChoiceTitle = 'Which read feels closer?';
  static const String postSaveInsightAbFeelsCloserA = 'A feels closer';
  static const String postSaveInsightAbFeelsCloserB = 'B feels closer';
  static const String postSaveInsightAbNeither = 'Neither';
  static const String postSaveInsightUseAsEvidence =
      'ArchiveMe will use that as evidence.';
  static const String postSaveInsightRecordThisNext = 'Record this next';
  static const String postSaveInsightUseThisPrompt = 'Use this prompt';
  static const String postSaveInsightChooseAnotherPrompt =
      'Choose another prompt';
  static const String postSaveInsightNextPromptSaved = 'Next prompt saved';
  static const String postSaveInsightMomentsProgress =
      '{count} of 3 moments recorded';
  static const String patternHypothesisTitle =
      'ArchiveMe has a working hypothesis';
  static const String patternHypothesisLead =
      'This may not be final, but these moments seem connected.';
  static const String patternHypothesisMightBe = 'The pattern might be';
  static const String patternHypothesisEvidence = 'Evidence so far';
  static const String patternHypothesisProveWrong = 'What would prove it wrong';
  static const String patternHypothesisWatchNext = 'What to watch next';
  static const String patternHypothesisFeelsRight = 'This feels right';
  static const String patternsSignalsWaitingTitle =
      'Signals waiting for confirmation';
  static const String patternsSignalsWaitingClarity =
      'What would make this clearer';
  static const String patternsWatchingSignalTitle =
      'ArchiveMe is watching this signal';
  static const String patternsWatchingSignalBody =
      'Needs one more moment to confirm whether it repeats.';

  // ——— Signal archive surfaces ———
  static const String signalDetailEmptyTitle = 'No saved signal yet';
  static const String signalDetailEmptyBody =
      'Record a moment and choose the read that feels closest.';
  static const String signalDetailRecordMoment = 'Record a moment';
  static const String signalDetailPageTitle = 'Signal detail';
  static const String signalDetailThinksMayBe =
      'What ArchiveMe thinks this may be';
  static const String signalDetailEvidenceSoFar = 'Evidence so far';
  static const String signalDetailWouldConfirm = 'What would confirm it';
  static const String signalDetailWouldProveWrong = 'What would prove it wrong';
  static const String signalDetailRecordNext = 'Record this next';
  static const String signalDetailFeedbackLabel = 'Your feedback';
  static const String signalDetailFeedbackTrue = 'This feels true';
  static const String signalDetailFeedbackNotMe = 'Not me';
  static const String signalDetailFeedbackAnother = 'Another angle';
  static const String signalDetailViewEvidenceTrail = 'View evidence trail';
  static const String signalDetailMarkNotMe = 'Mark not me';
  static const String signalDetailViewSignal = 'View signal detail';

  static const String signalEvidenceTitle = 'Evidence trail';
  static const String signalEvidenceNeedsMore = 'Needs more evidence';
  static const String signalEvidenceNeedsMoreBody =
      'ArchiveMe needs at least two moments before this trail is useful.';
  static const String signalEvidenceSupporting = 'Supporting moments';
  static const String signalEvidenceContradicting = 'Possible contradictions';
  static const String signalEvidenceWhatClearer =
      'What would make this clearer';
  static const String signalEvidenceNextPrompt = 'Next evidence prompt';

  static const String archiveWatchingTitle = 'ArchiveMe is watching';
  static const String archiveWatchingEmpty =
      'Record a moment and ArchiveMe will start watching for repeats.';
  static const String archiveWatchingRecordEvidence = 'Record evidence';
  static const String archiveWatchingHypothesisLabel = 'Working hypothesis';

  static const String signalCorrectionsTitle = 'What you corrected';
  static const String signalCorrectionsRejected = 'Rejected reads';
  static const String signalCorrectionsSelected = 'Selected alternative';
  static const String signalCorrectionsNote =
      'ArchiveMe will avoid showing this first unless stronger evidence appears.';
  static const String signalCorrectionsFeedbackNote =
      'ArchiveMe will use this as feedback.';

  static const String archiveHomeTitle = 'Your archive right now';
  static const String archiveHomeLead =
      'ArchiveMe is watching for what repeats, changes, or fades.';
  static const String archiveHomeSharpen =
      'Record one more moment to sharpen the signal.';
  static const String archiveHomeWatching = 'Signal being watched';
  static const String archiveHomeEvidenceCount = 'Evidence moments';
  static const String archiveHomeOpenDetail = 'Signal detail';
  static const String archiveHomeOpenTrail = 'Evidence trail';
  static const String archiveHomeOpenPatterns = 'Patterns';
  static const String archiveHomeRecordEvidence = 'Record evidence';

  // ——— Signal journey ———
  static const String signalJourneyTitle = 'Signal journey';
  static const String signalJourneyWatchingTemplate =
      'ArchiveMe is watching: {title}.';
  static const String signalJourneyProgress =
      '{count} of {target} moments recorded';
  static const String signalJourneyRecordMore =
      'Record one more moment to test whether this repeats.';
  static const String signalJourneyRecordMoreComplete =
      'ArchiveMe has enough moments to watch this signal.';
  static const String signalJourneyRecordEvidence = 'Record next evidence';
  static const String signalJourneyViewJourney = 'View journey';
  static const String signalJourneyStatusCollecting = 'Working signal';
  static const String signalJourneyStatusGettingClearer = 'Getting clearer';
  static const String signalJourneyStatusConfirmed =
      'Confirmed enough to watch';
  static const String signalJourneyStatusContradicted = 'Evidence mixed';
  static const String signalJourneyStatusArchived = 'Archived';
  static const String signalJourneyDetailTitle = 'Signal journey';
  static const String signalJourneyEmptyTitle = 'No active signal journey yet';
  static const String signalJourneyEmptyBody =
      'Record a moment and choose a read that feels closest.';
  static const String signalJourneyEvidenceSoFar = 'Evidence so far';
  static const String signalJourneyWouldConfirm = 'What would confirm it';
  static const String signalJourneyWouldChallenge = 'What would challenge it';
  static const String signalJourneyRecordNext = 'Record this next';
  static const String signalJourneyArchiveSignal = 'Archive this signal';
  static const String signalJourneyCompletionTitle =
      'This signal is getting clear';
  static const String signalJourneyCompletionBody =
      'ArchiveMe has seen this across 3 moments. It may be worth watching.';
  static const String signalJourneyCompletionRepeated = 'What repeated';
  static const String signalJourneyCompletionChanged = 'What changed';
  static const String signalJourneyCompletionWatchNext = 'What to watch next';
  static const String signalJourneyCompletionRepeatedTemplate =
      '{title} showed up across {count} moments.';
  static const String signalJourneyCompletionChangedNone =
      'No strong contradictions yet — the read held across moments.';
  static const String signalJourneyCompletionChangedSome =
      'Some moments did not fit this read — ArchiveMe is keeping both sides.';
  static const String signalJourneyCompletionWatchDefault =
      'Notice whether the same theme shows up in your next moment.';
  static const String signalJourneyKeepWatching = 'Keep watching';
  static const String signalJourneyViewPattern = 'View pattern';
  static const String signalJourneyPatternsActive = 'Active signal journey';
  static const String signalJourneyPatternsConfirmed =
      'Confirmed enough to watch';

  // ——— Signal review ———
  static const String signalReviewCardTitle = 'ArchiveMe reviewed this signal';
  static const String signalReviewWhatRepeated = 'What repeated';
  static const String signalReviewWhatChanged = 'What changed';
  static const String signalReviewEvidenceSoFar = 'Evidence so far';
  static const String signalReviewWhatToWatchNext = 'What to watch next';
  static const String signalReviewPossibleWrong = 'What could prove this wrong';
  static const String signalReviewFeelsRight = 'This feels right';
  static const String signalReviewCorrectThis = 'Correct this';
  static const String signalReviewKeepWatching = 'Keep watching';
  static const String signalReviewViewFull = 'View full review';
  static const String signalReviewConfirmPattern = 'Confirm pattern';
  static const String signalReviewCorrectRead = 'Correct the read';
  static const String signalReviewRecordNext = 'Record next evidence';
  static const String signalReviewViewTrail = 'View evidence trail';
  static const String signalReviewEmptyTitle = 'No signal review yet';
  static const String signalReviewEmptyBody =
      'Collect 3 moments in a signal journey and ArchiveMe will review what is becoming clearer.';
  static const String signalReviewRecordMoment = 'Record a moment';
  static const String signalReviewNeedsMoreEvidence =
      'ArchiveMe needs more evidence before it can review this signal.';
  static const String signalReviewSavedCorrection =
      'Saved. ArchiveMe will use this correction when it reads future moments.';
  static const String signalReviewSavedPattern = 'Saved as a pattern to watch.';
  static const String signalReviewWatchingSaved =
      'ArchiveMe will keep watching this signal.';
  static const String signalReviewViewPattern = 'View pattern';
  static const String signalReviewCorrectionTitle = 'Pick a closer read';
  static const String signalReviewStatusDraft = 'Needs more evidence';
  static const String signalReviewStatusReady = 'Ready to review';
  static const String signalReviewStatusConfirmed = 'Confirmed pattern';
  static const String signalReviewStatusCorrected = 'Corrected read';
  static const String signalReviewStatusWatching = 'Still watching';
  static const String signalReviewRepeatedTemplate =
      'So far, “{title}” seems to show up across {count} moments.';
  static const String signalReviewChangedNone =
      'No strong contradictions yet — the read may still hold.';
  static const String signalReviewChangedSome =
      'Some moments did not fit this read — ArchiveMe is keeping both sides.';
  static const String signalReviewChangedWithEvidence =
      'Some moments may not fit this read — worth watching both sides.';
  static const String signalReviewContradictionsDefault =
      'A moment that clearly goes the other way would test this read.';
  static const String signalReviewNextEvidenceDefault =
      'Record one more moment on the same theme.';

  // ——— Second-session comparison ———
  static const String secondSessionPossibleRepeatTitle =
      'ArchiveMe found a possible repeat';
  static const String secondSessionSoundsClose =
      'This looks close to something you recorded before.';
  static const String secondSessionFallbackWhatRepeated =
      'You may be doing more to avoid feeling behind.';
  static const String secondSessionFallbackWhatChanged =
      'This time, the pressure showed up around saying yes too quickly.';
  static const String secondSessionFallbackWhatToTestNext =
      'Before saying yes, check whether you actually have capacity.';
  static const String secondSessionCompareTemplate =
      'The earlier moment was about {previous}. This one may be about {latest}.';
  static const String secondSessionBetterEvidence =
      'That gives ArchiveMe better evidence to watch.';
  static const String secondSessionWhatRepeated = 'What repeated';
  static const String secondSessionWhatChanged = 'What changed';
  static const String secondSessionWhatToTestNext = 'What to test next';
  static const String secondSessionNotTheSame = 'Not the same';
  static const String secondSessionNeedMoreMoments =
      'ArchiveMe needs one more moment to compare this properly.';
  static const String earlyObservationsNote =
      'Early take — it gets clearer as you add more reflections.';
  static const String instantPatternLead = 'A pattern that may be forming';
  static const String instantStillLearning =
      'Keep recording — patterns get clearer with more moments.';
  static const String instantMomentsLabel = 'Moments you mentioned:';
  static const String showMoments = 'Show moments';
  static const String hideMoments = 'Hide moments';

  // ——— Account ———
  static const String accountTitle = 'ArchiveMe account';
  static const String syncStatus = 'Sync status';
  static const String syncNotAvailableTestFlight =
      'Sync is not available on this device yet.';
  static const String syncOnDeviceOnly = 'On this device';
  static const String accountPrivacyNote =
      'Your moments stay on this device until you sign in and sync. '
      'ArchiveMe does not sell your data.';
  static const String savedPrivatelyOnDevice =
      'Saved privately on this device.';
  static const String addAnotherMomentTomorrow =
      'Add one more moment tomorrow to make this clearer.';
  static const String subscription = 'Subscription';
  static const String privacy = 'Privacy';
  static const String exportData = 'Export data';
  static const String deleteAccount = 'Delete account';
  static const String settings = 'Settings';
  static const String accountStatsTitle = 'At a glance';
  static const String accountPatternsIdentified = 'Patterns noticed';
  static const String accountStrongestPattern = 'Strongest pattern';
  static const String accountReflectionsCounted = 'Reflections counted';
  static const String accountDaysWithReflections = 'Days with reflections';
  static const String protectPatternsTitle =
      'Save your patterns with email sign-in.';
  static const String protectPatternsCta = 'Save my patterns';

  // ——— Settings ———
  static const String privacyPolicy = 'Privacy policy';
  static const String termsOfUse = 'Terms of use';
  static const String restorePurchases = 'Restore purchases';
  static const String exportReflections = 'Export reflections';
  static const String appVersion = 'App version';

  // ——— Paywall ———
  static const String paywallHeadline =
      'Keep your archive useful over time.';
  static const String paywallSubhead =
      'Unlock deeper history and saved evidence as patterns keep returning.';
  static const String paywallTitle = paywallHeadline;
  static const List<String> paywallFallbackBullets = [
    'See more of what keeps returning',
    'Keep deeper history and saved evidence',
    'Review what changed over time',
    'Archive timeline',
    'Monthly review',
  ];
  static const List<String> paywallBullets = paywallFallbackBullets;
  static const String paywallPrimaryCta = 'Continue with ArchiveMe Pro';
  static const String paywallSecondaryCta = 'Not now';
  static const String paywallContinue = paywallPrimaryCta;
  static const String paywallBackToPatterns = 'Back to Patterns';
  static const String paywallProActiveBody =
      'Full pattern memory, key moments, pattern map, archive timeline, and monthly review are available on this device.';
  static const String paywallSetupUnavailableBody =
      'Purchases are not available right now.';
  static const String paywallBillingNotConfigured =
      'ArchiveMe Pro keeps deeper history and saved evidence over time. '
      'Purchases are not available right now.';
  static const String plansUnavailable = 'Plans are not available yet.';

  // ——— Pattern memory limits (Pro) ———
  static const String patternMemoryGrowingTitle =
      'Your pattern memory is growing.';
  static const String freeKeepsSevenKeyMoments =
      'Free keeps your first 7 key moments.';
  static const String proKeepsFullMemory =
      'Pro keeps the full memory across weeks and months.';
  static const String unlockFullMemoryCta = 'See deeper history';

  // ——— Narrative headlines (change stories) ———
  static const String narrativeStrengthening =
      'This pattern is getting stronger';
  static const String narrativeWeakening = 'This pattern is starting to loosen';
  static const String narrativeEmerging = 'A new pattern is forming';
  static const String narrativeShifting = 'This pattern is shifting';

  // ——— Legacy empty / progress surfaces (still reachable) ———
  static const String progressEmptyTitle = 'Start with one reflection';
  static const String progressEmptyBody =
      'Each moment helps ArchiveMe notice what keeps repeating.';
  static const String needMoreReflectionsTitle = 'A few more moments help';
  static const String needMoreReflectionsBody =
      'Keep recording. Patterns get clearer with more reflections.';
  static const String searchIdleTitle = 'Search your reflections';
  static const String searchIdleBody =
      'Find moments and themes after you add reflections.';
  static const String needAnIdea = 'Need an idea?';
  static const String onboardingBeginCta = onboardingFinalCta;
  static const String archiveMeNoticedHeading = 'ARCHIVEME NOTICED';
  static const String archiveMeNoticedTitle = 'Today ArchiveMe noticed';
  @Deprecated('Use archiveMeNoticedHeading')
  static const String voiceMemoryNoticedHeading = archiveMeNoticedHeading;
  @Deprecated('Use archiveMeNoticedTitle')
  static const String voiceMemoryNoticedTitle = archiveMeNoticedTitle;
  static const String processingReflectionSaved =
      'Your reflection will appear in Patterns when finished.';
  static const String discoveryNoticeHeadline = 'Something worth noticing';

  // ——— Tomorrow return loop ———
  static const String comeBackTomorrow = 'Come back tomorrow';
  static const String comeBackTomorrowLabel = 'COME BACK TOMORROW';
  static const String whatArchiveMeChecksNext =
      'What ArchiveMe will check next';
  static const String todayItNoticed = 'Today it noticed…';
  static const String todayArchiveMeNoticed = 'Today ArchiveMe noticed';
  static const String nextTimeWatchFor = 'Next time, watch for…';
  static const String tomorrowWatchForSection = 'What to watch for next time';
  static const String oneMoreReflectionMakesClearer =
      'One more reflection makes this clearer.';
  static const String oneReflectionMomentLead =
      'One reflection is a moment. A few reflections start to show what repeats.';
  static const String tomorrowCompareWithToday =
      'Tomorrow, add one more reflection and ArchiveMe can compare it with today.';
  static const String tomorrowReturnCardBody = tomorrowCompareWithToday;
  static const String tomorrowComparePatternsBody =
      'ArchiveMe can check whether the same pattern shows up again.';
  static const String viewTodaysPatternCta = "View today's pattern";
  static const String recordAgainTomorrowLine =
      'Record again tomorrow to see what repeats.';
  static const String ifShowsUpAgainPattern =
      'If this shows up again, it may be a pattern.';
  static const List<String> defaultWatchForChips = [
    'same worry',
    'same person',
    'same time of day',
  ];
  static const String tomorrowNoticePrompt =
      'Tomorrow, notice whether this shows up again.';
  static const String patternsComeBackTitle = 'Why come back tomorrow?';
  static const String patternsComeBackBody =
      'ArchiveMe gets useful when it can compare today with tomorrow. '
      'The more ordinary moments you add, the clearer your repeating patterns become.';
  static const String patternsComeBackRecordCta = "Record today's reflection";
  static const String postSaveRecordAnotherReflection =
      'Record another reflection';

  // ——— Tomorrow commitment ———
  static const String tomorrowCommitmentLabel = 'TOMORROW';
  static const String tomorrowCommitmentTitle =
      'Want ArchiveMe to check this again tomorrow?';
  static const String tomorrowCommitmentBody =
      'Save a simple reminder for tomorrow. When you come back, ArchiveMe '
      'can compare what repeats.';
  static const String tomorrowCommitmentRemindCta = 'Remind me tomorrow';
  static const String tomorrowCommitmentDismissCta = 'Not now';
  static const String tomorrowCommitmentConfirmedLine1 =
      "Tomorrow's check is set.";
  static const String tomorrowCommitmentConfirmedLine2 =
      'Come back tomorrow to see what changed.';
  static const String tomorrowCommitmentDefaultPrompt =
      'Notice what shows up again in your next reflection.';
  static const String tomorrowReturnStatusCameBackTitle = 'You came back';
  static const String tomorrowReturnStatusCameBackBodyPrefix =
      'Yesterday you were watching for:';
  static const String tomorrowReturnStatusCameBackBodySuffix =
      'This gives ArchiveMe better evidence.';
  static const String tomorrowReturnStatusKeptGoingTitle =
      'You kept the loop going.';
  static const String tomorrowReturnStatusKeptGoingBody =
      'ArchiveMe can now compare today with yesterday.';
  static const String tomorrowReturnStatusSeeChangedCta = 'See what changed';

  // ——— Watch-for follow-up ———
  static const String watchForTomorrowTitle = 'Watch for this tomorrow';
  static const String watchForTomorrowUseCta = 'Use this tomorrow';
  static const String watchForTomorrowChooseAnotherCta = 'Choose another';
  static const String watchForTomorrowAcceptedLine =
      'Saved for tomorrow. ArchiveMe will ask if it shows up again.';
  static const String todaysWatchForTitle = 'Today, watch for this';
  static const String todaysWatchForCheckInLabel = 'When you record, notice';
  static const String todaysWatchForRecordCta = 'Record what happened';
  static const String todaysWatchForSkipCta = 'Skip this';
  static const String watchForResultCardTitle = 'Yesterday\'s watch-for';
  static const String watchForResultShowedAgain = 'It showed up again.';
  static const String watchForResultDidNotShow = 'It did not show up today.';
  static const String watchForResultChangedShape = 'It changed shape.';
  static const String watchForResultFeltLighterToday = 'It felt lighter today.';
  static const String watchForResultFeltHeavierToday = 'It felt heavier today.';
  static const String watchForResultSomethingChangedToday =
      'Something changed today.';
  static const String watchForResultUnclear =
      'ArchiveMe needs one more moment.';
  static const String watchForResultBodyUnclear =
      'Today\'s moment was short. Record once more tomorrow and ArchiveMe '
      'can compare it with what you were watching for.';

  // ——— Return comparison ———
  static const String returnComparisonCardTitle = 'Compared with yesterday';
  static const String returnComparisonYesterdayLabel =
      'What you were watching for yesterday';
  static const String returnComparisonTodayLabel = 'What showed up today';
  static const String returnComparisonRecordAnotherCta =
      'Record another moment';
  static const String returnComparisonShortReflection =
      'A short reflection from today.';
  static const String returnComparisonHeadlineRepeated =
      'That pattern showed up again.';
  static const String returnComparisonHeadlineShifted =
      'The pattern changed shape.';
  static const String returnComparisonHeadlineEased =
      'It sounded lighter today.';
  static const String returnComparisonHeadlineAbsent =
      'That pattern was not there today.';
  static const String returnComparisonHeadlineUnclear =
      'One more moment will make this clearer.';
  static const String returnComparisonBodyUnclear =
      "Today's reflection was short, so ArchiveMe needs another moment "
      'before comparing it properly.';
  static const String returnComparisonChipShowedAgain = 'showed up again';
  static const String returnComparisonChipChangedShape = 'changed shape';
  static const String returnComparisonChipLighterToday = 'lighter today';
  static const String returnComparisonChipNotThereToday = 'not there today';
  static const String returnComparisonChipNeedAnotherMoment =
      'need another moment';

  // ——— Return streak ———
  static const String returnStreakHeadline = 'You kept the loop going.';
  static const String returnStreakHeadlineSingle = 'You came back today.';
  static const String returnStreakBodySingle =
      'One return gives ArchiveMe a starting point to compare.';
  static String returnStreakDaysInARow(int days) =>
      '$days day${days == 1 ? '' : 's'} in a row';
  static String returnStreakBody(int days) =>
      'You came back $days day${days == 1 ? '' : 's'} in a row. '
      'That gives ArchiveMe more to compare.';
  static const String returnStreakRecordCta = "Record today's moment";

  // ——— Change summary ———
  static const String changeSummaryCardTitle = 'What is changing';
  static const String changeSummaryTitleSteady = 'This pattern is still here.';
  static const String changeSummaryTitleStronger =
      'This pattern may be getting stronger.';
  static const String changeSummaryTitleSofter = 'This pattern eased a little.';
  static const String changeSummaryTitleShifted = 'This pattern changed shape.';
  static const String changeSummaryTitleUnclear = 'Still taking shape.';
  static const String changeSummarySummaryUnclear =
      'Today was too short to say much yet. One more moment will sharpen the comparison.';
  static const String changeSummaryChipGotStronger = 'got stronger';
  static const String changeSummaryChipEased = 'eased';
  static const String changeSummaryChipChangedShape = 'changed shape';
  static const String changeSummaryChipSamePressure = 'same pressure';
  static const String changeSummaryChipWatchTomorrow = 'watch tomorrow';
  static const String changeSummaryChipNeedAnotherMoment =
      'need another moment';

  // ——— Weekly recap ———
  static const String weeklyRecapTitle = "This week's repeating pattern";
  static String weeklyRecapBodyFallback(int count) =>
      'You kept showing up $count times this week. ArchiveMe is starting to see what repeats.';

  // Legacy labels (older loop card)
  static const String tomorrowLoopTitle = 'Your return loop';
  static const String tomorrowNoticedToday = 'What ArchiveMe noticed today';
  static const String tomorrowComeBack = 'Why come back tomorrow';
  static const String tomorrowWatchFor = tomorrowWatchForSection;

  // ——— Active pattern thread ———
  static const String activePatternContinueTitle = 'Continue this pattern';
  static const String activePatternAddMomentCta = "Add today's moment";
  static const String activePatternPauseCta = 'Pause this';
  static const String activePatternCurrentTitle = 'Current pattern';
  static const String activePatternLastCheckedLabel = 'Last checked';
  static const String activePatternNextWatchLabel = 'Next time, watch for';
  static const String activePatternRecordTodayCta = "Record today's moment";
  static const String activePatternPostSaveLine =
      'ArchiveMe is tracking this pattern across your moments.';

  // ——— First-session pattern ———
  static const String firstSessionPatternLabel = 'FIRST PATTERN';
  static const String firstSessionPatternHeadline =
      'A pattern may be starting.';
  static const String firstSessionPatternHeadlineLow =
      'Something may be worth watching.';
  static const String firstSessionAmbiguousHint = 'This could be a few things.';
  static const String firstSessionChooseCloserCta = 'Choose what feels closer';
  static const String firstSessionWatchTomorrowSection = 'Tomorrow, check this';
  static const String tomorrowCheckReasonLine =
      'A good check is specific enough to answer tomorrow.';
  static const String makeItSharperCta = 'Make it sharper';
  static const String firstSessionUseTomorrowCta = 'Use this tomorrow';
  static const String chooseTomorrowQuestionLabel =
      "Choose tomorrow's question";
  static const String chooseSharperQuestionHelper =
      'Choose the question you would actually want answered tomorrow.';
  static const String chooseSharperQuestionHelperAggressive =
      'Choose the question you would actually care to answer tomorrow.';
  static const String bestQuestionLabel = 'Most direct';

  /// Optional deeper step after an obvious or weak check-in result.
  static const String checkInGoDeeperCta = 'Go deeper';
  static const String checkInGoDeeperTitle = 'Go one step deeper';
  static const String checkInGoDeeperHelper =
      'If today felt obvious, this is the more useful question to sit with.';

  /// Next useful check after a loop closes — turns the result into a next step.
  static const String resultNextCheckTitle = 'Next useful check';
  static const String resultNextCheckExampleLabel = 'Example';
  static const String resultNextCheckUseTomorrowCta = 'Use this tomorrow';
  static const String resultNextCheckChooseDifferentCta =
      'Choose a different check';
  static const String resultNextCheckConfirmation =
      'Tomorrow\u2019s check is set.';
  static const String resultNextCheckChooseSheetTitle =
      'Pick what to check tomorrow';
  static const String resultNextCheckAltBefore =
      'What happens right before it shows up?';
  static const String resultNextCheckAltHelped = 'What helped make it lighter?';
  static const String resultNextCheckAltHeavier = 'What made it heavier?';
  static const String patternsResultUseCheckCta = 'Use this check';

  /// Useful takeaway — a clearer read of the result shown before the rating.
  static const String usefulTakeawayTitle = 'Useful takeaway';
  static const String usefulTakeawayNextCheckLabel = 'Next check';
  static const String usefulTakeawayExampleLabel = 'Example';

  /// "Make this more useful" path — refines the takeaway when it feels generic.
  static const String makeResultMoreUsefulCta = 'Make this more useful';
  static const String makeResultMoreUsefulSheetTitle =
      'What would make this more useful?';
  static const String makeResultMoreUsefulMoreSpecific = 'More specific';
  static const String makeResultMoreUsefulMoreAccurate = 'More accurate';
  static const String makeResultMoreUsefulMoreNextStep = 'More next step';
  static const String makeResultMoreUsefulEasier = 'Easier to understand';

  /// Input quality guide — nudges weak reflections toward one clear moment.
  static const String inputQualityCoachTitle = 'Make this more useful';
  static const String inputQualityCoachBody =
      'Add one clear moment so ArchiveMe can find a better pattern.';
  static const String inputQualityCoachExampleLabel = 'Example';
  static const String inputQualityCoachAddSentenceCta = 'Add one sentence';
  static const String inputQualityCoachUseAnywayCta = 'Use it anyway';
  static const String inputQualityCoachAddSentenceHint =
      'Add one sentence\u2026';
  static const String inputQualityEarlyReadLabel = 'Early read';

  /// First pattern on weak input — keeps the read honest.
  static const String firstPatternEarlyReadHint =
      'This may get sharper after one more clear moment.';
  static const String firstPatternAddAnotherMomentCta = 'Add another moment';

  /// Result on weak input — points at one concrete moment.
  static const String resultEarlyReadNudge =
      'Add one more clear moment to make this more useful.';
  static const String resultEarlyReadNextCheck =
      'What exact moment did this show up?';
  static const String firstSessionChooseAnotherCta = 'Choose another';
  static const String firstSessionNotQuiteCta = 'Not quite?';
  static const String firstSessionCorrectionLearnedLine =
      'Got it — ArchiveMe will use this pattern for tomorrow.';
  static const String firstSessionWhichCloserTitle = 'Which feels closer?';
  static const String firstSessionSomethingElse = 'Something else';
  static const String firstSessionSavedLine1 = 'Saved.';
  static const String firstSessionSavedLine2 =
      'Tomorrow ArchiveMe will ask this exact question.';
  static const String tomorrowCheckInDueTitle = 'Your check-in from yesterday';
  static const String tomorrowCheckInDueSubtitle =
      'You only need to answer what happened today.';
  static const String tomorrowCheckInYesterdayChosenLabel =
      'Yesterday you chose to check:';
  static const String tomorrowCheckInTodayHappenedLabel =
      'Today, what happened?';
  static const String tomorrowCheckInMomentCompareLine =
      'Now add one moment so ArchiveMe can compare today with yesterday.';
  static const String tomorrowCheckInRecordCta = 'Record one moment';
  static const String tomorrowCheckInShortHelper =
      'Short is fine. One sentence is enough.';
  static const String tomorrowCheckInNeedExamples = 'Need examples?';
  static const String tomorrowCheckInOneTapRecordPrompt =
      'Now record one short moment.';
  static const String tomorrowCheckInOneTapRecordHelper =
      'One sentence is enough.';
  static const String tomorrowCheckInOneTapRecordCta = 'Record one sentence';
  static const String reminderSoftAskTitle = 'Want a reminder tomorrow?';
  static const String reminderSoftAskBody =
      'We can remind you when tomorrow\u2019s check is ready.';
  static const String reminderSoftAskRemindCta = 'Remind me';
  static const String reminderSoftAskNotNowCta = 'Not now';
  static const String reminderSetConfirmation = 'Reminder set for tomorrow.';
  static const String reminderDeniedMessage =
      'No problem. Your check-in is still saved.';
  static const String reminderSettingsTitle = 'Check-in reminders';
  static const String reminderSettingsBodyOff =
      'Get a reminder when tomorrow\u2019s check is ready.';
  static const String reminderSettingsBodyOn =
      'You will get a reminder when tomorrow\u2019s check is ready.';
  static const String reminderSettingsBodyPermissionNeeded =
      'Turn on notifications to get your check-in reminder.';
  static const String reminderStateOff = 'Off';
  static const String reminderStateOn = 'On';
  static const String reminderStatePermissionNeeded = 'Permission needed';
  static const String guidedCheckInAnswerCta = "Answer today's check-in";
  static const String guidedCheckInPickClosest =
      'Pick the closest answer. You can keep it short.';
  static const String guidedCheckInShowedUp = 'It showed up';
  static const String guidedCheckInDidNotShowUp = 'It did not show up';
  static const String guidedCheckInOtherAnswers = 'Other answers';
  static const String checkInWhatThisMeansLabel = 'What this means';
  static const String checkInTomorrowsBetterQuestionLabel =
      "Tomorrow's better question";
  static const String patternsWhatToWatchNextLabel = 'What to watch next';
  static const String patternsRecordAnotherMomentCta = 'Record another moment';
  static const String checkInLoopClosedTitle = 'You closed the loop.';
  static const String checkInResultNotUsefulFollowUp = 'What was wrong?';
  static const String patternsCheckInWaitingTitle =
      "Today's check-in is waiting";
  static const String patternsCheckInWaitingBody =
      'You chose what to check today. Answer it on Record.';
  static const String patternsCheckInWaitingCta = 'Answer it now';
  static const String patternsLoopClosedTitle = 'Loop closed';
  static const String patternsLoopClosedBody =
      'Yesterday you chose a check-in. Today you answered it.';
  static const String checkInWorthQuestionPrompt =
      'Does this feel worth checking tomorrow?';
  static const String checkInResultUsefulPrompt = 'Was this useful?';
  static const String missedCheckInReasonTitle = 'What got in the way?';
}
