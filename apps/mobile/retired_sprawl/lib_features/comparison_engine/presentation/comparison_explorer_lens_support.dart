import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';

/// Lens-specific defaults and prompt addenda for the comparison explorer.
abstract final class ComparisonExplorerLensSupport {
  ComparisonExplorerLensSupport._();

  static bool usesTemporalComparisonLens(LifeStageLens? lens) =>
      NewParentLens.matches(lens) || GriefLossLens.matches(lens);

  static ComparisonTemporalWindow defaultWindowFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.defaultComparisonWindow;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.defaultComparisonWindow;
    }
    return ComparisonTemporalWindow.recent;
  }

  static String? headlineFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.comparisonExplorerHeadline;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.comparisonExplorerHeadline;
    }
    return null;
  }

  static String? intervalNudgeFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.comparisonIntervalNudge;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.comparisonIntervalNudge;
    }
    return null;
  }

  static String? systemPromptAddendumFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.comparisonSystemPromptAddendum;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.comparisonSystemPromptAddendum;
    }
    return null;
  }

  static List<ComparisonTemporalWindow> recommendedWindowsFor(
    LifeStageLens? lens,
  ) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.recommendedComparisonWindows;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.recommendedComparisonWindows;
    }
    return ComparisonTemporalWindow.values;
  }

  static bool isRecommendedWindow(LifeStageLens? lens, ComparisonTemporalWindow window) {
    return recommendedWindowsFor(lens).contains(window);
  }

  static String? beliefChangesEntryTitleFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.beliefChangesEntryTitle;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.beliefChangesEntryTitle;
    }
    return null;
  }

  static String? beliefChangesEntryBodyFor(LifeStageLens? lens) {
    if (NewParentLens.matches(lens)) {
      return NewParentLens.beliefChangesEntryBody;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.beliefChangesEntryBody;
    }
    return null;
  }

  static String beliefChangesFortnightCtaFor(LifeStageLens? lens) {
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.beliefChangesFortnightCta;
    }
    return NewParentLens.beliefChangesFortnightCta;
  }

  static String beliefChangesMonthCtaFor(LifeStageLens? lens) {
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.beliefChangesMonthCta;
    }
    return NewParentLens.beliefChangesMonthCta;
  }

  static String routeForWindow(ComparisonTemporalWindow window) =>
      '/comparison-explorer?window=${window.name}';
}