/// Freeze drift scanner copy — block feature drift during release freeze.
abstract final class FreezeDriftScannerCopy {
  FreezeDriftScannerCopy._();

  static const headline = 'Freeze drift scanner';

  static const body =
      'During release candidate freeze, scan changes for risky product drift '
      'and allow only release blocker fixes.';

  static const riskyLine =
      'Risky drift: new surfaces, dashboards, reports, rankings, action items, '
      'context expansion, chat mode, storage positioning, extra Pro promises, '
      'proof volume expansion, record layout changes, and anchor or threshold changes.';

  static const allowedLine =
      'Allowed during freeze: crash fixes, store readiness, purchase, restore, '
      'entitlement, metadata, privacy, support, security, first journey comprehension, '
      'and critical proof trust bugs.';

  static const blockedLine =
      'Risky drift detected. Stop the change and fix only release blockers.';

  static const allowedChangeLine =
      'Change fits release freeze. Blocker fix only, no feature drift.';

  static const freezeInactiveLine =
      'Release freeze is not active. Drift scan is informational only.';

  static const guardrail =
      'Freeze drift scanner protects release freeze. No product UI changes.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield riskyLine;
    yield allowedLine;
    yield blockedLine;
    yield allowedChangeLine;
    yield freezeInactiveLine;
  }
}
