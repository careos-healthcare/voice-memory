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

  static List<String> allVisibleStrings() => [
        deleteMomentButton,
        deleteDialogTitle,
        deleteDialogBody,
        deleteDialogConfirm,
        deleteDialogCancel,
        deleteSuccess,
        patternNeedsMoreEvidenceFallback,
      ];
}
