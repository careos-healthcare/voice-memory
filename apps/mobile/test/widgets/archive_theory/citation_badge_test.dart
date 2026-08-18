import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/citation_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CitationBadge renders timestamp and invokes callback', (tester) async {
    TheoryEvidenceQuote? tapped;
    const quote = TheoryEvidenceQuote(
      entryId: 'entry-1',
      dateLabel: 'Jan 2',
      quote: 'Partner and I keep arguing.',
      audioId: 'entry-1',
      startTimestampMs: 42000,
      endTimestampMs: 48000,
      chunkId: 'entry-1:42000',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitationBadge(
            quote: quote,
            onTap: (value) => tapped = value,
          ),
        ),
      ),
    );

    expect(find.text('0:42'), findsOneWidget);
    await tester.tap(find.byType(CitationBadge));
    await tester.pump();
    expect(tapped, quote);
  });

  testWidgets('CitationBadge hides when citation metadata is incomplete', (tester) async {
    const quote = TheoryEvidenceQuote(
      entryId: 'entry-1',
      dateLabel: 'Jan 2',
      quote: 'No audio anchor yet.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CitationBadge(
            quote: quote,
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(CitationBadge), findsOneWidget);
    expect(find.text('0:42'), findsNothing);
    expect(tester.widget<CitationBadge>(find.byType(CitationBadge)).quote.hasCitationPlayback, isFalse);
  });
}

void _noop(TheoryEvidenceQuote _) {}
