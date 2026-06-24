/// Settings copy for local privacy and data controls.
import 'privacy_copy_policy.dart';

abstract final class PrivacyDataControlsCopy {
  PrivacyDataControlsCopy._();

  static const sectionTitle = 'Privacy & data';

  static const dataStaysOnDeviceTitle = PrivacyCopyPolicy.privateByDefault;
  static const dataStaysOnDeviceBody =
      'ArchiveMe stores your journal file encrypted on this device. Archive '
      'metadata and prefs remain in plaintext JSON. Share cards do not include '
      'your raw entries.';

  static const exportArchiveTitle = 'Export archive';
  static const exportArchiveSubtitle =
      'Create a private file or preview from this device.';

  static const viewSampleArchiveTitle = 'View sample archive';
  static const viewSampleArchiveSubtitle =
      'Example data only — your private archive stays untouched.';

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
