/// Sync expectation safety copy — honest local-archive language only.
abstract final class SyncExpectationSafetyCopy {
  SyncExpectationSafetyCopy._();

  static const headline = 'Sync expectation safety guard';

  static const body =
      'Prevent paid copy from implying cloud backup or cross-device sync unless sync '
      'is actually proven. Paid promise stays longer proof trail, not backup.';

  static const allowedLanguageLine =
      'Allowed: on this device, local archive, private on this device, Pro keeps the '
      'longer proof trail, sync not available yet, and backup/export only where true.';

  static const blockedLanguageLine =
      'Blocked unless sync proven: cloud backup, cross-device sync, access everywhere, '
      'never lose your archive, backed up automatically, account keeps your trail safe, '
      'and sync across devices.';

  static const blockLine =
      'This copy implies cloud backup or cross-device sync before sync is proven. '
      'Rewrite with on-device or honest unavailable-sync language.';

  static const allowedLine =
      'Copy stays honest about local archive and longer proof trail.';

  static const guardrail =
      'Sync expectation safety is a copy guard only. No backend or sync implementation. '
      'Paid promise remains longer proof trail, not backup.';

  static String messageFor(SyncExpectationSafetyBlockReason reason) =>
      switch (reason) {
        SyncExpectationSafetyBlockReason.cloudBackup =>
          'Blocked cloud backup promise before sync is proven.',
        SyncExpectationSafetyBlockReason.crossDeviceSync =>
          'Blocked cross-device sync promise before sync is proven.',
        SyncExpectationSafetyBlockReason.accessEverywhere =>
          'Blocked access-everywhere promise before sync is proven.',
        SyncExpectationSafetyBlockReason.neverLoseArchive =>
          'Blocked never-lose-archive promise before sync is proven.',
        SyncExpectationSafetyBlockReason.backedUpAutomatically =>
          'Blocked automatic backup promise before sync is proven.',
        SyncExpectationSafetyBlockReason.accountKeepsTrailSafe =>
          'Blocked account-keeps-trail-safe promise before sync is proven.',
        SyncExpectationSafetyBlockReason.syncAcrossDevices =>
          'Blocked sync-across-devices promise before sync is proven.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield allowedLanguageLine;
    yield blockedLanguageLine;
    yield blockLine;
    yield allowedLine;
    yield guardrail;
    for (final reason in SyncExpectationSafetyBlockReason.values) {
      yield messageFor(reason);
    }
  }
}

enum SyncExpectationSafetyAction { allowed, blocked }

enum SyncExpectationSafetyBlockReason {
  cloudBackup,
  crossDeviceSync,
  accessEverywhere,
  neverLoseArchive,
  backedUpAutomatically,
  accountKeepsTrailSafe,
  syncAcrossDevices,
}