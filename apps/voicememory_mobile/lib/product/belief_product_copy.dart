import 'consumer_ui_copy.dart';

/// Product copy aliases — user-facing strings live in [ConsumerUiCopy].
abstract class BeliefProductCopy {
  BeliefProductCopy._();

  static const String northStarTagline =
      'See what keeps repeating in your life.';

  static const String archiveHeroHeading = ConsumerUiCopy.patternsHeroHeading;
  static const String archiveChangingHeading =
      ConsumerUiCopy.patternsShiftingHeading;
  static const String archiveEvolutionHeading =
      ConsumerUiCopy.patternsEvolutionHeading;
  static const String archiveContradictionsHeading =
      ConsumerUiCopy.patternsTensionsHeading;
  static const String archiveBlindSpotsHeading =
      ConsumerUiCopy.patternsWorthNoticingHeading;
  static const String archivePredictionsHeading =
      ConsumerUiCopy.patternsWhatMayComeNextHeading;
  static const String archiveRecordCta = ConsumerUiCopy.patternsRecordCta;

  static const String labelBelief = ConsumerUiCopy.labelPattern;
  static const String labelConfidence = ConsumerUiCopy.labelConfidence;
  static const String labelBasedOn = ConsumerUiCopy.labelBasedOn;
  static const String labelWhy = ConsumerUiCopy.labelWhy;
  static const String labelWhyItMatters = ConsumerUiCopy.labelWhyItMatters;
  static const String labelArchiveExplanation = ConsumerUiCopy.labelPatternNote;
  static const String reflectionsWord = 'reflections';

  static const String emptyTitle = ConsumerUiCopy.patternsEmptyPageTitle;
  static const String emptyBody = ConsumerUiCopy.patternsEarlyStateBody;
  static const List<String> emptyExamples =
      ConsumerUiCopy.patternsScreenshotExamples;
  static const String recordFirstReflectionCta =
      ConsumerUiCopy.patternsEmptyCta;

  static const String questionOfTheDay =
      'What has been occupying your mind recently?';
  static const List<String> recordPrompts = [
    'What are you worried about?',
    'What are you excited about?',
    'What keeps repeating lately?',
    'What are you avoiding?',
    'What shifted in you this week?',
  ];
  static const String reflectionSavedTitle =
      ConsumerUiCopy.reflectionSavedTitle;
  static const String potentialSignalsTitle =
      ConsumerUiCopy.possiblePatternForming;
  static const String postSavePossibleBelief =
      ConsumerUiCopy.possiblePatternForming;
  static const String postSaveConfidence = ConsumerUiCopy.postSaveConfidence;
  static const String postSaveBasedOn = ConsumerUiCopy.postSaveBasedOn;
  static const String postSaveRecordAnother =
      ConsumerUiCopy.postSaveRecordAnother;
  static const String potentialSignalsNote =
      ConsumerUiCopy.earlyObservationsNote;

  static const String beliefsTabLabel = ConsumerUiCopy.patternsTabLabel;
  static const String beliefsScreenTitle = ConsumerUiCopy.allPatternsTitle;
  static const String beliefsScreenLead = ConsumerUiCopy.allPatternsLead;

  static const String sectionCurrent = ConsumerUiCopy.patternsSectionCurrent;
  static const String sectionEmerging = ConsumerUiCopy.patternsSectionEmerging;
  static const String sectionChanging = ConsumerUiCopy.patternsSectionChanging;
  static const String sectionHidden = ConsumerUiCopy.patternsSectionHidden;

  static const String changesTabLabel = 'Changes';
  static const String changesScreenTitle = ConsumerUiCopy.changesScreenTitle;
  static const String changesScreenLead = ConsumerUiCopy.changesScreenLead;
  static const String narrativeStrengthening =
      ConsumerUiCopy.narrativeStrengthening;
  static const String narrativeWeakening = ConsumerUiCopy.narrativeWeakening;
  static const String narrativeEmerging = ConsumerUiCopy.narrativeEmerging;
  static const String narrativeShifting = ConsumerUiCopy.narrativeShifting;
  static const String changesEmptyLead = ConsumerUiCopy.changesEmptyLead;

  static const String detailConfidenceLabel = ConsumerUiCopy.labelConfidence;
  static const String detailEvidenceTimeline =
      ConsumerUiCopy.detailMomentsSection;
  static const String detailArchiveConclusion =
      ConsumerUiCopy.detailWhatThisMeans;

  static const String accountStatsTitle = ConsumerUiCopy.accountStatsTitle;
  static const String accountBeliefsIdentified =
      ConsumerUiCopy.accountPatternsIdentified;
  static const String accountStrongestBelief =
      ConsumerUiCopy.accountStrongestPattern;
  static const String accountEvidenceAnalysed =
      ConsumerUiCopy.accountReflectionsCounted;
  static const String accountArchiveAge =
      ConsumerUiCopy.accountDaysWithReflections;
}
