/// Copy for archive moment controls — user trust, no advice.
abstract final class ArchiveControlCopy {
  ArchiveControlCopy._();

  static const deleteMomentButton = 'Delete moment';

  static const deleteDialogTitle = 'Delete this moment?';

  static const deleteDialogBody =
      'This removes the saved moment from your archive on this device.';

  static const deleteDialogConfirm = 'Delete';

  static const deleteDialogCancel = 'Cancel';

  static const deleteSuccess = 'Moment deleted';

  static const patternNeedsMoreEvidenceFallback =
      'ArchiveMe needs more evidence before showing this pattern.';

  static const excludeFromPatternButton = 'Remove from this pattern';

  static const excludeDialogTitle = 'Remove from this pattern?';

  static const excludeDialogBody =
      'The moment will stay saved, but ArchiveMe will not use it as evidence for this pattern.';

  static const excludeDialogConfirm = 'Remove';

  static const excludeSuccess = 'Removed from this pattern';

  static const excludedFromPatternChip = 'Excluded from pattern';

  static List<String> allVisibleStrings() => [
        deleteMomentButton,
        deleteDialogTitle,
        deleteDialogBody,
        deleteDialogConfirm,
        deleteDialogCancel,
        deleteSuccess,
        patternNeedsMoreEvidenceFallback,
        excludeFromPatternButton,
        excludeDialogTitle,
        excludeDialogBody,
        excludeDialogConfirm,
        excludeSuccess,
        excludedFromPatternChip,
      ];
}
