/// Copy for local archive backup and restore — manual, user-controlled only.
abstract final class LocalBackupCopy {
  LocalBackupCopy._();

  static const exportControl = 'Export local backup';
  static const restoreControl = 'Restore from backup';

  static const exportTitle = 'Export local backup';
  static const exportBody =
      'This creates a file you control. Keep it somewhere safe. '
      'Anyone with the file may be able to read your saved moments.';
  static const exportPrimary = 'Export backup';
  static const cancel = 'Cancel';

  static const restoreTitle = 'Restore from backup?';
  static const restoreBody =
      'This will replace the current archive on this device with the backup you choose.';
  static const restorePrimary = 'Restore';

  static const exportSuccess = 'Backup exported';
  static const restoreSuccess = 'Archive restored';
  static const invalidBackup = 'This does not look like an ArchiveMe backup.';

  static List<String> allVisibleStrings() => [
    exportControl,
    restoreControl,
    exportTitle,
    exportBody,
    exportPrimary,
    cancel,
    restoreTitle,
    restoreBody,
    restorePrimary,
    exportSuccess,
    restoreSuccess,
    invalidBackup,
  ];
}