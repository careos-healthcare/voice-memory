import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/insights/archive_insight.dart';
import 'package:voicememory_mobile/features/insights/insight_evidence.dart';
import 'package:voicememory_mobile/shared/ui/ai_explainability_card.dart';
import 'package:voicememory_mobile/widgets/archive/archive_insight_card.dart';

void main() {
  final explainability = AiExplainability(
    confidence: 68,
    evidence: [
      AiEvidenceSource(
        sourceId: 'entry-1',
        excerpt: 'I pause before replying.',
      ),
      AiEvidenceSource(sourceId: 'entry-2', excerpt: 'I wrote it down first.'),
    ],
    reasoning: [
      'The same sequence appears in two cited moments.',
      'Both moments place a pause before the eventual response.',
    ],
    alternativeExplanation:
        'The pauses may reflect one unusually demanding project.',
    uncertainty:
        'There are too few unrelated situations to infer a stable habit.',
  );

  testWidgets('keeps five pillars progressively disclosed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiExplainabilityCard(explainability: explainability),
        ),
      ),
    );

    expect(find.text('Why this conclusion?'), findsOneWidget);
    expect(find.text('68% Confidence'), findsOneWidget);
    expect(find.text('Reasoning'), findsNothing);
    expect(find.text('Alternative explanation'), findsNothing);

    await tester.tap(find.text('Why this conclusion?'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_explainability_confidence')), findsOne);
    expect(find.byKey(const Key('ai_explainability_evidence')), findsOne);
    expect(find.byKey(const Key('ai_explainability_reasoning')), findsOne);
    expect(find.byKey(const Key('ai_explainability_alternative')), findsOne);
    expect(find.byKey(const Key('ai_explainability_uncertainty')), findsOne);
    expect(find.text('“I pause before replying.”'), findsOneWidget);
  });

  testWidgets('supports large Dynamic Type without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          maxScaleFactor: 2,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AiExplainabilityCard(explainability: explainability),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Why this conclusion?'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Uncertainty'), findsOneWidget);
  });

  testWidgets('renders external truth badges without citation playback', (
    tester,
  ) async {
    final withExternalContext = AiExplainability(
      confidence: 72,
      evidence: explainability.evidence,
      reasoning: explainability.reasoning,
      alternativeExplanation: explainability.alternativeExplanation,
      uncertainty: explainability.uncertainty,
      externalSources: [
        ExternalExplainabilitySource(
          nodeId: 'health-sleep',
          source: ExternalSource.appleHealth,
          label: 'Sleep: 7.8h',
          observedAt: DateTime.utc(2026, 7, 27),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiExplainabilityCard(explainability: withExternalContext),
        ),
      ),
    );
    await tester.tap(find.text('Why this conclusion?'));
    await tester.pumpAndSettle();

    expect(
      find.text('Apple Health · Sleep: 7.8h · verified external source'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('external-evidence-health-sleep')),
      findsOneWidget,
    );
  });

  testWidgets('prediction insight surface includes progressive explanation', (
    tester,
  ) async {
    final insight = ArchiveInsight(
      id: 'prediction-1',
      type: ArchiveInsightType.prediction,
      title: 'What may happen next',
      summary: 'Stress has sometimes preceded avoiding a reply.',
      confidence: 65,
      evidenceCount: 1,
      supportingEvidence: [
        InsightEvidenceLine(
          entryId: 'entry-1',
          quote: 'I felt stressed and avoided replying.',
          recordedAt: DateTime.utc(2026),
          label: 'Moment',
        ),
      ],
      createdAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchiveInsightCard(insight: insight),
          ),
        ),
      ),
    );

    expect(find.byType(AiExplainabilityCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_explainability_expand')));
    await tester.pumpAndSettle();
    expect(find.text('Alternative explanation'), findsOneWidget);
    expect(find.text('Uncertainty'), findsOneWidget);
  });

  testWidgets('legacy mode shows a badge and unknown confidence safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiExplainabilityCard(
            explainability: AiExplainability.legacy(sourceId: 'legacy-1'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai_explainability_legacy_badge')),
      findsOneWidget,
    );
    expect(find.text('Legacy Synthesis'), findsOneWidget);
    expect(find.text('Confidence: Unknown'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_explainability_expand')));
    await tester.pumpAndSettle();
    expect(find.text('1. Derived from older vault patterns.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
