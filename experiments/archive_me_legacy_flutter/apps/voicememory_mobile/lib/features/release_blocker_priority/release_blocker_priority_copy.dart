/// Release blocker priority copy — fix highest-impact blockers first during freeze.
abstract final class ReleaseBlockerPriorityCopy {
  ReleaseBlockerPriorityCopy._();

  static const headline = 'Fix blockers in order';

  static const body =
      'During release candidate freeze, fix the highest-impact blocker first. '
      'Do not start new product work.';

  static const priorityLine =
      'Priority: security → crash → store readiness → App Store risk → purchase '
      '→ restore → entitlement → first journey → proof trust → paid-intent beta.';

  static const securityLine =
      'Fix security and secrets blockers before anything else.';

  static const crashLine = 'Fix crashes before store or purchase work.';

  static const storeReadinessLine =
      'Prove store readiness: signing, TestFlight, metadata, privacy, and support.';

  static const purchaseLine =
      'Prove purchase flow works before polishing new copy or surfaces.';

  static const restoreLine =
      'Prove restore purchases works and does not crash.';

  static const entitlementLine =
      'Prove Pro entitlement state is readable after purchase and restore.';

  static const firstJourneyLine =
      'Protect first journey comprehension: save one repeat, feel it mattered, '
      'see first useful proof.';

  static const proofTrustLine =
      'Fix critical proof trust bugs before expanding proof volume.';

  static const paidIntentLine =
      'Run paid-intent beta validation after release blockers are cleared.';

  static const readyLine =
      'Blockers cleared. Run paid-intent beta on TestFlight without adding features.';

  static const freezeLine =
      'Release freeze is active. Only blocker fixes are in scope.';

  static const guardrail =
      'Blocker priority must focus release effort, not new product surfaces or '
      'feature volume.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield priorityLine;
    yield securityLine;
    yield crashLine;
    yield storeReadinessLine;
    yield purchaseLine;
    yield restoreLine;
    yield entitlementLine;
    yield firstJourneyLine;
    yield proofTrustLine;
    yield paidIntentLine;
    yield readyLine;
    yield freezeLine;
  }
}
