import 'package:archiveme_mobile/features/production_candidate/production_candidate_checklist.dart';

/// Production candidate copy — release readiness report only.
abstract final class ProductionCandidateCopy {
  ProductionCandidateCopy._();

  static const guardrail =
      'No new product features before submission. Only fix blockers, store '
      'readiness, secrets, or critical bugs.';

  static ProductionCandidateReport report(
    ProductionCandidateChecklist checklist,
    ProductionCandidateStatus status,
  ) => ProductionCandidateReport(
    title: titleFor(status),
    body: bodyFor(status),
    nextAction: nextActionFor(status),
    guardrail: guardrail,
    missingItems: checklist.missingItems().toList(growable: false),
  );

  static String titleFor(ProductionCandidateStatus status) => switch (status) {
    ProductionCandidateStatus.notReady => 'Product signal is not ready',
    ProductionCandidateStatus.betaReadyButStoreNotReady =>
      'Beta signal is ready, store prep is not',
    ProductionCandidateStatus.storeReadyButSecretsNotReady =>
      'Store prep is ready, secrets are not',
    ProductionCandidateStatus.readyForSubmission =>
      'Ready for App Store submission',
  };

  static String bodyFor(ProductionCandidateStatus status) => switch (status) {
    ProductionCandidateStatus.notReady =>
      'The beta loop has not yet passed every product-signal gate.',
    ProductionCandidateStatus.betaReadyButStoreNotReady =>
      'Product signal is strong enough, but store and device readiness is incomplete.',
    ProductionCandidateStatus.storeReadyButSecretsNotReady =>
      'Store and device checks are done, but production secrets still need rotation.',
    ProductionCandidateStatus.readyForSubmission =>
      'Beta signal, store prep, secrets, and device checks are all complete.',
  };

  static String nextActionFor(
    ProductionCandidateStatus status,
  ) => switch (status) {
    ProductionCandidateStatus.notReady =>
      'Do one targeted repair based on the beta results reader. Do not add broad features.',
    ProductionCandidateStatus.betaReadyButStoreNotReady =>
      'Complete App Store, RevenueCat, restore purchases, device, and metadata checks.',
    ProductionCandidateStatus.storeReadyButSecretsNotReady =>
      'Rotate exposed production secrets before launch.',
    ProductionCandidateStatus.readyForSubmission =>
      'Freeze scope and submit the production candidate.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final status in ProductionCandidateStatus.values) {
      yield titleFor(status);
      yield bodyFor(status);
      yield nextActionFor(status);
    }
  }
}

class ProductionCandidateReport {
  const ProductionCandidateReport({
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