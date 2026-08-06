import 'capacity_cost_models.dart';

/// Copy for capacity later-cost check-ins — cautious, non-clinical language.
abstract final class CapacityCostCopy {
  CapacityCostCopy._();

  static const cardTitle = 'Did that yes cost you later?';
  static const cardBody = 'Did this cost you time, energy, or attention later?';
  static const cardHelper =
      'This helps your archive understand the pattern. No private details are shared.';
  static const answerCheckinCta = 'Answer check-in';
  static const skipCta = 'Skip for now';
  static const saveCheckinCta = 'Save check-in';
  static const earlyStateBody =
      'After you save a yes moment, ArchiveMe can ask whether it cost you later.';

  static const costTypeTime = 'Time';
  static const costTypeEnergy = 'Energy';
  static const costTypeAttention = 'Attention';
  static const costTypeWorkSpillover = 'Work spillover';
  static const costTypeResentment = 'Resentment';
  static const costTypeNone = 'None / not really';

  static String labelForCostType(String id) => switch (id) {
    CapacityCostTypeIds.time => costTypeTime,
    CapacityCostTypeIds.energy => costTypeEnergy,
    CapacityCostTypeIds.attention => costTypeAttention,
    CapacityCostTypeIds.workSpillover => costTypeWorkSpillover,
    CapacityCostTypeIds.resentment => costTypeResentment,
    CapacityCostTypeIds.none => costTypeNone,
    _ => id,
  };

  static String laterCostRecordedCount(int count) =>
      'Later cost recorded on $count moment${count == 1 ? '' : 's'}.';

  static String savedMomentsWithLaterCost(int count) =>
      '$count saved moment${count == 1 ? '' : 's'} had a later cost';

  static const strengthenLoopPrompt =
      'Add a later-cost check-in to strengthen this loop.';

  static const shareSafeNote = 'No private details are shared.';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    cardHelper,
    answerCheckinCta,
    skipCta,
    saveCheckinCta,
    earlyStateBody,
    costTypeTime,
    costTypeEnergy,
    costTypeAttention,
    costTypeWorkSpillover,
    costTypeResentment,
    costTypeNone,
    strengthenLoopPrompt,
    shareSafeNote,
  ];
}
