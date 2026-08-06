import 'context_trail_clarity_copy.dart';

/// Context trail clarity — optional context evidence, hidden until useful.
abstract final class ContextTrailClarity {
  ContextTrailClarity._();

  static ContextTrailClarityResult build(ContextTrailClarityInput input) {
    if (input.isFirstSession) {
      return ContextTrailClarityResult.hidden(
        reason: ContextTrailClarityReason.hiddenFirstSession,
      );
    }
    if (input.isRecordScreen) {
      return ContextTrailClarityResult.hidden(
        reason: ContextTrailClarityReason.hiddenRecordScreen,
      );
    }
    if (input.hasUserCorrection) {
      return ContextTrailClarityResult.hidden(
        reason: ContextTrailClarityReason.hiddenAfterCorrection,
      );
    }
    if (input.userAskedForContext && input.eligibleEntryCount >= 2) {
      return ContextTrailClarityResult.surface(
        reason: ContextTrailClarityReason.surfaceWhenUserAsked,
      );
    }
    if (input.eligibleEntryCount < 3) {
      return ContextTrailClarityResult.hidden(
        reason: ContextTrailClarityReason.hiddenNotEnoughEvidence,
      );
    }
    if (input.taggedContextCount == 0) {
      return ContextTrailClarityResult.quiet(
        reason: ContextTrailClarityReason.quietOptionalContext,
      );
    }
    if (input.distinctContextCount == 1 && input.hasStrongProof) {
      return ContextTrailClarityResult.surface(
        reason: ContextTrailClarityReason.surfaceSingleContextEvidence,
      );
    }
    if (input.distinctContextCount > 1 && input.hasStrongProof) {
      return ContextTrailClarityResult.surface(
        reason: ContextTrailClarityReason.surfaceVariedContextEvidence,
      );
    }
    return ContextTrailClarityResult.quiet(
      reason: ContextTrailClarityReason.quietOptionalContext,
    );
  }

  static ContextTrailClarityReport report(ContextTrailClarityResult result) =>
      ContextTrailClarityReport(
        headline: ContextTrailClarityCopy.headline,
        body: ContextTrailClarityCopy.body,
        optionalLine: ContextTrailClarityCopy.optionalLine,
        evidenceLine: ContextTrailClarityCopy.evidenceLine,
        notMaintenanceLine: ContextTrailClarityCopy.notMaintenanceLine,
        trailLine: ContextTrailClarityCopy.trailLine,
        proLaterLine: ContextTrailClarityCopy.proLaterLine,
        guardrail: ContextTrailClarityCopy.guardrail,
        result: result,
      );
}

enum ContextTrailClarityReason {
  hiddenFirstSession,
  hiddenRecordScreen,
  hiddenNotEnoughEvidence,
  hiddenAfterCorrection,
  quietOptionalContext,
  surfaceSingleContextEvidence,
  surfaceVariedContextEvidence,
  surfaceWhenUserAsked,
}

class ContextTrailClarityInput {
  const ContextTrailClarityInput({
    required this.eligibleEntryCount,
    required this.taggedContextCount,
    required this.distinctContextCount,
    required this.hasStrongProof,
    required this.hasUserCorrection,
    required this.isFirstSession,
    required this.isRecordScreen,
    required this.userAskedForContext,
  });

  final int eligibleEntryCount;
  final int taggedContextCount;
  final int distinctContextCount;
  final bool hasStrongProof;
  final bool hasUserCorrection;
  final bool isFirstSession;
  final bool isRecordScreen;
  final bool userAskedForContext;
}

class ContextTrailClarityResult {
  const ContextTrailClarityResult({
    required this.shouldSurfaceContext,
    required this.shouldKeepQuiet,
    required this.reason,
  });

  factory ContextTrailClarityResult.hidden({
    required ContextTrailClarityReason reason,
  }) => ContextTrailClarityResult(
    shouldSurfaceContext: false,
    shouldKeepQuiet: true,
    reason: reason,
  );

  factory ContextTrailClarityResult.quiet({
    required ContextTrailClarityReason reason,
  }) => ContextTrailClarityResult(
    shouldSurfaceContext: false,
    shouldKeepQuiet: true,
    reason: reason,
  );

  factory ContextTrailClarityResult.surface({
    required ContextTrailClarityReason reason,
  }) => ContextTrailClarityResult(
    shouldSurfaceContext: true,
    shouldKeepQuiet: false,
    reason: reason,
  );

  final bool shouldSurfaceContext;
  final bool shouldKeepQuiet;
  final ContextTrailClarityReason reason;
}

class ContextTrailClarityReport {
  const ContextTrailClarityReport({
    required this.headline,
    required this.body,
    required this.optionalLine,
    required this.evidenceLine,
    required this.notMaintenanceLine,
    required this.trailLine,
    required this.proLaterLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String optionalLine;
  final String evidenceLine;
  final String notMaintenanceLine;
  final String trailLine;
  final String proLaterLine;
  final String guardrail;
  final ContextTrailClarityResult result;
}
