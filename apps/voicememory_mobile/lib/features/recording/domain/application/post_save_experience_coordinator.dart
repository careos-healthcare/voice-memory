import '../../../../features/explainable_conclusion/auditable_conclusion_trust_policy.dart';
import '../../../../features/explainable_conclusion/auditable_personal_change_engine.dart';
import '../../../../features/explainable_conclusion/explainable_conclusion.dart';
import '../../../../features/explainable_conclusion/explainable_conclusion_validator.dart';
import '../../../../features/insight_feedback/insight_feedback_models.dart';
import '../../../../features/monetization/domain/access_policy_engine.dart';
import '../../../../features/monetization/domain/product_value_delivery_ledger.dart';
import '../../../../models/journal_entry.dart';
import '../../../../subscriptions/domain/subscription_models.dart';
import 'save_moment_coordinator.dart';

/// Which promise this post-save moment is keeping.
///
/// These are delivery milestones, not archive positions. A `firstSave`
/// experience is the first observation ArchiveMe can actually stand behind,
/// which may well be the user's fourth saved moment.
enum PostSaveExperienceKind {
  /// The first valid observation, whenever it finally becomes possible.
  firstSave,

  /// The first genuine comparison, against any eligible earlier moment.
  secondRelatedSave,

  /// Both free promises are already kept; this is ongoing Pro territory or a
  /// previously delivered artifact being read again.
  returnSave,

  noConclusion,
}

final class PostSaveExperience {
  const PostSaveExperience({
    required this.kind,
    required this.entry,
    required this.priorEntries,
    required this.conclusion,
    required this.nextQuestion,
  });

  final PostSaveExperienceKind kind;
  final JournalEntry entry;
  final List<JournalEntry> priorEntries;
  final ValidatedExplainableConclusion? conclusion;
  final String? nextQuestion;

  bool get hasConclusion => conclusion != null;
}

/// Pure policy boundary for the focused commercial V1 post-save experience.
///
/// It selects at most one auditable conclusion. Free value is offered on the
/// evidence of the [ProductValueDeliveryLedger] — what ArchiveMe has actually
/// delivered — and never on how many moments the archive holds. An archive of
/// forty unrelated moments has not been given its free observation, and a
/// first observation that only becomes possible on the fourth save is still
/// the first one.
///
/// This coordinator never marks anything as delivered. Delivery is recorded
/// from the UI once the artifact is on screen.
final class PostSaveExperienceCoordinator {
  const PostSaveExperienceCoordinator({
    this.entitlement = const EntitlementSnapshot.free(),
    this.usage = const UsageSnapshot(),
    this.productValue = const ProductValueState(),
    this.deliveryLedger = const ProductValueDeliveryLedger.empty(),
  });

  factory PostSaveExperienceCoordinator.forSubscription(
    SubscriptionState? subscription, {
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
    ProductValueDeliveryLedger deliveryLedger =
        const ProductValueDeliveryLedger.empty(),
    bool legacyGrandfathered = false,
  }) => PostSaveExperienceCoordinator(
    entitlement: subscription == null
        ? const EntitlementSnapshot.free()
        : EntitlementSnapshot.fromSubscriptionState(
            subscription,
            legacyGrandfathered: legacyGrandfathered,
          ),
    usage: usage,
    productValue: productValue,
    deliveryLedger: deliveryLedger,
  );

  final EntitlementSnapshot entitlement;
  final UsageSnapshot usage;
  final ProductValueState productValue;
  final ProductValueDeliveryLedger deliveryLedger;

  PostSaveExperience build(
    SavedMomentResult moment, {
    Iterable<InsightFeedbackRecord> feedback = const [],
  }) {
    final entries = List<JournalEntry>.unmodifiable(moment.entries);
    final priorEntries = List<JournalEntry>.unmodifiable(
      entries.where((entry) => entry.id != moment.entry.id),
    );
    final eligibleEntries = entries.where(_isEligibleEvidence).toList();
    final canonicalTranscripts = <String, String>{
      for (final entry in eligibleEntries) entry.id: entry.transcript,
      if (_isEligibleEvidence(moment.entry))
        moment.entry.id: moment.entry.transcript,
    };

    PostSaveExperience experience(
      PostSaveExperienceKind kind,
      ValidatedExplainableConclusion? conclusion,
    ) => PostSaveExperience(
      kind: conclusion == null ? PostSaveExperienceKind.noConclusion : kind,
      entry: moment.entry,
      priorEntries: priorEntries,
      conclusion: conclusion,
      nextQuestion: _nextQuestion(conclusion),
    );

    final observation = _freeObservation(
      moment.entry,
      canonicalTranscripts,
      feedback,
    );
    if (observation != null) {
      return experience(PostSaveExperienceKind.firstSave, observation);
    }

    final comparison = _freeComparison(eligibleEntries, feedback);
    if (comparison != null) {
      return experience(PostSaveExperienceKind.secondRelatedSave, comparison);
    }

    return experience(
      PostSaveExperienceKind.returnSave,
      _ongoingConclusion(
        eligibleEntries,
        moment.entry,
        canonicalTranscripts,
        feedback,
      ),
    );
  }

  /// The first observation ArchiveMe can defend, at whatever archive position
  /// it becomes possible. An earlier moment that produced nothing valid never
  /// consumed this promise.
  ValidatedExplainableConclusion? _freeObservation(
    JournalEntry entry,
    Map<String, String> canonicalTranscripts,
    Iterable<InsightFeedbackRecord> feedback,
  ) {
    final candidate = entry.reflection.explainableConclusion;
    if (candidate == null ||
        candidate.kind != ExplainableInsightKind.observation) {
      return null;
    }
    if (!_mayDeliverFreeProof(DeliveredValueKind.observation)) return null;
    return _rank(
      [candidate],
      canonicalTranscripts: canonicalTranscripts,
      feedback: feedback,
    );
  }

  /// The first genuine comparison, searched across every eligible related
  /// prior moment rather than archive positions one and two.
  ValidatedExplainableConclusion? _freeComparison(
    List<JournalEntry> entries,
    Iterable<InsightFeedbackRecord> feedback,
  ) {
    if (!_mayDeliverFreeProof(DeliveredValueKind.comparison)) return null;
    return AuditablePersonalChangeEngine.buildEarlyComparison(
      entries: entries,
      feedback: feedback,
    )?.conclusion;
  }

  ValidatedExplainableConclusion? _ongoingConclusion(
    List<JournalEntry> entries,
    JournalEntry current,
    Map<String, String> canonicalTranscripts,
    Iterable<InsightFeedbackRecord> feedback,
  ) {
    final persisted = current.reflection.explainableConclusion;
    if (persisted != null && _mayReadExisting()) {
      final ranked = _rank(
        [persisted],
        canonicalTranscripts: canonicalTranscripts,
        feedback: feedback,
      );
      if (ranked != null) return ranked;
    }
    if (!_mayGenerate(CapabilityId.ongoingComparisons)) return null;
    return AuditablePersonalChangeEngine.buildEarlyComparison(
      entries: entries,
      feedback: feedback,
    )?.conclusion;
  }

  ValidatedExplainableConclusion? _rank(
    Iterable<ExplainableConclusion> candidates, {
    required Map<String, String> canonicalTranscripts,
    required Iterable<InsightFeedbackRecord> feedback,
  }) => AuditableConclusionTrustPolicy.rankBest(
    candidates: candidates,
    canonicalTranscripts: canonicalTranscripts,
    feedback: feedback,
  )?.conclusion;

  /// True when this free promise is still unkept.
  ///
  /// A promise already kept is not delivered a second time. The artifact that
  /// kept it is still shown — it comes back through the ongoing path, which is
  /// what keeps it readable once Pro lapses.
  bool _mayDeliverFreeProof(DeliveredValueKind kind) =>
      !deliveryLedger.hasDelivered(kind) && _mayGenerate(kind.capability);

  bool _mayGenerate(CapabilityId capability) {
    return AccessPolicyEngine.decide(
      capability: capability,
      entitlement: entitlement,
      usage: usage,
      productValue: _effectiveProductValue,
    ).allowed;
  }

  bool _mayReadExisting() {
    return AccessPolicyEngine.decide(
      capability: CapabilityId.readExistingGeneratedOutput,
      entitlement: entitlement,
      usage: usage,
      productValue: _effectiveProductValue,
    ).allowed;
  }

  /// Real deliveries always count. Legacy generation bookkeeping is kept only
  /// so an existing install is never offered the same proof twice.
  ProductValueState get _effectiveProductValue => ProductValueState(
    generatedCapabilities: {
      ...productValue.generatedCapabilities,
      ...deliveryLedger.productValue.generatedCapabilities,
    },
  );

  static String? _nextQuestion(ValidatedExplainableConclusion? conclusion) {
    final suggested = conclusion?.value.nextRecordingPrompt?.trim();
    if (suggested?.isNotEmpty == true) return suggested!;
    return null;
  }

  static bool _isEligibleEvidence(JournalEntry entry) =>
      !entry.isArchived &&
      !entry.isDeleted &&
      !AuditablePersonalChangeEngine.holdsGeneratedPlaceholder(entry);
}
