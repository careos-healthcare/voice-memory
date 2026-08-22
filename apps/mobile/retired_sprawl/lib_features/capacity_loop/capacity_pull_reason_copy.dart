import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_models.dart';

/// Copy for capacity pull reasons — cautious, non-judgmental language.
abstract final class CapacityPullReasonCopy {
  CapacityPullReasonCopy._();

  static const cardTitle = 'What pulled you toward yes?';
  static const cardBody =
      'Choose what made it hard to pause. This helps your archive show what keeps repeating.';
  static const saveReasonCta = 'Save reason';
  static const skipCta = 'Skip for now';

  static const reasonFeltResponsible = 'I felt responsible';
  static const reasonSoundedUrgent = 'It sounded urgent';
  static const reasonAvoidDisappoint = 'I did not want to disappoint them';
  static const reasonSqueezeItIn = 'I thought I could squeeze it in';
  static const reasonWantedOpportunity = 'I wanted the opportunity';
  static const reasonAnsweredTooQuickly = 'I answered too quickly';
  static const reasonSomethingElse = 'Something else';

  static const loopStrengthenPrompt =
      'Add what pulled you toward yes to strengthen this loop.';

  static const weeklySectionTitle = 'What pulled you in';
  static const weeklyFormingCopy =
      'A few more saved reasons will make this clearer.';

  static String mostCommonPullLabel(String reasonLabel) =>
      'Most common pull: $reasonLabel';

  static String weeklyMostCommonLine(String shortLabel) =>
      'This week, $shortLabel appeared most often.';

  static const boundaryUrgentFitNote = 'This may fit when the pull is urgency.';

  static String labelForReason(String id) => switch (id) {
    CapacityPullReasonIds.feltResponsible => reasonFeltResponsible,
    CapacityPullReasonIds.soundedUrgent => reasonSoundedUrgent,
    CapacityPullReasonIds.avoidDisappoint => reasonAvoidDisappoint,
    CapacityPullReasonIds.squeezeItIn => reasonSqueezeItIn,
    CapacityPullReasonIds.wantedOpportunity => reasonWantedOpportunity,
    CapacityPullReasonIds.answeredTooQuickly => reasonAnsweredTooQuickly,
    CapacityPullReasonIds.somethingElse => reasonSomethingElse,
    _ => id,
  };

  static String shortLabelForReason(String id) => switch (id) {
    CapacityPullReasonIds.feltResponsible => 'feeling responsible',
    CapacityPullReasonIds.soundedUrgent => 'urgency',
    CapacityPullReasonIds.avoidDisappoint => 'not wanting to disappoint',
    CapacityPullReasonIds.squeezeItIn => 'thinking you could squeeze it in',
    CapacityPullReasonIds.wantedOpportunity => 'wanting the opportunity',
    CapacityPullReasonIds.answeredTooQuickly => 'answering too quickly',
    CapacityPullReasonIds.somethingElse => 'mixed pulls',
    _ => 'a repeated pull',
  };

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    saveReasonCta,
    skipCta,
    reasonFeltResponsible,
    reasonSoundedUrgent,
    reasonAvoidDisappoint,
    reasonSqueezeItIn,
    reasonWantedOpportunity,
    reasonAnsweredTooQuickly,
    reasonSomethingElse,
    loopStrengthenPrompt,
    weeklySectionTitle,
    weeklyFormingCopy,
    boundaryUrgentFitNote,
  ];
}