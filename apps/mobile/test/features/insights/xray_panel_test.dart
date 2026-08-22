import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/features/insights/widgets/xray_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('XRayPanel renders confidence breakdown and retrieved chunks', (
    tester,
  ) async {
    const inspection = TheoryRankingInspection(
      confidenceBreakdown: TheoryConfidenceBreakdown(
        volumePoints: 20,
        consistencyPoints: 15,
        recencyPoints: 10,
        contradictionPenalty: 3,
        counterPenalty: 4,
        lowEvidenceMultiplierApplied: false,
        staleMultiplierApplied: false,
        rawTotalBeforeModifiers: 38,
        finalPercent: 38,
      ),
      rankBreakdown: TheoryRankBreakdown(
        volumePoints: 12,
        consistencyPoints: 8,
        recencyPoints: 6,
        contradictionPoints: 0,
        surprisePoints: 0,
        counterQualityPoints: 6,
        finalScore: 32,
      ),
      retrievedChunks: [
        TheoryRetrievalChunk(
          entryId: 'entry-1',
          excerpt: 'Partner conflict keeps showing up at home.',
          role: TheoryRetrievalRole.supporting,
          keywordOverlap: 3,
          vectorSimilarity: 0.812,
        ),
      ],
      finalConfidencePercent: 38,
      finalRankScore: 32,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 900,
            child: XRayPanel(
              inspection: inspection,
              theoryStatement: 'Partner conflict at home',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('xray_panel')), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
    expect(find.text('Counter-evidence penalty'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('xray_chunk_entry-1')), findsOneWidget);
    expect(find.textContaining('Vector sim: 0.812'), findsOneWidget);
  });
}
