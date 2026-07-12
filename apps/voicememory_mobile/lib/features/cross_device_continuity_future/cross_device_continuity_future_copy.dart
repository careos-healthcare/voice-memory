/// Cross device continuity future copy — future only until technically proven.
abstract final class CrossDeviceContinuityFutureCopy {
  CrossDeviceContinuityFutureCopy._();

  static const headline = 'Cross device continuity future gate';

  static const body =
      'Prevent cloud and sync promises until technically proven, while documenting future '
      'cross-device continuity expansion. Classification only.';

  static const positioning =
      'Cross-device continuity stays future-only until account, restore, backup, privacy, '
      'and migration proof are complete.';

  static const orderLine =
      'Rules: future only, no cloud backup promise, no access everywhere promise, no never '
      'lose your archive promise, technical proof required before launch.';

  static const prereqOrderLine =
      'Proof prerequisites: account identity, restore, backup, privacy, and migration.';

  static const guardrail =
      'Cross device continuity future gate classifies continuity as future only. No cloud backup promise. No access everywhere promise. No never lose your archive promise. Requires account identity, restore, backup, privacy, and migration proof before launch.';

  static const continuityFrozenLine =
      'Keep cross-device continuity frozen until account, restore, backup, privacy, and migration proof are complete.';

  static const futureContinuityDocumentedLine =
      'Technical proof complete. Document cross-device continuity as future expansion only — not a V1 promise.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeTechnicalProof = 'Blocked before technical proof';
  static const detailFutureContinuityDocumented = 'Future continuity documented only';

  static String prereqLabelFor(CrossDeviceContinuityFuturePrereqId id) =>
      switch (id) {
        CrossDeviceContinuityFuturePrereqId.accountIdentityProof =>
          'Account identity proof',
        CrossDeviceContinuityFuturePrereqId.restoreProof => 'Restore proof',
        CrossDeviceContinuityFuturePrereqId.backupProof => 'Backup proof',
        CrossDeviceContinuityFuturePrereqId.privacyProof => 'Privacy proof',
        CrossDeviceContinuityFuturePrereqId.migrationProof => 'Migration proof',
      };

  static String ruleLabelFor(CrossDeviceContinuityFutureRuleId id) => switch (id) {
        CrossDeviceContinuityFutureRuleId.futureOnly => 'Future only',
        CrossDeviceContinuityFutureRuleId.noCloudBackupPromise =>
          'No cloud backup promise',
        CrossDeviceContinuityFutureRuleId.noAccessEverywherePromise =>
          'No access everywhere promise',
        CrossDeviceContinuityFutureRuleId.noNeverLoseArchivePromise =>
          'No never lose your archive promise',
        CrossDeviceContinuityFutureRuleId.technicalProofBeforeLaunch =>
          'Technical proof before launch',
      };

  static String messageFor(CrossDeviceContinuityFutureGateDecision decision) =>
      switch (decision) {
        CrossDeviceContinuityFutureGateDecision.continuityFrozen =>
          continuityFrozenLine,
        CrossDeviceContinuityFutureGateDecision.futureContinuityDocumented =>
          futureContinuityDocumentedLine,
      };

  static String recommendationFor(
    CrossDeviceContinuityFutureGateDecision decision,
  ) =>
      switch (decision) {
        CrossDeviceContinuityFutureGateDecision.continuityFrozen =>
          'Do not promise cloud backup, access everywhere, or never-lose-archive language until technical proof is complete.',
        CrossDeviceContinuityFutureGateDecision.futureContinuityDocumented =>
          'Document cross-device continuity as future expansion only. Keep local-archive honesty in V1 copy.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield continuityFrozenLine;
    yield futureContinuityDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeTechnicalProof;
    yield detailFutureContinuityDocumented;
    for (final id in CrossDeviceContinuityFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in CrossDeviceContinuityFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in CrossDeviceContinuityFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum CrossDeviceContinuityFuturePrereqId {
  accountIdentityProof,
  restoreProof,
  backupProof,
  privacyProof,
  migrationProof,
}

enum CrossDeviceContinuityFuturePrereqStatus {
  pass,
  pending,
  fail,
}

enum CrossDeviceContinuityFutureRuleId {
  futureOnly,
  noCloudBackupPromise,
  noAccessEverywherePromise,
  noNeverLoseArchivePromise,
  technicalProofBeforeLaunch,
}

enum CrossDeviceContinuityFutureRuleStatus {
  pass,
  fail,
}

enum CrossDeviceContinuityFutureGateDecision {
  continuityFrozen,
  futureContinuityDocumented,
}
