import 'archive_timeline_spine_model.dart';

/// User-facing copy for the archive timeline spine card.
abstract final class ArchiveTimelineSpineCopy {
  ArchiveTimelineSpineCopy._();

  static const title = 'Archive timeline';

  static const subtitle = 'Not a chat. A record of what changed over time.';

  static const explanation =
      'ArchiveMe does not treat one moment as the whole truth. It tracks what appeared, what returned, what you corrected, and what still matters now.';

  static const footer = 'Your past is context, not a verdict.';

  static const differentiationLine =
      'ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.';

  static const proBridgeCopy = 'Pro keeps the longer proof trail over time.';

  static const firstSeenLabel = 'Seen';
  static const firstSeenDetail = 'First saved moment on record.';

  static const returnedLabel = 'Returned';
  static const returnedDetail = 'This came back across saved moments.';

  static const stillCurrentLabel = 'Current';
  static const stillCurrentDetail =
      'ArchiveMe still treats this as live context.';

  static const correctedLabel = 'Corrected';
  static const correctedDetail =
      'You adjusted how much this still matters.';

  static const weightChangedLabel = 'Reweighted';
  static const weightChangedDetail =
      'How much weight ArchiveMe gives this has shifted.';

  static const needsFreshProofLabel = 'Fresh proof needed';
  static const needsFreshProofDetail =
      'ArchiveMe needs a newer saved moment before treating this as current.';

  static const currentWeightStrong = 'Current weight: strong';
  static const currentWeightLight = 'Current weight: light';
  static const currentWeightFading = 'Current weight: fading';
  static const currentWeightCorrected = 'Current weight: corrected';
  static const currentWeightNeedsFreshProof =
      'Current weight: needs fresh proof';

  static String labelFor(ArchiveTimelineSpineRowId row) => switch (row) {
        ArchiveTimelineSpineRowId.firstSeen => firstSeenLabel,
        ArchiveTimelineSpineRowId.returned => returnedLabel,
        ArchiveTimelineSpineRowId.stillCurrent => stillCurrentLabel,
        ArchiveTimelineSpineRowId.correctedByYou => correctedLabel,
        ArchiveTimelineSpineRowId.weightChanged => weightChangedLabel,
        ArchiveTimelineSpineRowId.needsFreshProof => needsFreshProofLabel,
      };

  static String detailFor(ArchiveTimelineSpineRowId row) => switch (row) {
        ArchiveTimelineSpineRowId.firstSeen => firstSeenDetail,
        ArchiveTimelineSpineRowId.returned => returnedDetail,
        ArchiveTimelineSpineRowId.stillCurrent => stillCurrentDetail,
        ArchiveTimelineSpineRowId.correctedByYou => correctedDetail,
        ArchiveTimelineSpineRowId.weightChanged => weightChangedDetail,
        ArchiveTimelineSpineRowId.needsFreshProof => needsFreshProofDetail,
      };

  static String currentWeightLabelFor(
    ArchiveTimelineSpineCurrentWeight weight,
  ) =>
      switch (weight) {
        ArchiveTimelineSpineCurrentWeight.strong => currentWeightStrong,
        ArchiveTimelineSpineCurrentWeight.light => currentWeightLight,
        ArchiveTimelineSpineCurrentWeight.fading => currentWeightFading,
        ArchiveTimelineSpineCurrentWeight.corrected => currentWeightCorrected,
        ArchiveTimelineSpineCurrentWeight.needsFreshProof =>
          currentWeightNeedsFreshProof,
      };

  static List<String> allVisibleStrings() => [
        title,
        subtitle,
        explanation,
        footer,
        differentiationLine,
        proBridgeCopy,
        firstSeenLabel,
        firstSeenDetail,
        returnedLabel,
        returnedDetail,
        stillCurrentLabel,
        stillCurrentDetail,
        correctedLabel,
        correctedDetail,
        weightChangedLabel,
        weightChangedDetail,
        needsFreshProofLabel,
        needsFreshProofDetail,
        currentWeightStrong,
        currentWeightLight,
        currentWeightFading,
        currentWeightCorrected,
        currentWeightNeedsFreshProof,
      ];
}
