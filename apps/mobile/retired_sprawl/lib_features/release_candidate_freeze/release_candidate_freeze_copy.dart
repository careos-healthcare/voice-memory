/// Release candidate freeze copy — fix blockers only, no feature drift.
abstract final class ReleaseCandidateFreezeCopy {
  ReleaseCandidateFreezeCopy._();

  static const headline = 'Release candidate freeze';

  static const body =
      'ArchiveMe should stop adding product features. From here, only fix blockers '
      'that affect release, purchase, restore, trust, safety, or the first journey.';

  static const allowedLine =
      'Allowed: store readiness, purchase, restore, entitlement, crash, signing, '
      'TestFlight, metadata, privacy, support, security, App Store risk, and '
      'critical first-journey fixes.';

  static const blockedLine =
      'Blocked: new features, new dashboards, rankings, reports, action items, '
      'context expansion, chat mode, storage positioning, and extra Pro promises.';

  static const firstJourneyLine =
      'Protect the first journey: save one repeat, feel it mattered, understand '
      'ArchiveMe compares later, then see the first useful proof.';

  static const proLine =
      'Protect the Pro promise: Free shows the first useful proof. Pro keeps the '
      'longer proof trail.';

  static const guardrail =
      'During release freeze, do not build more product. Fix only release blockers.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield allowedLine;
    yield blockedLine;
    yield firstJourneyLine;
    yield proLine;
  }
}