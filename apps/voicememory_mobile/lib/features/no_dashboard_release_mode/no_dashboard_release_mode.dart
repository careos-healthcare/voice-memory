import '../../config/production_navigation.dart';
import '../no_dashboard_positioning/no_dashboard_positioning_guard.dart';
import '../v1_visible_surface_reducer/v1_visible_surface_reducer.dart';
import '../v1_visible_surface_reducer/v1_visible_surface_reducer_copy.dart';
import 'no_dashboard_release_mode_copy.dart';

/// No dashboard release mode — hide dashboard surfaces in V1 release builds.
abstract final class NoDashboardReleaseMode {
  NoDashboardReleaseMode._();

  static const riskySurfaceCount = 9;
  static const allowedSurfaceCount = 9;

  static const riskySurfaces = [
    NoDashboardReleaseSurface.archiveHealth,
    NoDashboardReleaseSurface.actionPlan,
    NoDashboardReleaseSurface.evidenceMap,
    NoDashboardReleaseSurface.workspaceQuickActions,
    NoDashboardReleaseSurface.reports,
    NoDashboardReleaseSurface.dashboard,
    NoDashboardReleaseSurface.contextInsights,
    NoDashboardReleaseSurface.monthlyReview,
    NoDashboardReleaseSurface.archiveAnalyst,
  ];

  static const allowedSurfaces = [
    NoDashboardReleaseSurface.record,
    NoDashboardReleaseSurface.typeInstead,
    NoDashboardReleaseSurface.promptAssist,
    NoDashboardReleaseSurface.postSaveReinforcement,
    NoDashboardReleaseSurface.firstProof,
    NoDashboardReleaseSurface.whyProofAppeared,
    NoDashboardReleaseSurface.confirmCorrect,
    NoDashboardReleaseSurface.whatChanged,
    NoDashboardReleaseSurface.proLongerTrail,
  ];

  static const lowRiskSecondarySurfaces = [
    NoDashboardReleaseSurface.shareProof,
  ];

  static const blockedReleasePhrases = [
    'dashboard',
    'command center',
    'second brain',
    'life os',
    'life operating system',
  ];

  static NoDashboardReleaseModeResult build(
    NoDashboardReleaseModeInput input,
  ) {
    final surfaces = {
      for (final surface in NoDashboardReleaseSurface.values)
        surface: resolve(surface, input),
    };
    final riskyHiddenInRelease = !input.releaseMode ||
        riskySurfaces.every((surface) => !surfaces[surface]!.visible);
    final decision = riskyHiddenInRelease
        ? NoDashboardReleaseModeDecision.hardened
        : NoDashboardReleaseModeDecision.violated;

    return NoDashboardReleaseModeResult(
      decision: decision,
      message: decision == NoDashboardReleaseModeDecision.hardened
          ? NoDashboardReleaseModeCopy.hardenedOkLine
          : NoDashboardReleaseModeCopy.violatedLine,
      surfaces: surfaces,
      riskyHiddenInRelease: riskyHiddenInRelease,
      keepsProofTrailFocus: decision == NoDashboardReleaseModeDecision.hardened,
    );
  }

  static NoDashboardReleaseModeReport report(
    NoDashboardReleaseModeResult result,
  ) =>
      NoDashboardReleaseModeReport(
        headline: NoDashboardReleaseModeCopy.headline,
        body: NoDashboardReleaseModeCopy.body,
        riskyLine: NoDashboardReleaseModeCopy.riskyLine,
        allowedLine: NoDashboardReleaseModeCopy.allowedLine,
        guardrail: NoDashboardReleaseModeCopy.guardrail,
        result: result,
      );

  static NoDashboardReleaseSurfaceResult resolve(
    NoDashboardReleaseSurface surface,
    NoDashboardReleaseModeInput input,
  ) {
    final visible = _shouldShow(surface: surface, input: input);
    return NoDashboardReleaseSurfaceResult(
      surface: surface,
      label: NoDashboardReleaseModeCopy.labelFor(surface),
      visible: visible,
      risky: isRiskySurface(surface),
      detailLabel: _detailFor(surface: surface, visible: visible, input: input),
    );
  }

  static bool isRiskySurface(NoDashboardReleaseSurface surface) =>
      riskySurfaces.contains(surface);

  static bool isAllowedSurface(NoDashboardReleaseSurface surface) =>
      allowedSurfaces.contains(surface);

  static bool isLowRiskSecondarySurface(NoDashboardReleaseSurface surface) =>
      lowRiskSecondarySurfaces.contains(surface);

  static bool passesReleaseCopy(String copy) {
    if (!NoDashboardPositioningGuard.passes(copy)) return false;
    final lower = copy.toLowerCase().trim();
    if (lower.isEmpty) return true;
    for (final phrase in blockedReleasePhrases) {
      if (lower.contains(phrase) && !_isNegated(lower, phrase)) {
        return false;
      }
    }
    return true;
  }

  static bool detectReleaseModeHook(String productionNavigationSource) =>
      productionNavigationSource.contains('hideIncompleteSurfaces') &&
      productionNavigationSource.contains('kReleaseMode');

  static bool detectRecordLayoutUnchanged(String recordScreenSource) =>
      V1VisibleSurfaceReducer.detectRecordLayoutUnchanged(recordScreenSource);

  static NoDashboardReleaseModeInput fromReducerInput({
    required bool releaseMode,
    required V1VisibleSurfaceReducerInput reducerInput,
  }) =>
      NoDashboardReleaseModeInput(
        releaseMode: releaseMode,
        postSaveImmediate: reducerInput.postSaveImmediate,
        firstProofSafe: reducerInput.firstProofSafe,
        afterFirstProof: reducerInput.afterFirstProof,
        confirmedRepeatOrEligibleMoment:
            reducerInput.confirmedRepeatOrEligibleMoment,
        proofValueSeen: reducerInput.proofValueSeen,
        userExplicitlyAsked: reducerInput.userExplicitlyAsked,
        proofThresholdStillThree: reducerInput.proofThresholdStillThree,
      );

  static bool releaseModeActive() => ProductionNavigation.hideIncompleteSurfaces;

  static V1Surface? toV1Surface(NoDashboardReleaseSurface surface) =>
      switch (surface) {
        NoDashboardReleaseSurface.record => V1Surface.recordCapture,
        NoDashboardReleaseSurface.typeInstead => V1Surface.typeInstead,
        NoDashboardReleaseSurface.promptAssist => V1Surface.promptAssist,
        NoDashboardReleaseSurface.postSaveReinforcement =>
          V1Surface.postSaveReinforcement,
        NoDashboardReleaseSurface.firstProof => V1Surface.firstProof,
        NoDashboardReleaseSurface.whyProofAppeared =>
          V1Surface.whyProofAppeared,
        NoDashboardReleaseSurface.confirmCorrect => V1Surface.confirmCorrect,
        NoDashboardReleaseSurface.whatChanged => V1Surface.whatChanged,
        NoDashboardReleaseSurface.proLongerTrail => V1Surface.proLongerTrail,
        NoDashboardReleaseSurface.shareProof => V1Surface.shareProof,
        NoDashboardReleaseSurface.archiveHealth => V1Surface.archiveHealth,
        NoDashboardReleaseSurface.evidenceMap => V1Surface.evidenceMap,
        NoDashboardReleaseSurface.reports => V1Surface.reports,
        NoDashboardReleaseSurface.dashboard => V1Surface.dashboard,
        NoDashboardReleaseSurface.contextInsights =>
          V1Surface.contextExpansion,
        NoDashboardReleaseSurface.monthlyReview => V1Surface.monthlyReview,
        NoDashboardReleaseSurface.archiveAnalyst => V1Surface.archiveAnalyst,
        NoDashboardReleaseSurface.actionPlan ||
        NoDashboardReleaseSurface.workspaceQuickActions =>
          null,
      };

  static bool _shouldShow({
    required NoDashboardReleaseSurface surface,
    required NoDashboardReleaseModeInput input,
  }) {
    if (isAllowedSurface(surface)) {
      return _allowedVisible(surface: surface, input: input);
    }

    if (isLowRiskSecondarySurface(surface)) {
      if (!input.releaseMode) {
        return input.userExplicitlyAsked;
      }
      return input.userExplicitlyAsked;
    }

    if (isRiskySurface(surface)) {
      if (!input.releaseMode) {
        return input.userExplicitlyAsked;
      }
      if (_supportsFirstProof(surface) && input.afterFirstProof) {
        return true;
      }
      return false;
    }

    return false;
  }

  static bool _allowedVisible({
    required NoDashboardReleaseSurface surface,
    required NoDashboardReleaseModeInput input,
  }) {
    final mapped = toV1Surface(surface);
    if (mapped == null) return false;
    final reducerInput = V1VisibleSurfaceReducerInput(
      postSaveImmediate: input.postSaveImmediate,
      firstProofSafe: input.firstProofSafe,
      afterFirstProof: input.afterFirstProof,
      confirmedRepeatOrEligibleMoment: input.confirmedRepeatOrEligibleMoment,
      proofValueSeen: input.proofValueSeen,
      userExplicitlyAsked: input.userExplicitlyAsked,
      developerMode: false,
      proofThresholdStillThree: input.proofThresholdStillThree,
    );
    return V1VisibleSurfaceReducer.resolve(mapped, reducerInput).visible;
  }

  static bool _supportsFirstProof(NoDashboardReleaseSurface surface) => false;

  static String _detailFor({
    required NoDashboardReleaseSurface surface,
    required bool visible,
    required NoDashboardReleaseModeInput input,
  }) {
    if (visible) {
      if (surface == NoDashboardReleaseSurface.postSaveReinforcement) {
        return NoDashboardReleaseModeCopy.detailPostSave;
      }
      if (isLowRiskSecondarySurface(surface) && input.userExplicitlyAsked) {
        return NoDashboardReleaseModeCopy.detailUserAsked;
      }
      if (isAllowedSurface(surface) &&
          (surface == NoDashboardReleaseSurface.firstProof ||
              surface == NoDashboardReleaseSurface.whyProofAppeared ||
              surface == NoDashboardReleaseSurface.confirmCorrect ||
              surface == NoDashboardReleaseSurface.whatChanged ||
              surface == NoDashboardReleaseSurface.proLongerTrail) &&
          !input.afterFirstProof) {
        return NoDashboardReleaseModeCopy.detailProofGated;
      }
      return NoDashboardReleaseModeCopy.detailVisible;
    }

    if (isRiskySurface(surface) && input.releaseMode) {
      return NoDashboardReleaseModeCopy.detailHidden;
    }
    if (isLowRiskSecondarySurface(surface) && !input.userExplicitlyAsked) {
      return NoDashboardReleaseModeCopy.detailHidden;
    }
    return NoDashboardReleaseModeCopy.detailHidden;
  }

  static bool _isNegated(String lower, String phrase) {
    final index = lower.indexOf(phrase);
    if (index < 0) return false;
    final before = lower.substring(0, index);
    if (before.contains('avoid')) return true;
    if (before.contains('do not')) return true;
    if (RegExp(r'\bnot\b').hasMatch(before)) return true;
    if (RegExp(r'\bno\b').hasMatch(before)) return true;
    return false;
  }
}

class NoDashboardReleaseModeInput {
  const NoDashboardReleaseModeInput({
    this.releaseMode = true,
    this.postSaveImmediate = false,
    this.firstProofSafe = false,
    this.afterFirstProof = false,
    this.confirmedRepeatOrEligibleMoment = false,
    this.proofValueSeen = false,
    this.userExplicitlyAsked = false,
    this.proofThresholdStillThree = true,
  });

  final bool releaseMode;
  final bool postSaveImmediate;
  final bool firstProofSafe;
  final bool afterFirstProof;
  final bool confirmedRepeatOrEligibleMoment;
  final bool proofValueSeen;
  final bool userExplicitlyAsked;
  final bool proofThresholdStillThree;
}

class NoDashboardReleaseSurfaceResult {
  const NoDashboardReleaseSurfaceResult({
    required this.surface,
    required this.label,
    required this.visible,
    required this.risky,
    required this.detailLabel,
  });

  final NoDashboardReleaseSurface surface;
  final String label;
  final bool visible;
  final bool risky;
  final String detailLabel;
}

class NoDashboardReleaseModeResult {
  const NoDashboardReleaseModeResult({
    required this.decision,
    required this.message,
    required this.surfaces,
    required this.riskyHiddenInRelease,
    required this.keepsProofTrailFocus,
  });

  final NoDashboardReleaseModeDecision decision;
  final String message;
  final Map<NoDashboardReleaseSurface, NoDashboardReleaseSurfaceResult> surfaces;
  final bool riskyHiddenInRelease;
  final bool keepsProofTrailFocus;

  NoDashboardReleaseSurfaceResult surface(NoDashboardReleaseSurface id) =>
      surfaces[id]!;
}

class NoDashboardReleaseModeReport {
  const NoDashboardReleaseModeReport({
    required this.headline,
    required this.body,
    required this.riskyLine,
    required this.allowedLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String riskyLine;
  final String allowedLine;
  final String guardrail;
  final NoDashboardReleaseModeResult result;
}
