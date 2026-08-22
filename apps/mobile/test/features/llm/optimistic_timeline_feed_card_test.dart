import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/presentation/optimistic_timeline_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows shimmer while pending analysis', (tester) async {
    const state = LlmFeedCardState(
      captureId: 'capture-1',
      createdAt: DateTime.utc(2026, 1, 1, 12),
      status: LlmAnalysisStatus.pendingAnalysis,
      rawTranscript: 'Raw voice note about boundaries.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OptimisticTimelineFeedCard(state: state),
        ),
      ),
    );

    expect(find.byKey(const Key('llm_feed_shimmer')), findsOneWidget);
    expect(find.text('Raw voice note about boundaries.'), findsOneWidget);
  });

  testWidgets('shows extracted nodes when completed', (tester) async {
    const state = LlmFeedCardState(
      captureId: 'capture-2',
      createdAt: DateTime.utc(2026, 1, 2, 9),
      status: LlmAnalysisStatus.completed,
      rawTranscript: 'Raw transcript',
      summary: 'Pause before agreeing to extra work.',
      nodes: [
        LlmFeedGraphNode(id: 'n1', kind: 'theme', label: 'boundaries'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OptimisticTimelineFeedCard(state: state),
        ),
      ),
    );

    expect(find.byKey(const Key('llm_feed_shimmer')), findsNothing);
    expect(find.text('Pause before agreeing to extra work.'), findsOneWidget);
    expect(find.text('boundaries'), findsOneWidget);
  });
}
