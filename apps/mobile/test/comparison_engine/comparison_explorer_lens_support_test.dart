import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/comparison_explorer_lens_support.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temporal comparison lenses default to fortnight window', () {
    expect(
      ComparisonExplorerLensSupport.defaultWindowFor(LifeStageLens.newParent),
      ComparisonTemporalWindow.fortnight,
    );
    expect(
      ComparisonExplorerLensSupport.defaultWindowFor(LifeStageLens.griefLoss),
      ComparisonTemporalWindow.fortnight,
    );
    expect(
      ComparisonExplorerLensSupport.defaultWindowFor(
        LifeStageLens.careerTransition,
      ),
      ComparisonTemporalWindow.recent,
    );
  });

  test('lens support exposes comparison system prompt addenda', () {
    expect(
      ComparisonExplorerLensSupport.systemPromptAddendumFor(
        LifeStageLens.newParent,
      ),
      NewParentLens.comparisonSystemPromptAddendum,
    );
    expect(
      ComparisonExplorerLensSupport.systemPromptAddendumFor(
        LifeStageLens.griefLoss,
      ),
      GriefLossLens.comparisonSystemPromptAddendum,
    );
    expect(
      ComparisonExplorerLensSupport.systemPromptAddendumFor(
        LifeStageLens.defaultLens,
      ),
      isNull,
    );
  });

  test('recommended windows highlight fortnight and month for lens users', () {
    expect(
      ComparisonExplorerLensSupport.isRecommendedWindow(
        LifeStageLens.newParent,
        ComparisonTemporalWindow.fortnight,
      ),
      isTrue,
    );
    expect(
      ComparisonExplorerLensSupport.isRecommendedWindow(
        LifeStageLens.griefLoss,
        ComparisonTemporalWindow.recent,
      ),
      isTrue,
    );
    expect(
      ComparisonExplorerLensSupport.isRecommendedWindow(
        LifeStageLens.newParent,
        ComparisonTemporalWindow.quarter,
      ),
      isFalse,
    );
  });
}