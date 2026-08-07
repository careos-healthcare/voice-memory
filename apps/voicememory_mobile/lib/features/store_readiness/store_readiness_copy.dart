import 'store_readiness_audit.dart';

/// Store readiness copy — App Store submission report only.
abstract final class StoreReadinessCopy {
  StoreReadinessCopy._();

  static const guardrail =
      'No new product features before submission. Only fix blockers, store '
      'readiness, secrets, or critical bugs.';

  static StoreReadinessReport report(
    StoreReadinessAudit audit,
    StoreReadinessStatus status,
  ) => StoreReadinessReport(
    title: titleFor(status),
    body: bodyFor(status),
    nextAction: nextActionFor(status),
    guardrail: guardrail,
    missingItems: audit.missingItems().toList(growable: false),
  );

  static String titleFor(StoreReadinessStatus status) => switch (status) {
    StoreReadinessStatus.notReady => 'Build and device checks incomplete',
    StoreReadinessStatus.storeAssetsMissing => 'App Store assets missing',
    StoreReadinessStatus.revenueCatOrRestoreMissing =>
      'RevenueCat or restore purchases not verified',
    StoreReadinessStatus.secretsNotRotated => 'Production secrets not rotated',
    StoreReadinessStatus.readyForSubmission => 'Store readiness complete',
  };

  static String bodyFor(StoreReadinessStatus status) => switch (status) {
    StoreReadinessStatus.notReady =>
      'Store assets and billing checks may be done, but the latest TestFlight build or physical device smoke test is still missing.',
    StoreReadinessStatus.storeAssetsMissing =>
      'Support URL, privacy policy, screenshots, or metadata are not ready for App Store submission.',
    StoreReadinessStatus.revenueCatOrRestoreMissing =>
      'App Store assets are ready, but RevenueCat products or restore purchases still need verification.',
    StoreReadinessStatus.secretsNotRotated =>
      'Store and billing checks are complete, but production secrets still need rotation.',
    StoreReadinessStatus.readyForSubmission =>
      'TestFlight, device smoke test, App Store assets, billing, and secrets are all ready.',
  };

  static String nextActionFor(StoreReadinessStatus status) => switch (status) {
    StoreReadinessStatus.notReady =>
      'Upload the latest TestFlight build and complete a physical device smoke test.',
    StoreReadinessStatus.storeAssetsMissing =>
      'Finish App Store support URL, privacy policy, screenshots, and metadata.',
    StoreReadinessStatus.revenueCatOrRestoreMissing =>
      'Verify RevenueCat products, entitlement access, purchase, and restore purchases.',
    StoreReadinessStatus.secretsNotRotated =>
      'Rotate exposed production secrets before launch.',
    StoreReadinessStatus.readyForSubmission =>
      'Freeze scope and submit the production candidate.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final status in StoreReadinessStatus.values) {
      yield titleFor(status);
      yield bodyFor(status);
      yield nextActionFor(status);
    }
  }
}

class StoreReadinessReport {
  const StoreReadinessReport({
    required this.title,
    required this.body,
    required this.nextAction,
    required this.guardrail,
    required this.missingItems,
  });

  final String title;
  final String body;
  final String nextAction;
  final String guardrail;
  final List<String> missingItems;
}
