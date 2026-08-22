import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/belief_changes_temporal_comparison_entry.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeliefChangesTemporalComparisonEntry', () {
    Future<void> pumpWithLens(WidgetTester tester, LifeStageLens lens) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BeliefChangesTemporalComparisonEntry(activeLens: lens),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('new parent lens shows dedicated interval entry card', (
      tester,
    ) async {
      await pumpWithLens(tester, LifeStageLens.newParent);

      expect(find.text(NewParentLens.beliefChangesEntryTitle), findsOneWidget);
      expect(find.text(NewParentLens.beliefChangesFortnightCta), findsOneWidget);
      expect(find.text(NewParentLens.beliefChangesMonthCta), findsOneWidget);
    });

    testWidgets('grief loss lens shows dedicated interval entry card', (
      tester,
    ) async {
      await pumpWithLens(tester, LifeStageLens.griefLoss);

      expect(find.text(GriefLossLens.beliefChangesEntryTitle), findsOneWidget);
      expect(find.text(GriefLossLens.beliefChangesFortnightCta), findsOneWidget);
      expect(find.text(GriefLossLens.beliefChangesMonthCta), findsOneWidget);
    });

    testWidgets('default lens hides dedicated interval entry card', (
      tester,
    ) async {
      await pumpWithLens(tester, LifeStageLens.defaultLens);

      expect(find.byType(Card), findsNothing);
      expect(find.text(NewParentLens.beliefChangesEntryTitle), findsNothing);
      expect(find.text(GriefLossLens.beliefChangesEntryTitle), findsNothing);
    });
  });
}