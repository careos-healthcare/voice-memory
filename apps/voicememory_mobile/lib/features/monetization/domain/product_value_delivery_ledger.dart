import '../../explainable_conclusion/auditable_conclusion_trust_policy.dart';
import '../../explainable_conclusion/explainable_conclusion.dart';
import '../../explainable_conclusion/explainable_conclusion_validator.dart';
import '../../explainable_conclusion/semantic_conclusion_gate.dart';
import '../../insight_feedback/insight_feedback_models.dart';
import 'access_policy_engine.dart';

/// The two kinds of free proof ArchiveMe promises before it ever asks for money.
enum DeliveredValueKind { observation, comparison }

extension DeliveredValueCapability on DeliveredValueKind {
  CapabilityId get capability => switch (this) {
    DeliveredValueKind.observation => CapabilityId.firstEvidenceObservation,
    DeliveredValueKind.comparison => CapabilityId.firstEarlyComparison,
  };

  static DeliveredValueKind? forConclusion(ExplainableInsightKind kind) =>
      switch (kind) {
        ExplainableInsightKind.observation => DeliveredValueKind.observation,
        ExplainableInsightKind.pattern ||
        ExplainableInsightKind.change => DeliveredValueKind.comparison,
      };
}

/// Why an attempted delivery did not consume free proof.
enum ProductValueDeliveryRejection {
  /// Candidate generation never produced anything — including network failure.
  generationFailed,

  /// The conclusion does not follow from its own cited words.
  semanticValidationFailed,

  /// A citation does not resolve to an exact span of a live transcript.
  exactEvidenceValidationFailed,

  /// The user's feedback suppressed this framing before it could be shown.
  outputSuppressed,

  /// The artifact could not be written durably.
  persistenceFailed,

  /// The artifact was generated but never actually put in front of the user.
  notRendered,

  /// This exact artifact already delivered this proof. Retrying is free.
  alreadyDelivered,

  /// A different artifact already delivered this proof.
  proofAlreadyConsumed,
}

/// Durable record of the free value ArchiveMe has actually delivered.
///
/// Delivery is proven by a rendered, validated artifact — never by how many
/// moments the archive happens to hold. A raw entry count says nothing about
/// whether the product did anything useful, so it can never stand in for
/// proof here.
class ProductValueDeliveryLedger {
  const ProductValueDeliveryLedger({
    required this.policyVersion,
    this.firstValidObservationArtifactId,
    this.firstValidObservationDeliveredAt,
    this.firstValidComparisonArtifactId,
    this.firstValidComparisonDeliveredAt,
  });

  const ProductValueDeliveryLedger.empty()
    : this(policyVersion: MonetizationPolicy.policyVersion);

  final String? firstValidObservationArtifactId;
  final DateTime? firstValidObservationDeliveredAt;
  final String? firstValidComparisonArtifactId;
  final DateTime? firstValidComparisonDeliveredAt;
  final String policyVersion;

  String? artifactIdFor(DeliveredValueKind kind) => switch (kind) {
    DeliveredValueKind.observation => firstValidObservationArtifactId,
    DeliveredValueKind.comparison => firstValidComparisonArtifactId,
  };

  DateTime? deliveredAtFor(DeliveredValueKind kind) => switch (kind) {
    DeliveredValueKind.observation => firstValidObservationDeliveredAt,
    DeliveredValueKind.comparison => firstValidComparisonDeliveredAt,
  };

  bool hasDelivered(DeliveredValueKind kind) =>
      artifactIdFor(kind)?.trim().isNotEmpty == true;

  /// Artifacts the user has already been shown. These stay readable forever,
  /// including after a Pro subscription lapses.
  Set<String> get deliveredArtifactIds => {
    for (final kind in DeliveredValueKind.values) ?artifactIdFor(kind),
  };

  /// The commercial state the access policy consumes. Only proof that was
  /// really delivered can close a free-proof capability.
  ProductValueState get productValue => ProductValueState(
    generatedCapabilities: {
      for (final kind in DeliveredValueKind.values)
        if (hasDelivered(kind)) kind.capability,
    },
  );

  ProductValueDeliveryLedger recordDelivered({
    required DeliveredValueKind kind,
    required String artifactId,
    required DateTime at,
    String? policyVersion,
  }) {
    final deliveredAt = at.toUtc();
    return ProductValueDeliveryLedger(
      policyVersion: policyVersion ?? this.policyVersion,
      firstValidObservationArtifactId: kind == DeliveredValueKind.observation
          ? artifactId
          : firstValidObservationArtifactId,
      firstValidObservationDeliveredAt: kind == DeliveredValueKind.observation
          ? deliveredAt
          : firstValidObservationDeliveredAt,
      firstValidComparisonArtifactId: kind == DeliveredValueKind.comparison
          ? artifactId
          : firstValidComparisonArtifactId,
      firstValidComparisonDeliveredAt: kind == DeliveredValueKind.comparison
          ? deliveredAt
          : firstValidComparisonDeliveredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'policyVersion': policyVersion,
    if (firstValidObservationArtifactId != null)
      'firstValidObservationArtifactId': firstValidObservationArtifactId,
    if (firstValidObservationDeliveredAt != null)
      'firstValidObservationDeliveredAt': firstValidObservationDeliveredAt!
          .toUtc()
          .toIso8601String(),
    if (firstValidComparisonArtifactId != null)
      'firstValidComparisonArtifactId': firstValidComparisonArtifactId,
    if (firstValidComparisonDeliveredAt != null)
      'firstValidComparisonDeliveredAt': firstValidComparisonDeliveredAt!
          .toUtc()
          .toIso8601String(),
  };

  static ProductValueDeliveryLedger fromJson(Object? value) {
    if (value is! Map) return const ProductValueDeliveryLedger.empty();
    final json = Map<String, dynamic>.from(value);
    String? id(String key) {
      final raw = json[key]?.toString().trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    DateTime? at(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '')?.toUtc();

    final observationId = id('firstValidObservationArtifactId');
    final comparisonId = id('firstValidComparisonArtifactId');
    return ProductValueDeliveryLedger(
      policyVersion: id('policyVersion') ?? MonetizationPolicy.policyVersion,
      // A delivery timestamp without an artifact id proves nothing, and an
      // artifact id without a timestamp is still a real delivery.
      firstValidObservationArtifactId: observationId,
      firstValidObservationDeliveredAt: observationId == null
          ? null
          : at('firstValidObservationDeliveredAt'),
      firstValidComparisonArtifactId: comparisonId,
      firstValidComparisonDeliveredAt: comparisonId == null
          ? null
          : at('firstValidComparisonDeliveredAt'),
    );
  }
}

/// One attempt to deliver free value, carrying every fact the gate needs.
class ProductValueDeliveryAttempt {
  const ProductValueDeliveryAttempt({
    required this.candidate,
    required this.canonicalTranscripts,
    required this.generationSucceeded,
    required this.artifactPersisted,
    required this.rendered,
    this.feedback = const [],
    this.deletedEntryIds = const {},
    this.generatedTextEntryIds = const {},
  });

  /// Generation never completed — an offline model call, a transport error or
  /// an engine that found nothing defensible to say.
  const ProductValueDeliveryAttempt.generationFailed()
    : candidate = null,
      canonicalTranscripts = const {},
      generationSucceeded = false,
      artifactPersisted = false,
      rendered = false,
      feedback = const [],
      deletedEntryIds = const {},
      generatedTextEntryIds = const {};

  final ExplainableConclusion? candidate;
  final Map<String, String> canonicalTranscripts;
  final bool generationSucceeded;
  final bool artifactPersisted;
  final bool rendered;
  final Iterable<InsightFeedbackRecord> feedback;
  final Set<String> deletedEntryIds;
  final Set<String> generatedTextEntryIds;
}

class ProductValueDeliveryOutcome {
  const ProductValueDeliveryOutcome({
    required this.ledger,
    required this.consumedFreeProof,
    required this.kind,
    required this.rejection,
  });

  final ProductValueDeliveryLedger ledger;

  /// True only when this attempt closed a free-proof slot that was open.
  final bool consumedFreeProof;

  final DeliveredValueKind? kind;
  final ProductValueDeliveryRejection? rejection;

  /// True when the user is now holding this proof, whether this attempt or an
  /// earlier identical one put it there.
  bool get delivered =>
      consumedFreeProof ||
      rejection == ProductValueDeliveryRejection.alreadyDelivered;
}

/// The single authority that decides whether free proof was actually spent.
///
/// Every one of the five conditions must hold: the candidate was generated,
/// it survived the semantic gate, its citations resolved to exact transcript
/// spans, it was written durably, and it was put in front of the user. A
/// failure at any stage leaves the free slot open for a later attempt.
abstract final class ProductValueDeliveryGate {
  static ProductValueDeliveryOutcome record({
    required ProductValueDeliveryLedger ledger,
    required ProductValueDeliveryAttempt attempt,
    required DateTime now,
  }) {
    ProductValueDeliveryOutcome reject(
      ProductValueDeliveryRejection rejection, {
      DeliveredValueKind? kind,
    }) => ProductValueDeliveryOutcome(
      ledger: ledger,
      consumedFreeProof: false,
      kind: kind,
      rejection: rejection,
    );

    final candidate = attempt.candidate;
    if (!attempt.generationSucceeded || candidate == null) {
      return reject(ProductValueDeliveryRejection.generationFailed);
    }

    final semantic = SemanticConclusionGate.assess(
      conclusion: candidate,
      canonicalTranscripts: attempt.canonicalTranscripts,
      deletedEntryIds: attempt.deletedEntryIds,
      generatedTextEntryIds: attempt.generatedTextEntryIds,
    );
    if (!semantic.isEntailed) {
      return reject(ProductValueDeliveryRejection.semanticValidationFailed);
    }

    final validated = ExplainableConclusionRenderGate.visible(
      candidate,
      canonicalTranscripts: attempt.canonicalTranscripts,
    );
    if (validated == null) {
      return reject(
        ProductValueDeliveryRejection.exactEvidenceValidationFailed,
      );
    }

    // Both gates passed, so anything the production trust policy still drops
    // was dropped because the user told ArchiveMe to stop showing it.
    final ranked = AuditableConclusionTrustPolicy.rankBest(
      candidates: [candidate],
      canonicalTranscripts: attempt.canonicalTranscripts,
      feedback: attempt.feedback,
      deletedEntryIds: attempt.deletedEntryIds,
      generatedTextEntryIds: attempt.generatedTextEntryIds,
    );
    if (ranked == null) {
      return reject(ProductValueDeliveryRejection.outputSuppressed);
    }

    if (!attempt.artifactPersisted) {
      return reject(ProductValueDeliveryRejection.persistenceFailed);
    }
    if (!attempt.rendered) {
      return reject(ProductValueDeliveryRejection.notRendered);
    }

    final kind = DeliveredValueCapability.forConclusion(candidate.kind);
    if (kind == null) {
      return reject(ProductValueDeliveryRejection.generationFailed);
    }

    final existing = ledger.artifactIdFor(kind);
    if (existing != null) {
      return reject(
        existing == candidate.id
            ? ProductValueDeliveryRejection.alreadyDelivered
            : ProductValueDeliveryRejection.proofAlreadyConsumed,
        kind: kind,
      );
    }

    return ProductValueDeliveryOutcome(
      ledger: ledger.recordDelivered(
        kind: kind,
        artifactId: candidate.id,
        at: now,
      ),
      consumedFreeProof: true,
      kind: kind,
      rejection: null,
    );
  }
}
