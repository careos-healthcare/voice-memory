import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grief loss lens exposes cyclical listen targets', () {
    expect(GriefLossLens.listenTargets.length, 4);
    expect(GriefLossLens.systemPromptInjection, contains('cyclical patterns'));
    expect(
      GriefLossLens.systemPromptInjection,
      contains('non-linear emotional movement'),
    );
  });

  test('comparison addendum forbids progress and healing pressure', () {
    expect(
      GriefLossLens.comparisonSystemPromptAddendum,
      contains('do not imply progress'),
    );
    expect(
      GriefLossLens.comparisonSystemPromptAddendum,
      contains('Sunday evenings'),
    );
    expect(GriefLossLens.recommendedComparisonWindows, [
      ComparisonTemporalWindow.fortnight,
      ComparisonTemporalWindow.recent,
    ]);
  });

  test('matches grief loss lens only', () {
    expect(GriefLossLens.matches(LifeStageLens.griefLoss), isTrue);
    expect(GriefLossLens.matches(LifeStageLens.newParent), isFalse);
  });
}