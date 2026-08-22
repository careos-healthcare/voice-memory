import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_insight_feed_card.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/insight_evidence_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InsightEvidenceDetailSheet', () {
    Future<void> pumpDetailSheet(
      WidgetTester tester, {
      required List<InlineEvidenceQuote> quotes,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => InsightEvidenceDetailSheet.show(
                      context,
                      payload: InsightEvidenceDetailPayload(
                        insightText: 'You often push through exhaustion at work',
                        confidenceBand: PatternMatchConfidenceBand.solid,
                        quotes: quotes,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('single-entry case shows Single mention band and one source', (
      tester,
    ) async {
      await pumpDetailSheet(
        tester,
        quotes: [
          InlineEvidenceQuote(
            entryId: 'entry-1',
            recordedAt: DateTime.utc(2026, 8, 10, 9),
            verbatimText: '"I keep saying yes even when exhausted"',
          ),
        ],
      );

      expect(find.byKey(const Key('insight_evidence_detail_sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('insight_evidence_confidence_band_Single mention')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('insight_evidence_source_entry-1')), findsOneWidget);
      expect(find.text('Open journal entry'), findsOneWidget);
    });

    testWidgets('multi-entry case lists sources chronologically', (
      tester,
    ) async {
      await pumpDetailSheet(
        tester,
        quotes: [
          InlineEvidenceQuote(
            entryId: 'entry-newer',
            recordedAt: DateTime.utc(2026, 8, 12, 9),
            verbatimText: '"Still exhausted on Friday"',
          ),
          InlineEvidenceQuote(
            entryId: 'entry-older',
            recordedAt: DateTime.utc(2026, 8, 8, 9),
            verbatimText: '"Said yes again at work"',
          ),
        ],
      );

      expect(
        find.byKey(const Key('insight_evidence_confidence_band_Strong pattern')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('insight_evidence_source_entry-older')), findsOneWidget);
      expect(find.byKey(const Key('insight_evidence_source_entry-newer')), findsOneWidget);

      final older = tester.getTopLeft(
        find.byKey(const Key('insight_evidence_source_entry-older')),
      );
      final newer = tester.getTopLeft(
        find.byKey(const Key('insight_evidence_source_entry-newer')),
      );
      expect(older.dy, lessThan(newer.dy));
    });
  });

  group('ArchiveInsightFeedCard show evidence affordance', () {
    testWidgets('Show evidence opens detail sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveInsightFeedCard(
              insightText: 'Pattern about exhaustion',
              confidenceBand: PatternMatchConfidenceBand.emerging,
              quotes: [
                InlineEvidenceQuote(
                  entryId: 'e1',
                  recordedAt: DateTime.utc(2026, 8, 1),
                  verbatimText: '"Tired again"',
                ),
                InlineEvidenceQuote(
                  entryId: 'e2',
                  recordedAt: DateTime.utc(2026, 8, 2),
                  verbatimText: '"Still tired"',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('show_evidence_affordance')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insight_evidence_detail_sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('insight_evidence_confidence_band_Possible pattern')),
        findsOneWidget,
      );
    });
  });
}
