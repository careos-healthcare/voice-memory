import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_insight_feed_card.dart';
import 'package:archiveme_mobile/widgets/archive_v1/evidence_keyword_highlighter.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceKeywordHighlighter', () {
    test('highlights matching terms in quotes', () {
      final span = EvidenceKeywordHighlighter.buildHighlightedSpan(
        quote: '"I keep saying yes at work even when exhausted"',
        highlightTerms: const ['exhausted', 'saying'],
        baseStyle: const TextStyle(color: Colors.black),
        highlightStyle: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      );

      expect(span.children, isNotNull);
      expect(span.children!.length, greaterThan(1));
    });
  });

  group('ArchiveInsightFeedCard', () {
    testWidgets('shows badge, evidence pill, and expands inline drawer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveInsightFeedCard(
                insightText: 'You often push through exhaustion at work',
                confidenceBand: PatternMatchConfidenceBand.solid,
                quotes: [
                  InlineEvidenceQuote(
                    entryId: 'entry-1',
                    recordedAt: DateTime.utc(2026, 8, 10, 9),
                    verbatimText: '"I keep saying yes even when exhausted"',
                  ),
                ],
                onAgree: () {},
                onDisagree: () {},
                onCorrect: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pattern_match_confidence_badge_solid')), findsOneWidget);
      expect(find.byKey(const Key('evidence_pill')), findsOneWidget);
      expect(find.textContaining('Backed by 1 verbatim entry'), findsOneWidget);
      expect(find.byKey(const Key('inline_evidence_drawer')), findsNothing);

      await tester.tap(find.byKey(const Key('evidence_pill')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_evidence_drawer')), findsOneWidget);
      expect(find.byKey(const Key('insight_evidence_feedback_bar')), findsOneWidget);
      expect(find.textContaining('verbatim'), findsOneWidget);
    });
  });
}