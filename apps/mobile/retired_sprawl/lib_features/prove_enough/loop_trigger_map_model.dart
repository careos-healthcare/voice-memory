/// Trigger categories detected in prove_enough journal moments.
enum LoopTriggerCategory {
  unfinishedWork,
  comparison,
  praiseOrExpectations,
  quietOrRest,
  feelingBehind,
  externalDeadline,
  wantingToLookCapable,
  unclear;

  String get id {
    switch (this) {
      case LoopTriggerCategory.unfinishedWork:
        return 'unfinished_work';
      case LoopTriggerCategory.comparison:
        return 'comparison';
      case LoopTriggerCategory.praiseOrExpectations:
        return 'praise_or_expectations';
      case LoopTriggerCategory.quietOrRest:
        return 'quiet_or_rest';
      case LoopTriggerCategory.feelingBehind:
        return 'feeling_behind';
      case LoopTriggerCategory.externalDeadline:
        return 'external_deadline';
      case LoopTriggerCategory.wantingToLookCapable:
        return 'wanting_to_look_capable';
      case LoopTriggerCategory.unclear:
        return 'unclear';
    }
  }

  /// Consumer-facing label — no diagnosis language.
  String get label {
    switch (this) {
      case LoopTriggerCategory.unfinishedWork:
        return 'Unfinished work';
      case LoopTriggerCategory.comparison:
        return 'Comparison to others';
      case LoopTriggerCategory.praiseOrExpectations:
        return 'Praise or expectations';
      case LoopTriggerCategory.quietOrRest:
        return 'Quiet or rest';
      case LoopTriggerCategory.feelingBehind:
        return 'Feeling behind';
      case LoopTriggerCategory.externalDeadline:
        return 'External deadline';
      case LoopTriggerCategory.wantingToLookCapable:
        return 'Wanting to look capable';
      case LoopTriggerCategory.unclear:
        return 'Unclear trigger';
    }
  }

  static LoopTriggerCategory? fromId(String? raw) {
    if (raw == null) return null;
    for (final category in LoopTriggerCategory.values) {
      if (category.id == raw) return category;
    }
    return null;
  }
}

/// One row in the loop trigger map.
class LoopTriggerMapRow {
  const LoopTriggerMapRow({
    required this.category,
    required this.count,
    required this.lastEvidencePhrase,
  });

  final LoopTriggerCategory category;
  final int count;
  final String lastEvidencePhrase;
}

/// Aggregated trigger map across prove_enough moments.
class LoopTriggerMapModel {
  const LoopTriggerMapModel({
    required this.rows,
    required this.analyzedEntryCount,
    required this.hasEnoughData,
  });

  static const notEnoughDataCopy =
      'ArchiveMe needs a few more proving moments before it can map triggers.';
  static const enoughDataHeadline =
      'Your proving loop appears most often after:';

  final List<LoopTriggerMapRow> rows;
  final int analyzedEntryCount;
  final bool hasEnoughData;

  List<LoopTriggerMapRow> get rankedRows =>
      rows
          .where(
            (row) =>
                row.category != LoopTriggerCategory.unclear && row.count > 0,
          )
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
}