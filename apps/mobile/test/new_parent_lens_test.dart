import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new parent lens exposes capacity and identity listen targets', () {
    expect(NewParentLens.listenTargets.length, 4);
    expect(NewParentLens.systemPromptInjection, contains('patience'));
    expect(
      NewParentLens.systemPromptInjection,
      contains('pre-transition vs post-transition'),
    );
  });

  test('comparison addendum targets 2-week and 1-month intervals', () {
    expect(
      NewParentLens.comparisonSystemPromptAddendum,
      contains('2-week and 1-month'),
    );
    expect(NewParentLens.recommendedComparisonWindows, [
      ComparisonTemporalWindow.fortnight,
      ComparisonTemporalWindow.recent,
    ]);
    expect(NewParentLens.defaultComparisonWindow,
        ComparisonTemporalWindow.fortnight);
  });

  test('matches new parent lens only', () {
    expect(NewParentLens.matches(LifeStageLens.newParent), isTrue);
    expect(NewParentLens.matches(LifeStageLens.griefLoss), isFalse);
  });
}