import '../archive_evidence/archive_belief_thread_copy.dart';
import '../early_archive/archive_summary_copy.dart';
import '../early_archive/confirmed_repeat_thought_map_copy.dart';
import '../early_archive/first_proof_moment_copy.dart';
import '../early_archive/first_week_loop_copy.dart';
import '../early_archive/helpful_action_appeared_copy.dart';
import '../early_archive/positive_pattern_copy.dart';
import '../early_archive/positive_reinforcement_copy.dart';
import '../early_archive/private_archive_report_copy.dart';
import '../early_archive/return_check_payoff_copy.dart';
import '../early_archive/weekly_archive_review_copy.dart';
import '../archive_thought_map/archive_thought_map_copy.dart';
import '../repeat_return_check/pattern_changed_copy.dart';
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
    final lower = text.toLowerCase();
    for (final phrase in bannedAdvicePhrases) {
      if (lower.contains(phrase)) yield phrase;
    }
  }

  static bool passes(String text) => violationsIn(text).isEmpty;

  static List<String> mainProofSurfaceCopyBlocks() => [
        FirstProofMomentCopy.title,
        FirstProofMomentCopy.titlePossible,
        FirstProofMomentCopy.bodyFallback,
        FirstProofMomentCopy.bodyFallbackStrong,
        FirstProofMomentCopy.evidenceLabel,
        FirstProofMomentCopy.whyLine,
        FirstProofMomentCopy.footer,
        FirstProofMomentCopy.bodyWithPhrase('said yes again'),
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
        PrivateArchiveReportCopy.evidenceNotAdviceLine,
        PrivateArchiveReportCopy.previewProNote,
        PrivateArchiveReportCopy.whatHelpedHeading,
        PrivateArchiveReportCopy.recordNextHeading,
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
        PositiveReinforcementCopy.title,
        PositiveReinforcementCopy.body,
        PositiveReinforcementCopy.completionTitle,
        PositiveReinforcementCopy.completionBody,
        ...ArchiveThoughtMapCopy.allVisibleStrings,
      ];
}
