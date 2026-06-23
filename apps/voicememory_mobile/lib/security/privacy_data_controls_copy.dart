/// Settings copy for local privacy and data controls.
abstract final class PrivacyDataControlsCopy {
  PrivacyDataControlsCopy._();

  static const sectionTitle = 'Privacy & data';

  static const dataStaysOnDeviceTitle = 'Your data stays on this device';
  static const dataStaysOnDeviceBody =
      'ArchiveMe uses your saved moments to build your private archive on this '
      'device. Share cards do not include your raw entries.';

  static const exportArchiveTitle = 'Export archive';
  static const exportArchiveSubtitle =
      'Create a private file or preview from this device.';

  static const clearLocalArchiveTitle = 'Clear local archive';
  static const clearLocalArchiveSubtitle =
      'Remove saved moments and local archive insights from this device.';

  static const clearLocalArchiveConfirmTitle = 'Clear local archive?';
  static const clearLocalArchiveConfirmBody =
      'This removes saved moments and local archive insights from this device. '
      'This cannot be undone.';

  static const resetDismissedTipsTitle = 'Reset dismissed tips';
  static const resetDismissedTipsSubtitle =
      'Show Archive workspace hints again.';

  static const resetDismissedTipsConfirmTitle = 'Reset dismissed tips?';
  static const resetDismissedTipsConfirmBody =
      'Archive workspace hints will appear again the next time you open Patterns.';

  static const cancel = 'Cancel';
  static const clearArchiveConfirm = 'Clear archive';
  static const resetTipsConfirm = 'Reset tips';

  static const clearArchiveDone = 'Local archive cleared.';
  static const resetTipsDone = 'Dismissed tips reset.';
}
