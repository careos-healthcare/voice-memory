import '../archive_timeline_spine/archive_timeline_spine_model.dart';
import '../correction_memory/correction_memory_model.dart';

/// Concise proof-moment copy built from existing timeline signals.
abstract final class TimelineProofMomentCopy {
  TimelineProofMomentCopy._();

  static const title = 'This pattern has a timeline now.';

  static const compactTitle = 'Your timeline is forming.';

  static const body =
      'ArchiveMe found more than one saved moment pointing in the same direction.';

  static const firstSeenRow = 'First seen';

  static const returnedRow = 'Returned';

  static const correctedRowPrefix = 'You corrected this:';

  static const currentWeightRow = 'Current weight';

  static const footer =
      'ArchiveMe is not treating your past as a verdict. It is showing what still has evidence today.';

  static const differentiationLine =
      'ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.';

  static const proLine = 'Pro keeps the longer proof trail over time.';

  static const currentWeightStrong = 'Current weight: strong';
  static const currentWeightLight = 'Current weight: light';
  static const currentWeightFading = 'Current weight: fading';
  static const currentWeightCorrected = 'Current weight: corrected by you';
  static const currentWeightNeedsFreshProof =
      'Current weight: needs fresh proof';

  static String correctionLabelFor({
    required CorrectionMemoryState state,
    required bool returnedAfterFaded,
  }) {
    if (returnedAfterFaded) return 'returned after less current';
    return switch (state) {
      CorrectionMemoryState.stillCurrent => 'still current',
      CorrectionMemoryState.partlyCurrent => 'partly current',
      CorrectionMemoryState.faded => 'less current',
      CorrectionMemoryState.unsure => 'not sure yet',
    };
  }

  static String correctedRowFor(String correctionLabel) =>
      '$correctedRowPrefix $correctionLabel';

  static String currentWeightLineFor(
    ArchiveTimelineSpineCurrentWeight weight,
  ) => switch (weight) {
    ArchiveTimelineSpineCurrentWeight.strong => currentWeightStrong,
    ArchiveTimelineSpineCurrentWeight.light => currentWeightLight,
    ArchiveTimelineSpineCurrentWeight.fading => currentWeightFading,
    ArchiveTimelineSpineCurrentWeight.corrected => currentWeightCorrected,
    ArchiveTimelineSpineCurrentWeight.needsFreshProof =>
      currentWeightNeedsFreshProof,
  };

  static List<String> allVisibleStrings() => [
    title,
    compactTitle,
    body,
    firstSeenRow,
    returnedRow,
    correctedRowPrefix,
    currentWeightRow,
    footer,
    differentiationLine,
    proLine,
    currentWeightStrong,
    currentWeightLight,
    currentWeightFading,
    currentWeightCorrected,
    currentWeightNeedsFreshProof,
    correctionLabelFor(
      state: CorrectionMemoryState.stillCurrent,
      returnedAfterFaded: false,
    ),
    correctionLabelFor(
      state: CorrectionMemoryState.partlyCurrent,
      returnedAfterFaded: false,
    ),
    correctionLabelFor(
      state: CorrectionMemoryState.faded,
      returnedAfterFaded: false,
    ),
    correctionLabelFor(
      state: CorrectionMemoryState.unsure,
      returnedAfterFaded: false,
    ),
    correctionLabelFor(
      state: CorrectionMemoryState.faded,
      returnedAfterFaded: true,
    ),
  ];
}
