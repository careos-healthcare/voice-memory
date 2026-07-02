import '../early_archive/archive_summary_copy.dart';
import '../early_archive/confirmed_repeat_thought_map_copy.dart';
import '../early_archive/first_proof_moment_copy.dart';
import '../early_archive/positive_pattern_copy.dart';
import '../early_archive/positive_reinforcement_copy.dart';
import '../early_archive/private_archive_report_copy.dart';
import '../early_archive/return_check_payoff_copy.dart';
import '../early_archive/weekly_archive_review_copy.dart';
import '../archive_thought_map/archive_thought_map_copy.dart';
import '../repeat_return_check/pattern_changed_copy.dart';

/// Guards main proof surfaces from coaching / advice language.
abstract final class ProofSurfaceAdviceGuard {
  ProofSurfaceAdviceGuard._();

  static const bannedAdvicePhrases = [
    'you should',
    'you need to',
    'try this',
    'try to',
    'try repeating',
    'try watching',
    'this means you are',
    'the reason is',
    'your problem is',
    'you have a tendency',
    'mental health',
    'therapy',
    'diagnosis',
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
        PatternChangedCopy.softerTitle,
        PatternChangedCopy.softerBody,
        PatternChangedCopy.changedTitle,
        PatternChangedCopy.changedBody,
        PatternChangedCopy.strongerTitle,
        PatternChangedCopy.strongerBody,
        PrivateArchiveReportCopy.intro,
        PrivateArchiveReportCopy.previewProNote,
        PrivateArchiveReportCopy.whatHelpedHeading,
        PrivateArchiveReportCopy.recordNextHeading,
        WeeklyArchiveWeekReviewCopy.promise,
        WeeklyArchiveWeekReviewCopy.helpedLabel,
        WeeklyArchiveWeekReviewCopy.helpedPrefix,
        WeeklyArchiveWeekReviewCopy.helpedFallback,
        ConfirmedRepeatThoughtMapCopy.title,
        ConfirmedRepeatThoughtMapCopy.triggerUnknown,
        ConfirmedRepeatThoughtMapCopy.thoughtUnknown,
        ConfirmedRepeatThoughtMapCopy.actionUnknown,
        ConfirmedRepeatThoughtMapCopy.resultUnknown,
        PositivePatternCopy.title,
        PositivePatternCopy.body,
        PositiveReinforcementCopy.title,
        PositiveReinforcementCopy.body,
        PositiveReinforcementCopy.completionTitle,
        PositiveReinforcementCopy.completionBody,
        ...ArchiveThoughtMapCopy.allVisibleStrings,
      ];
}
