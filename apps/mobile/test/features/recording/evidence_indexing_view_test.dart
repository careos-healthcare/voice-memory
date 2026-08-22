import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_controller.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_models.dart';
import 'package:archiveme_mobile/features/recording/views/evidence_indexing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EvidenceIndexingView renders live feed chips', (tester) async {
    final controller = EvidenceIndexingController();
    addTearDown(controller.dispose);

    controller.phase = EvidenceIndexingPhase.extracting;
    controller.visibleChips.add(
      const EvidenceIndexingChip(
        category: 'Belief Detected',
        label: 'Tension',
        value: 'Work stress spikes on Sundays',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceIndexingView(controller: controller),
        ),
      ),
    );

    expect(find.byKey(const Key('evidence_indexing_view')), findsOneWidget);
    expect(find.textContaining('Work stress spikes on Sundays'), findsOneWidget);
  });
}