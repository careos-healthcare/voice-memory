import 'v1_surface_scope_audit_copy.dart';

/// V1 surface scope audit — classify visible surfaces without deleting features.
abstract final class V1SurfaceScopeAudit {
  V1SurfaceScopeAudit._();

  static const coreSurfaces = [
    V1VisibleSurface.record,
    V1VisibleSurface.save,
    V1VisibleSurface.postSaveReinforcement,
    V1VisibleSurface.promptAssist,
    V1VisibleSurface.firstProof,
    V1VisibleSurface.whyProofAppeared,
    V1VisibleSurface.confirmCorrect,
    V1VisibleSurface.proLongerProofTrail,
    V1VisibleSurface.restorePurchases,
    V1VisibleSurface.privacySupport,
  ];

  static const secondarySurfaces = [
    V1VisibleSurface.reports,
    V1VisibleSurface.dashboards,
    V1VisibleSurface.actionItems,
    V1VisibleSurface.archivePacks,
    V1VisibleSurface.archiveAnalyst,
    V1VisibleSurface.search,
    V1VisibleSurface.calendar,
    V1VisibleSurface.widgets,
    V1VisibleSurface.monthlyReviews,
    V1VisibleSurface.shareCards,
    V1VisibleSurface.actionPlans,
    V1VisibleSurface.contextMaps,
  ];

  static const releaseBlockerSurfaces = [
    V1VisibleSurface.purchase,
    V1VisibleSurface.restore,
    V1VisibleSurface.entitlement,
    V1VisibleSurface.testFlight,
    V1VisibleSurface.metadata,
    V1VisibleSurface.privacy,
    V1VisibleSurface.support,
    V1VisibleSurface.secrets,
  ];

  static V1SurfaceScope scopeFor(V1VisibleSurface surface) {
    if (coreSurfaces.contains(surface)) return V1SurfaceScope.coreV1;
    if (secondarySurfaces.contains(surface)) {
      return V1SurfaceScope.secondaryHidden;
    }
    if (releaseBlockerSurfaces.contains(surface)) {
      return V1SurfaceScope.releaseBlockerOnly;
    }
    return V1SurfaceScope.secondaryHidden;
  }

  static V1SurfaceScopeAuditResult audit(V1SurfaceScopeAuditInput input) {
    if (input.requestsProductDeletion) {
      return _result(
        surface: input.surface,
        scope: scopeFor(input.surface),
        decision: V1ScopeDecision.blockProductDeletion,
        requiredForRelease: false,
        visibleInV1: false,
      );
    }
    if (input.requestsLayoutChange && !input.isReleaseBlocker) {
      return _result(
        surface: input.surface,
        scope: scopeFor(input.surface),
        decision: V1ScopeDecision.blockLayoutChangeUnlessBlocker,
        requiredForRelease: false,
        visibleInV1: scopeFor(input.surface) == V1SurfaceScope.coreV1,
      );
    }

    final scope = scopeFor(input.surface);
    return switch (scope) {
      V1SurfaceScope.coreV1 => _result(
        surface: input.surface,
        scope: scope,
        decision: V1ScopeDecision.coreAllowed,
        requiredForRelease: true,
        visibleInV1: true,
      ),
      V1SurfaceScope.secondaryHidden => _result(
        surface: input.surface,
        scope: scope,
        decision: V1ScopeDecision.secondaryNotRequiredForRelease,
        requiredForRelease: false,
        visibleInV1: false,
      ),
      V1SurfaceScope.releaseBlockerOnly => _result(
        surface: input.surface,
        scope: scope,
        decision: V1ScopeDecision.releaseBlockerAllowed,
        requiredForRelease: true,
        visibleInV1: false,
      ),
    };
  }

  static V1SurfaceScopeAuditReport report(V1SurfaceScopeAuditResult result) =>
      V1SurfaceScopeAuditReport(
        headline: V1SurfaceScopeAuditCopy.headline,
        body: V1SurfaceScopeAuditCopy.body,
        coreLine: V1SurfaceScopeAuditCopy.coreLine,
        secondaryLine: V1SurfaceScopeAuditCopy.secondaryLine,
        blockerLine: V1SurfaceScopeAuditCopy.blockerLine,
        guardrail: V1SurfaceScopeAuditCopy.guardrail,
        result: result,
      );

  static V1SurfaceScopeAuditResult _result({
    required V1VisibleSurface surface,
    required V1SurfaceScope scope,
    required V1ScopeDecision decision,
    required bool requiredForRelease,
    required bool visibleInV1,
  }) => V1SurfaceScopeAuditResult(
    surface: surface,
    scope: scope,
    decision: decision,
    requiredForRelease: requiredForRelease,
    visibleInV1: visibleInV1,
  );
}

enum V1VisibleSurface {
  record,
  save,
  postSaveReinforcement,
  promptAssist,
  firstProof,
  whyProofAppeared,
  confirmCorrect,
  proLongerProofTrail,
  restorePurchases,
  privacySupport,
  reports,
  dashboards,
  actionItems,
  archivePacks,
  archiveAnalyst,
  search,
  calendar,
  widgets,
  monthlyReviews,
  shareCards,
  actionPlans,
  contextMaps,
  purchase,
  restore,
  entitlement,
  testFlight,
  metadata,
  privacy,
  support,
  secrets,
}

enum V1SurfaceScope { coreV1, secondaryHidden, releaseBlockerOnly }

enum V1ScopeDecision {
  coreAllowed,
  secondaryNotRequiredForRelease,
  releaseBlockerAllowed,
  blockProductDeletion,
  blockLayoutChangeUnlessBlocker,
}

class V1SurfaceScopeAuditInput {
  const V1SurfaceScopeAuditInput({
    required this.surface,
    required this.requestsProductDeletion,
    required this.requestsLayoutChange,
    required this.isReleaseBlocker,
  });

  final V1VisibleSurface surface;
  final bool requestsProductDeletion;
  final bool requestsLayoutChange;
  final bool isReleaseBlocker;
}

class V1SurfaceScopeAuditResult {
  const V1SurfaceScopeAuditResult({
    required this.surface,
    required this.scope,
    required this.decision,
    required this.requiredForRelease,
    required this.visibleInV1,
  });

  final V1VisibleSurface surface;
  final V1SurfaceScope scope;
  final V1ScopeDecision decision;
  final bool requiredForRelease;
  final bool visibleInV1;
}

class V1SurfaceScopeAuditReport {
  const V1SurfaceScopeAuditReport({
    required this.headline,
    required this.body,
    required this.coreLine,
    required this.secondaryLine,
    required this.blockerLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String coreLine;
  final String secondaryLine;
  final String blockerLine;
  final String guardrail;
  final V1SurfaceScopeAuditResult result;
}
