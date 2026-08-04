/// Settings copy for local privacy and data controls.
library;

import 'privacy_copy_policy.dart';

abstract final class PrivacyDataControlsCopy {
  PrivacyDataControlsCopy._();

  static const sectionTitle = 'Privacy & data';

  static const dataStaysOnDeviceTitle = PrivacyCopyPolicy.privateByDefault;
  static const dataStaysOnDeviceBody =
      'ArchiveMe keeps your archive on this device. Production preferences use '
      'the platform secure storage service. Share cards do not include your '
      'raw entries.';

  static const exportArchiveTitle = 'Export archive';
  static const exportArchiveSubtitle =
      'Create a private file or preview from this device.';

  static const viewSampleArchiveTitle = 'View sample archive';
  static const viewSampleArchiveSubtitle =
      'Example data only — your private archive stays untouched.';

  static const clearLocalArchiveTitle = 'Clear archive';
  static const clearLocalArchiveSubtitle =
      'Remove saved moments and archive evidence from this device.';

  static const clearLocalArchiveConfirmTitle = 'Clear your archive?';
  static const clearLocalArchiveConfirmBody =
      'This removes saved moments and archive evidence from this device. '
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
