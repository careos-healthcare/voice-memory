import '../../../product/auditable_change_positioning.dart';
import 'access_policy_engine.dart';

/// Fixed customer copy for the contextual paywall.
///
/// Nothing here interpolates journal text. The only archive-derived value the
/// paywall may render is a count, or a thread label the user named and
/// approved themselves.
abstract final class ContextualPaywallCopy {
  /// The product the paywall extends, stated before it asks for anything.
  static const String positioning = AuditableChangePositioning.primaryPromise;

  static const String primary =
      'See the exact moments where the pattern repeated—and the evidence '
      'that it is changing.';

  static const String supporting =
      'Your recordings stay yours. Pro unlocks ongoing comparisons and '
      'deeper change history.';

  static const String originalsNeverGated =
      'Opening, playing, editing, exporting and deleting your original '
      'moments does not require Pro.';

  static const String awaitingFreeProof =
      'ArchiveMe shows you its first evidence-backed observation before it '
      'asks for anything.';

  /// Safe contextual count. Derived from how many saved moments a genuine
  /// Pro-only comparison would draw on — never from their content.
  static String comparisonCount(int count) => count == 1
      ? '1 saved moment is ready for comparison.'
      : '$count saved moments are ready for comparison.';

  /// Only reachable when the user explicitly approved or named the thread.
  static String approvedThread(String label) => "Continue following '$label'.";
}

/// What the paywall is permitted to know about the archive behind it.
class ContextualPaywallContext {
  const ContextualPaywallContext({this.comparableMomentCount = 0})
    : approvedThreadLabel = null,
      threadLabelApproved = false;

  /// The only way a thread label can reach the paywall. Callers must pass the
  /// user's own approval, so an inferred topic can never leak by default.
  const ContextualPaywallContext.withApprovedThread({
    required String label,
    required bool approvedByUser,
    this.comparableMomentCount = 0,
  }) : approvedThreadLabel = label,
       threadLabelApproved = approvedByUser;

  /// How many saved moments a genuine Pro-only comparison would use.
  final int comparableMomentCount;

  final String? approvedThreadLabel;
  final bool threadLabelApproved;

  String? get safeThreadLabel {
    if (!threadLabelApproved) return null;
    final label = approvedThreadLabel?.trim();
    return label == null || label.isEmpty ? null : label;
  }
}

/// The resolved paywall surface: whether it may appear at all, and the exact
/// strings it is allowed to render.
class ContextualPaywallContent {
  const ContextualPaywallContent._({
    required this.visible,
    required this.contextLine,
    required this.capabilityLines,
  });

  /// True only once free proof has been delivered and Pro is genuinely
  /// required for the capability the user reached for.
  final bool visible;

  /// A safe count, or an approved thread label. Null when neither is earned.
  final String? contextLine;

  /// Capabilities that are actually available. Unavailable ones are omitted
  /// rather than advertised with a conditional qualifier.
  final List<String> capabilityLines;

  String get primaryCopy => ContextualPaywallCopy.primary;
  String get supportingCopy => ContextualPaywallCopy.supporting;
}

/// Decides when the paywall may appear and what it may say.
///
/// [AccessPolicyEngine] remains the only authority on access itself; this type
/// only translates one of its denials into a contextual surface.
abstract final class ContextualPaywallPolicy {
  /// Capabilities that must never be behind the paywall, whatever the
  /// entitlement state: the user's own recordings and transcripts, evidence
  /// that was already generated, and correcting an interpretation.
  static const Set<CapabilityId> neverPaywalled = {
    CapabilityId.createTypedEntry,
    CapabilityId.createVoiceRecording,
    CapabilityId.openOriginalEntry,
    CapabilityId.readSavedTranscript,
    CapabilityId.editOriginalContent,
    CapabilityId.playOriginalAudio,
    CapabilityId.browseOriginalArchive,
    CapabilityId.openEvidenceSource,
    CapabilityId.correctInterpretation,
    CapabilityId.hideInterpretation,
    CapabilityId.deleteOriginalContent,
    CapabilityId.exportOriginalContent,
    CapabilityId.readExistingGeneratedOutput,
  };

  /// Capabilities the paywall is allowed to name, in display order.
  static const List<CapabilityId> advertisableCapabilities = [
    CapabilityId.ongoingComparisons,
    CapabilityId.fullChangesHistoryGeneration,
    CapabilityId.deepArchiveSynthesis,
    CapabilityId.fullHistoryQuestion,
    CapabilityId.periodicReviewGeneration,
    CapabilityId.advancedEvidenceGrouping,
  ];

  static bool mayPaywall(CapabilityId capability) =>
      !neverPaywalled.contains(capability) &&
      MonetizationPolicy.capability(capability).accessClass !=
          AccessClass.userOwned;

  /// Free proof is delivered when at least one free-proof capability has been
  /// spent on a rendered artifact.
  static bool freeProofDelivered(ProductValueState productValue) =>
      productValue.hasGenerated(CapabilityId.firstEvidenceObservation) ||
      productValue.hasGenerated(CapabilityId.firstEarlyComparison);

  static ContextualPaywallContent resolve({
    required EntitlementSnapshot entitlement,
    CapabilityId capability = CapabilityId.ongoingComparisons,
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
    ContextualPaywallContext context = const ContextualPaywallContext(),
    Set<CapabilityId> unavailableCapabilities = const {},
    bool? freeProofDeliveredOverride,
  }) {
    final delivered =
        freeProofDeliveredOverride ?? freeProofDelivered(productValue);
    final decision = AccessPolicyEngine.decide(
      capability: capability,
      entitlement: entitlement,
      usage: usage,
      productValue: productValue,
    );
    // A Pro holder is never offered Pro, even when a metered allowance is
    // temporarily unavailable to them.
    final visible =
        delivered &&
        mayPaywall(capability) &&
        !entitlement.hasProAccess &&
        !decision.allowed;
    return ContextualPaywallContent._(
      visible: visible,
      contextLine: visible ? _contextLine(context) : null,
      capabilityLines: visible
          ? capabilityLines(unavailableCapabilities: unavailableCapabilities)
          : const [],
    );
  }

  static List<String> capabilityLines({
    Set<CapabilityId> unavailableCapabilities = const {},
  }) => List.unmodifiable([
    for (final capability in advertisableCapabilities)
      if (!unavailableCapabilities.contains(capability))
        _copyFor(MonetizationPolicy.capability(capability).copyKey),
  ]);

  static String? _contextLine(ContextualPaywallContext context) {
    if (context.safeThreadLabel case final label?) {
      return ContextualPaywallCopy.approvedThread(label);
    }
    // A comparison needs at least two saved moments to be genuine.
    if (context.comparableMomentCount >= 2) {
      return ContextualPaywallCopy.comparisonCount(
        context.comparableMomentCount,
      );
    }
    return null;
  }

  static String _copyFor(String copyKey) => switch (copyKey) {
    'ongoingComparisons' => MonetizationPolicy.ongoingComparisons,
    'fullChangesHistory' => MonetizationPolicy.fullChangesHistory,
    'deeperArchiveAnalysis' => MonetizationPolicy.deeperArchiveAnalysis,
    'fullHistoryQuestions' => MonetizationPolicy.fullHistoryQuestions,
    'periodicReviews' => MonetizationPolicy.periodicReviews,
    'advancedEvidenceGrouping' => MonetizationPolicy.advancedEvidenceGrouping,
    _ => throw ArgumentError.value(copyKey, 'copyKey', 'unknown paywall copy'),
  };
}
