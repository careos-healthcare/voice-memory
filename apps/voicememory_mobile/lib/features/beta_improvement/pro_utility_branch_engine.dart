import '../beta_decision/beta_decision_model.dart';
import '../beta_decision/beta_tester_outcome_store.dart';
import 'beta_improvement_model.dart';
import 'beta_improvement_recommendation_gate.dart';
import 'pro_utility_boundary_model.dart';
import 'pro_utility_copy_fix.dart';

/// Feature detection for existing export/report surfaces — no new routes.
class ProUtilityBranchConfig {
  const ProUtilityBranchConfig({
    this.exportSurfaceLive = true,
    this.privateReportLive = false,
  });

  /// `/export` + `ExportScreen` exist with coverage; link only when allowed.
  final bool exportSurfaceLive;

  /// Monthly private report remains preview/planned unless fully tested live.
  final bool privateReportLive;

  static const defaults = ProUtilityBranchConfig();
}

/// Applies gated Pro utility when the proUtility branch is active.
abstract final class ProUtilityBranchEngine {
  ProUtilityBranchEngine._();

  static const minEntryCount = 3;
  static const exportRoute = '/export';

  static bool isBranchRecommended({
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.proUtility,
        outcomesOverride: outcomesOverride,
      );

  static bool hasExplicitUtilityAsk({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final outcomes = outcomesOverride ?? BetaTesterOutcomeStore.allOutcomes;
    return outcomes.any((outcome) => outcome.askedForUtilityExpansion);
  }

  static bool shouldShowUtility({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (entryCount == 0) return false;
    if (!isBranchRecommended(outcomesOverride: outcomesOverride)) return false;

    final explicitAsk = hasExplicitUtilityAsk(outcomesOverride: outcomesOverride);
    if (!hasMeaningfulProof && !explicitAsk) return false;

    return BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.proUtility,
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof || explicitAsk,
      outcomesOverride: outcomesOverride,
    );
  }

  static bool shouldShowBridge({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      shouldShowUtility(
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      ) &&
      entryCount >= minEntryCount;

  static ProUtilityBoundaryModel build({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
    ProUtilityBranchConfig config = ProUtilityBranchConfig.defaults,
  }) {
    if (!shouldShowUtility(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return ProUtilityBoundaryModel.hidden.copyWith(
        reason: entryCount == 0
            ? 'Empty first-run — Pro utility hidden'
            : 'Pro utility gated — need meaningful proof or explicit utility ask',
      );
    }

    final exportLinkLive = config.exportSurfaceLive;
    final privateReportLive = config.privateReportLive;
    final previewOnly = !privateReportLive;

    return ProUtilityBoundaryModel(
      showHistory: hasMeaningfulProof || entryCount >= minEntryCount,
      showExport: true,
      showPrivateReportPreview: true,
      isPreviewOnly: previewOnly,
      shouldShowProBridge: shouldShowBridge(
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      ),
      reason: hasExplicitUtilityAsk(outcomesOverride: outcomesOverride)
          ? 'Explicit utility ask after caring about proof'
          : 'Meaningful proof with expansion gate met',
      exportLinkLive: exportLinkLive,
      privateReportLive: privateReportLive,
    );
  }

  static List<ProUtilityRow> utilityRows({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
    ProUtilityBranchConfig config = ProUtilityBranchConfig.defaults,
  }) {
    final model = build(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
      config: config,
    );
    if (!model.shouldShowSection) return const [];

    final rows = <ProUtilityRow>[];
    if (model.showHistory) {
      rows.add(
        const ProUtilityRow(
          title: ProUtilityCopyFix.historyTitle,
          body: ProUtilityCopyFix.historyBody,
        ),
      );
    }
    if (model.showExport) {
      rows.add(
        ProUtilityRow(
          title: ProUtilityCopyFix.exportTitle,
          body: model.exportLinkLive
              ? ProUtilityCopyFix.exportBody
              : ProUtilityCopyFix.exportPlannedBody,
          route: model.exportLinkLive ? exportRoute : null,
          previewOnly: !model.exportLinkLive,
        ),
      );
    }
    if (model.showPrivateReportPreview) {
      rows.add(
        ProUtilityRow(
          title: ProUtilityCopyFix.privateReportTitle,
          body: model.privateReportLive
              ? ProUtilityCopyFix.privateReportBody
              : '${ProUtilityCopyFix.privateReportBody} ${ProUtilityCopyFix.plannedSuffix}',
          previewOnly: !model.privateReportLive,
        ),
      );
    }
    return rows;
  }

  static String? bridgeTitle({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return ProUtilityCopyFix.headline;
  }

  static String? bridgeBody({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return '${ProUtilityCopyFix.proofBridge} ${ProUtilityCopyFix.notMoreAiLine}';
  }

  static List<String> firstProofBridgeLines({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return const [];
    }
    return [
      ProUtilityCopyFix.proofBridge,
      ProUtilityCopyFix.notMoreAiLine,
    ];
  }
}
