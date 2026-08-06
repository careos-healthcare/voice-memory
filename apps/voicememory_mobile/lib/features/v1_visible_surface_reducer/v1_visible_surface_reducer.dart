import '../archive_evidence/archive_evidence_quality_gate.dart';
import 'v1_visible_surface_reducer_copy.dart';

/// V1 visible surface reducer — shrink first-release journey without deletion.
abstract final class V1VisibleSurfaceReducer {
  V1VisibleSurfaceReducer._();

  static const surfaceCount = 25;

  static const coreSurfaces = [
    V1Surface.recordCapture,
    V1Surface.typeInstead,
    V1Surface.promptAssist,
    V1Surface.postSaveReinforcement,
    V1Surface.restorePurchases,
    V1Surface.privacySupport,
    V1Surface.archiveHome,
  ];

  static const hiddenSurfaces = [
    V1Surface.archiveHealth,
    V1Surface.evidenceMap,
    V1Surface.reports,
    V1Surface.actionItems,
    V1Surface.archivePacks,
    V1Surface.archiveAnalyst,
    V1Surface.widgets,
    V1Surface.contextExpansion,
    V1Surface.dashboard,
    V1Surface.search,
    V1Surface.monthlyReview,
  ];

  static const proofGatedSurfaces = [
    V1Surface.firstProof,
    V1Surface.whyProofAppeared,
    V1Surface.confirmCorrect,
    V1Surface.whatChanged,
    V1Surface.proLongerTrail,
  ];

  static V1VisibleSurfaceReducerReport report(
    V1VisibleSurfaceReducerResult result,
  ) => V1VisibleSurfaceReducerReport(
    headline: V1VisibleSurfaceReducerCopy.headline,
    body: V1VisibleSurfaceReducerCopy.body,
    coreLine: V1VisibleSurfaceReducerCopy.coreLine,
    hiddenLine: V1VisibleSurfaceReducerCopy.hiddenLine,
    guardrail: V1VisibleSurfaceReducerCopy.guardrail,
    result: result,
  );

  static V1SurfaceDecision baseDecisionFor(V1Surface surface) =>
      switch (surface) {
        V1Surface.recordCapture ||
        V1Surface.typeInstead ||
        V1Surface.promptAssist ||
        V1Surface.postSaveReinforcement ||
        V1Surface.restorePurchases ||
        V1Surface.privacySupport ||
        V1Surface.archiveHome => V1SurfaceDecision.showCore,
        V1Surface.firstProof ||
        V1Surface.whyProofAppeared ||
        V1Surface.confirmCorrect ||
        V1Surface.whatChanged ||
        V1Surface.proLongerTrail => V1SurfaceDecision.allowAfterProof,
        V1Surface.shareProof => V1SurfaceDecision.allowOnlyWhenUserAsked,
        V1Surface.developerDiagnostics => V1SurfaceDecision.developerOnly,
        V1Surface.archiveHealth ||
        V1Surface.evidenceMap ||
        V1Surface.reports ||
        V1Surface.actionItems ||
        V1Surface.archivePacks ||
        V1Surface.archiveAnalyst ||
        V1Surface.widgets ||
        V1Surface.contextExpansion ||
        V1Surface.dashboard ||
        V1Surface.search ||
        V1Surface.monthlyReview => V1SurfaceDecision.hideForV1,
      };

  static bool detectProofThresholdStillThree(
    String archiveEvidenceGateSource,
  ) => archiveEvidenceGateSource.contains(
    'static const minProofEntryCount = 3;',
  );

  static bool detectRecordLayoutUnchanged(String recordScreenSource) =>
      recordScreenSource.contains('RecordScreen') &&
      !recordScreenSource.contains('reorderCaptureControls');

  static V1VisibleSurfaceReducerInput fromRepoSignals({
    required String archiveEvidenceGateSource,
    bool postSaveImmediate = false,
    bool firstProofSafe = false,
    bool afterFirstProof = false,
    bool confirmedRepeatOrEligibleMoment = false,
    bool proofValueSeen = false,
    bool userExplicitlyAsked = false,
    bool developerMode = false,
  }) => V1VisibleSurfaceReducerInput(
    postSaveImmediate: postSaveImmediate,
    firstProofSafe:
        firstProofSafe &&
        detectProofThresholdStillThree(archiveEvidenceGateSource),
    afterFirstProof: afterFirstProof,
    confirmedRepeatOrEligibleMoment: confirmedRepeatOrEligibleMoment,
    proofValueSeen: proofValueSeen,
    userExplicitlyAsked: userExplicitlyAsked,
    developerMode: developerMode,
    proofThresholdStillThree: detectProofThresholdStillThree(
      archiveEvidenceGateSource,
    ),
  );

  static V1VisibleSurfaceReducerResult build(
    V1VisibleSurfaceReducerInput input,
  ) {
    final surfaces = {
      for (final surface in V1Surface.values) surface: resolve(surface, input),
    };
    return V1VisibleSurfaceReducerResult(
      surfaces: surfaces,
      visibleCoreCount: surfaces.values
          .where(
            (item) =>
                item.visible && item.decision == V1SurfaceDecision.showCore,
          )
          .length,
      hiddenCount: surfaces.values
          .where((item) => item.decision == V1SurfaceDecision.hideForV1)
          .length,
      keepsV1Small: surfaces.values
          .where((item) => hiddenSurfaces.contains(item.surface))
          .every((item) => !item.visible),
    );
  }

  static V1VisibleSurfaceReducerSurfaceResult resolve(
    V1Surface surface,
    V1VisibleSurfaceReducerInput input,
  ) {
    final decision = baseDecisionFor(surface);
    final visible = _isVisible(
      surface: surface,
      decision: decision,
      input: input,
    );
    return V1VisibleSurfaceReducerSurfaceResult(
      surface: surface,
      label: V1VisibleSurfaceReducerCopy.labelFor(surface),
      decision: decision,
      visible: visible,
      detailLabel: _detailFor(
        surface: surface,
        decision: decision,
        visible: visible,
        input: input,
      ),
    );
  }

  static bool _isVisible({
    required V1Surface surface,
    required V1SurfaceDecision decision,
    required V1VisibleSurfaceReducerInput input,
  }) => switch (decision) {
    V1SurfaceDecision.showCore => switch (surface) {
      V1Surface.postSaveReinforcement => input.postSaveImmediate,
      _ => true,
    },
    V1SurfaceDecision.allowAfterProof => _proofGatedVisible(
      surface: surface,
      input: input,
    ),
    V1SurfaceDecision.allowOnlyWhenUserAsked => input.userExplicitlyAsked,
    V1SurfaceDecision.hideForV1 => false,
    V1SurfaceDecision.developerOnly => input.developerMode,
    V1SurfaceDecision.releaseBlockerOnly => false,
  };

  static bool _proofGatedVisible({
    required V1Surface surface,
    required V1VisibleSurfaceReducerInput input,
  }) => switch (surface) {
    V1Surface.firstProof => input.firstProofGuardSafe,
    V1Surface.whyProofAppeared ||
    V1Surface.confirmCorrect => input.afterFirstProof,
    V1Surface.whatChanged => input.confirmedRepeatOrEligibleMoment,
    V1Surface.proLongerTrail => input.afterFirstProof || input.proofValueSeen,
    _ => false,
  };

  static String _detailFor({
    required V1Surface surface,
    required V1SurfaceDecision decision,
    required bool visible,
    required V1VisibleSurfaceReducerInput input,
  }) {
    if (!visible) {
      return switch (decision) {
        V1SurfaceDecision.hideForV1 => V1VisibleSurfaceReducerCopy.detailHidden,
        V1SurfaceDecision.allowAfterProof =>
          V1VisibleSurfaceReducerCopy.detailGated,
        V1SurfaceDecision.allowOnlyWhenUserAsked =>
          V1VisibleSurfaceReducerCopy.detailUserAsked,
        V1SurfaceDecision.developerOnly =>
          V1VisibleSurfaceReducerCopy.detailDeveloper,
        V1SurfaceDecision.showCore
            when surface == V1Surface.postSaveReinforcement =>
          V1VisibleSurfaceReducerCopy.detailPostSave,
        _ => V1VisibleSurfaceReducerCopy.detailHidden,
      };
    }
    if (surface == V1Surface.postSaveReinforcement) {
      return V1VisibleSurfaceReducerCopy.detailPostSave;
    }
    return V1VisibleSurfaceReducerCopy.detailVisible;
  }
}

class V1VisibleSurfaceReducerInput {
  const V1VisibleSurfaceReducerInput({
    this.postSaveImmediate = false,
    this.firstProofSafe = false,
    this.afterFirstProof = false,
    this.confirmedRepeatOrEligibleMoment = false,
    this.proofValueSeen = false,
    this.userExplicitlyAsked = false,
    this.developerMode = false,
    this.proofThresholdStillThree = true,
  });

  final bool postSaveImmediate;
  final bool firstProofSafe;
  final bool afterFirstProof;
  final bool confirmedRepeatOrEligibleMoment;
  final bool proofValueSeen;
  final bool userExplicitlyAsked;
  final bool developerMode;
  final bool proofThresholdStillThree;

  bool get firstProofGuardSafe =>
      firstProofSafe &&
      proofThresholdStillThree &&
      ArchiveEvidenceQualityGate.minProofEntryCount == 3;
}

class V1VisibleSurfaceReducerSurfaceResult {
  const V1VisibleSurfaceReducerSurfaceResult({
    required this.surface,
    required this.label,
    required this.decision,
    required this.visible,
    required this.detailLabel,
  });

  final V1Surface surface;
  final String label;
  final V1SurfaceDecision decision;
  final bool visible;
  final String detailLabel;
}

class V1VisibleSurfaceReducerResult {
  const V1VisibleSurfaceReducerResult({
    required this.surfaces,
    required this.visibleCoreCount,
    required this.hiddenCount,
    required this.keepsV1Small,
  });

  final Map<V1Surface, V1VisibleSurfaceReducerSurfaceResult> surfaces;
  final int visibleCoreCount;
  final int hiddenCount;
  final bool keepsV1Small;

  V1VisibleSurfaceReducerSurfaceResult surface(V1Surface id) => surfaces[id]!;
}

class V1VisibleSurfaceReducerReport {
  const V1VisibleSurfaceReducerReport({
    required this.headline,
    required this.body,
    required this.coreLine,
    required this.hiddenLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String coreLine;
  final String hiddenLine;
  final String guardrail;
  final V1VisibleSurfaceReducerResult result;
}
