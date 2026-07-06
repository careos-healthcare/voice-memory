import '../archive_evidence/archive_belief_thread_copy.dart';
import '../early_archive/archive_summary_copy.dart';
import '../early_archive/confirmed_repeat_thought_map_copy.dart';
import '../early_archive/first_proof_moment_copy.dart';
import '../first_proof_payoff/first_proof_payoff_copy.dart';
import '../first_proof_truth/first_proof_truth_copy.dart';
import '../belief_change/belief_change_moment_copy.dart';
import '../what_changed/what_changed_v2_copy.dart';
import '../pattern_confidence/pattern_confidence_copy.dart';
import '../pattern_lifecycle/pattern_lifecycle_copy.dart';
import '../quiet_signal/quiet_signal_copy.dart';
import '../contextual_privacy/contextual_privacy_copy.dart';
import '../early_archive/first_week_loop_copy.dart';
import '../early_archive/archive_change_timeline_copy.dart';
import '../early_archive/helpful_action_appeared_copy.dart';
import '../early_archive/positive_pattern_copy.dart';
import '../early_archive/positive_reinforcement_copy.dart';
import '../early_archive/private_archive_report_copy.dart';
import '../early_archive/return_check_payoff_copy.dart';
import '../early_archive/weekly_archive_review_copy.dart';
import '../weekly_review/weekly_archive_review_copy.dart';
import '../archive_thought_map/archive_thought_map_copy.dart';
import '../repeat_return_check/pattern_changed_copy.dart';
import '../next_action/next_best_action_copy.dart';
import 'proof_surface_why_appeared_copy.dart';
import 'archive_belief_surface_copy.dart';

/// Guards main proof surfaces from coaching / advice language.
abstract final class ProofSurfaceAdviceGuard {
  ProofSurfaceAdviceGuard._();

  static const bannedAdvicePhrases = [
    'you should',
    'you need to',
    'you must',
    'try this',
    'try to',
    'try repeating',
    'try watching',
    'try doing',
    'this means you are',
    'this means',
    'you always',
    'the reason is',
    'your problem is',
    'you have a tendency',
    'mental health',
    'therapy',
    'diagnosis',
    'coach',
    'coaching plan',
    'recommendations',
    'what to try',
  ];

  static Iterable<String> violationsIn(String text) sync* {
    if (text == ArchiveThoughtMapCopy.patternSignalDisclaimer) return;
    if (text == FirstProofPayoffCopy.truthLine) return;
    if (text == BeliefChangeMomentCopy.footer) return;
    final lower = text.toLowerCase();
    for (final phrase in bannedAdvicePhrases) {
      if (lower.contains(phrase)) yield phrase;
    }
  }

  static bool passes(String text) => violationsIn(text).isEmpty;

  static List<String> mainProofSurfaceCopyBlocks() => [
        FirstProofMomentCopy.primaryLabel,
        FirstProofMomentCopy.title,
        FirstProofMomentCopy.titlePossible,
        FirstProofMomentCopy.bodyStrong,
        FirstProofMomentCopy.bodyFallback,
        FirstProofMomentCopy.evidenceLabel,
        FirstProofMomentCopy.whyLine,
        FirstProofMomentCopy.nextLine,
        ...FirstProofPayoffCopy.allVisibleStrings(),
        ...FirstProofTruthCopy.allVisibleStrings(),
        ...BeliefChangeMomentCopy.allVisibleStrings(),
        ...WhatChangedV2Copy.allVisibleStrings(),
        ...PatternConfidenceCopy.allVisibleStrings(),
        ...PatternLifecycleCopy.allVisibleStrings(),
        ...QuietSignalCopy.allVisibleStrings(),
        ...ContextualPrivacyCopy.allVisibleStrings(),
        ArchiveSummaryCopy.title,
        ArchiveSummaryCopy.promise,
        ArchiveSummaryCopy.keepsRepeatingLabel,
        ArchiveSummaryCopy.keepsRepeatingFallback,
        ArchiveSummaryCopy.keepsRepeatingForming,
        ArchiveSummaryCopy.keepsRepeatingWithPhrase('said yes again'),
        ArchiveSummaryCopy.changingLabel,
        ArchiveSummaryCopy.changingFallback,
        ArchiveSummaryCopy.whatHelpsLabel,
        ArchiveSummaryCopy.whatHelpsFallback,
        ArchiveSummaryCopy.whatHelpsPrefix,
        ArchiveSummaryCopy.whatHelpsWithPhrase('walked outside'),
        FirstWeekLoopCopy.title,
        FirstWeekLoopCopy.bodyFallback,
        FirstWeekLoopCopy.footer,
        FirstWeekLoopCopy.bodyWithPhrase('said yes again'),
        ReturnCheckPayoffCopy.evidenceLabel,
        ReturnCheckPayoffCopy.softerTitle,
        ReturnCheckPayoffCopy.softerBodyFallback,
        ReturnCheckPayoffCopy.softerFooter,
        ReturnCheckPayoffCopy.strongerTitle,
        ReturnCheckPayoffCopy.strongerBodyFallback,
        ReturnCheckPayoffCopy.strongerFooter,
        ReturnCheckPayoffCopy.sameTitle,
        ReturnCheckPayoffCopy.sameBodyFallback,
        ReturnCheckPayoffCopy.sameFooter,
        ReturnCheckPayoffCopy.changedTitle,
        ReturnCheckPayoffCopy.changedBodyFallback,
        ReturnCheckPayoffCopy.changedFooter,
        ReturnCheckPayoffCopy.unknownTitle,
        ReturnCheckPayoffCopy.unknownBody,
        ReturnCheckPayoffCopy.unknownFooter,
        PatternChangedCopy.title,
        PatternChangedCopy.bodyFallback,
        PatternChangedCopy.footer,
        PatternChangedCopy.earlierLabel,
        PatternChangedCopy.thisTimeLabel,
        PrivateArchiveReportCopy.intro,
        PrivateArchiveReportCopy.previewTitle,
        PrivateArchiveReportCopy.previewBody,
        PrivateArchiveReportCopy.exportIncludedHeading,
        ...PrivateArchiveReportCopy.exportIncludedItems,
        PrivateArchiveReportCopy.exportNotIncludedHeading,
        ...PrivateArchiveReportCopy.exportNotIncludedItems,
        PrivateArchiveReportCopy.copyReportCta,
        PrivateArchiveReportCopy.viewReportCta,
        PrivateArchiveReportCopy.whatHelpedHeading,
        PrivateArchiveReportCopy.whatToWatchNextHeading,
        WeeklyArchiveReviewCopy.watchBeforeAgree,
        PrivateArchiveReportCopy.missingEvidenceFallback,
        ArchiveBeliefSurfaceCopy.headline,
        ArchiveBeliefSurfaceCopy.evidenceLabel,
        ArchiveBeliefSurfaceCopy.watchingLabel,
        ArchiveBeliefSurfaceCopy.previewBadge,
        ArchiveBeliefSurfaceCopy.beliefFallback,
        ArchiveBeliefSurfaceCopy.watchingFallback,
        ArchiveBeliefThreadCopy.proBridgeBody,
        ArchiveBeliefThreadCopy.whyPro,
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ArchiveBeliefThreadCopy.whatToTestLabel,
        ArchiveBeliefThreadCopy.weeklyWhatToTestNext,
        WeeklyArchiveWeekReviewCopy.promise,
        WeeklyArchiveWeekReviewCopy.helpedLabel,
        WeeklyArchiveWeekReviewCopy.helpedPrefix,
        WeeklyArchiveWeekReviewCopy.helpedFallback,
        ConfirmedRepeatThoughtMapCopy.title,
        ConfirmedRepeatThoughtMapCopy.triggerUnknown,
        ConfirmedRepeatThoughtMapCopy.thoughtUnknown,
        ConfirmedRepeatThoughtMapCopy.actionUnknown,
        ConfirmedRepeatThoughtMapCopy.resultUnknown,
        HelpfulActionAppearedCopy.title,
        HelpfulActionAppearedCopy.bodyFallback,
        HelpfulActionAppearedCopy.footer,
        HelpfulActionAppearedCopy.evidenceLabel,
        HelpfulActionAppearedCopy.chipLabel,
        HelpfulActionAppearedCopy.bodyWithPhrase('walked outside'),
        ArchiveChangeTimelineCopy.title,
        ArchiveChangeTimelineCopy.subtitle,
        ArchiveChangeTimelineCopy.firstSeenBody,
        ArchiveChangeTimelineCopy.repeatedBody,
        ArchiveChangeTimelineCopy.lookedSofterBody,
        ArchiveChangeTimelineCopy.lookedStrongerBody,
        ArchiveChangeTimelineCopy.aboutTheSameBody,
        ArchiveChangeTimelineCopy.changedThisTimeBody,
        ArchiveChangeTimelineCopy.helpfulActionAppearedBody,
        ArchiveChangeTimelineCopy.stillWatchingBody,
        PositiveReinforcementCopy.title,
        PositiveReinforcementCopy.body,
        PositiveReinforcementCopy.completionTitle,
        PositiveReinforcementCopy.completionBody,
        ...NextBestActionCopy.allVisibleStrings,
        ...ProofSurfaceWhyAppearedCopy.allLines,
        ...ArchiveThoughtMapCopy.allVisibleStrings,
      ];
}
