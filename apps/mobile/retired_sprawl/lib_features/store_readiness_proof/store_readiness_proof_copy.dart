/// Store readiness proof copy — prove billing and submission before new features.
abstract final class StoreReadinessProofCopy {
  StoreReadinessProofCopy._();

  static const headline = 'Store readiness proof';

  static const body =
      'ArchiveMe should not add more product features until purchase, restore, '
      'entitlement, metadata, screenshots, and device smoke are proven.';

  static const revenueCatLine =
      'RevenueCat must load products with the real API key.';

  static const restoreLine =
      'Restore purchases must be reachable and must not crash.';

  static const entitlementLine =
      'Pro state must be readable before and after purchase or restore.';

  static const fallbackLine =
      'When purchases are unavailable, ArchiveMe should explain calmly and keep '
      'the app usable.';

  static const metadataLine =
      'Support URL, privacy URL, screenshots, and App Store metadata must be ready.';

  static const deviceLine =
      'Run a physical-device smoke test before submission.';

  static const secretsLine =
      'Before production launch, rotate exposed Stripe secrets and update production '
      'environment variables.';

  static const guardrail =
      'No new product features before store readiness blockers are cleared.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield revenueCatLine;
    yield restoreLine;
    yield entitlementLine;
    yield fallbackLine;
    yield metadataLine;
    yield deviceLine;
    yield secretsLine;
    yield guardrail;
  }
}