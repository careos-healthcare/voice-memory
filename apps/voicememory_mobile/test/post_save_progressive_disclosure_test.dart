import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';
import 'package:voicememory_mobile/widgets/record/post_save_conclusion_view.dart';

const _thenTranscript =
    'I kept checking the finished report again and again before I could send '
    'it to my manager, and the checking took most of the evening.';
const _nowTranscript =
    'I sent the finished report to my manager after one quick check, and the '
    'rest of the evening stayed free for the things I actually wanted to do.';

const _thenQuote =
    'I kept checking the finished report again and again before I could send it';
const _nowQuote =
    'I sent the finished report to my manager after one quick check, and the '
    'rest of the evening stayed free for the things I actually wanted to do.';

final Map<String, String> _transcripts = {
  'entry-then': _thenTranscript,
  'entry-now': _nowTranscript,
};

ExplainableConclusion _conclusion({
  ExplainableInsightKind kind = ExplainableInsightKind.change,
}) {
  final thenStart = _thenTranscript.indexOf(_thenQuote);
  final nowStart = _nowTranscript.indexOf(_nowQuote);
  return ExplainableConclusion(
    id: 'change-1',
    statement:
        'You sent the finished report after one check, where the same report '
        'once took repeated checking.',
    confidence: 80,
    reasoning: const [
      'The earlier saved words describe repeated checking of the report.',
      'The later saved words describe one check before sending the report.',
      'Both moments name the same report and the same evening routine.',
    ],
    uncertaintyNote:
        'Two moments cannot show whether the shorter checking holds over time.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-then',
        quote: _thenQuote,
        startUtf16: thenStart,
        endUtf16: thenStart + _thenQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 6, 1, 9),
        sourceType: EvidenceSourceType.voice,
        temporalRole: EvidenceTemporalRole.then,
        confidenceScore: 0.9,
      ),
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: _nowQuote,
        startUtf16: nowStart,
        endUtf16: nowStart + _nowQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
      ),
    ],
    alternatives: [
      const ExplainableAlternative(
        statement: 'The later report may simply have been a smaller one.',
        rationale:
            'Neither saved moment says how large or risky the report was.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
    kind: kind,
  );
}

ValidatedExplainableConclusion _validated({
  ExplainableInsightKind kind = ExplainableInsightKind.change,
}) {
  final gated = ExplainableConclusionRenderGate.visible(
    _conclusion(kind: kind),
    canonicalTranscripts: _transcripts,
  );
  expect(gated, isNotNull, reason: 'fixture must survive the render gate');
  return gated!;
}

Future<void> _pumpCompact(
  WidgetTester tester, {
  ExplainableInsightKind kind = ExplainableInsightKind.change,
  Size size = const Size(390, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CompactAuditableConclusionCard(
            conclusion: _validated(kind: kind),
            nextQuestion: 'What happened the next time a report was finished?',
            onRecordNext: (_) {},
            onEvidenceSelected: (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact result shows only the reduced conclusion elements', (
    tester,
  ) async {
    await _pumpCompact(tester);

    expect(find.byKey(const Key('post_save_conclusion_label')), findsOneWidget);
    expect(find.text('Possible change'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_conclusion_statement')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('post_save_strongest_quote')), findsOneWidget);
    expect(find.text('31 July 2026'), findsOneWidget);
    expect(
      find.text('Based on 2 saved moments · Repeated across several moments'),
      findsOneWidget,
    );
    for (final control in ['Accurate', 'Wrong angle', 'Too generic', 'Hide']) {
      expect(find.text(control), findsOneWidget);
    }
    expect(find.text('Check all evidence'), findsOneWidget);

    // Exactly one action, and no competing secondary surfaces.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    for (final withheld in [
      _thenQuote,
      'Alternative explanation',
      'Method',
      'Uncertainty',
      'Open exact moment',
      'Chronology',
      'Record another moment',
      'Upgrade',
      'Pro',
      'Streak',
      'Set a reminder',
      'Memory graph',
    ]) {
      expect(
        find.textContaining(withheld),
        findsNothing,
        reason: '"$withheld" must not appear on the compact result',
      );
    }
  });

  testWidgets('compact result never renders a confidence percentage', (
    tester,
  ) async {
    await _pumpCompact(tester);

    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('80'), findsNothing);
    expect(
      find.textContaining('Repeated across several moments'),
      findsOneWidget,
    );
  });

  testWidgets('long evidence wraps instead of overflowing or truncating', (
    tester,
  ) async {
    await _pumpCompact(tester);

    final quote = tester.widget<Text>(
      find.byKey(const Key('post_save_strongest_quote')),
    );
    expect(quote.data, '“$_nowQuote”');
    expect(quote.data, isNot(contains('…')));
    expect(quote.overflow ?? TextOverflow.clip, isNot(TextOverflow.ellipsis));
    expect(quote.maxLines, isNull);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('post_save_strongest_quote')),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    // Taller than a single line means the quote wrapped rather than clipped.
    final singleLineHeight = paragraph.getMaxIntrinsicHeight(double.infinity);
    expect(paragraph.size.height, greaterThan(singleLineHeight * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact reading order stays label, sentence, quote, date', (
    tester,
  ) async {
    await _pumpCompact(tester);

    double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
    expect(
      top(const Key('post_save_conclusion_label')),
      lessThan(top(const Key('post_save_conclusion_statement'))),
    );
    expect(
      top(const Key('post_save_conclusion_statement')),
      lessThan(top(const Key('post_save_strongest_quote'))),
    );
    expect(
      top(const Key('post_save_strongest_quote')),
      lessThan(top(const Key('post_save_evidence_date'))),
    );
    expect(
      top(const Key('post_save_evidence_date')),
      lessThan(top(const Key('post_save_evidence_count'))),
    );
    expect(
      top(const Key('post_save_evidence_count')),
      lessThan(top(const Key('post_save_feedback_controls'))),
    );
    expect(
      top(const Key('post_save_feedback_controls')),
      lessThan(top(const Key('post_save_check_all_evidence'))),
    );

    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byKey(const Key('post_save_evidence_count')))
          .label,
      'Based on 2 saved moments. Repeated across several moments.',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('post_save_conclusion_statement')))
          .label,
      startsWith('Possible change. You sent'),
    );
    handle.dispose();
  });

  testWidgets('pattern conclusions are labelled Possible repeat', (
    tester,
  ) async {
    await _pumpCompact(tester, kind: ExplainableInsightKind.pattern);

    expect(find.text('Possible repeat'), findsOneWidget);
  });

  testWidgets('Check all evidence opens the full detail', (tester) async {
    await _pumpCompact(tester, size: const Size(390, 2200));

    await tester.tap(find.byKey(const Key('post_save_check_all_evidence')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('post_save_evidence_detail_sheet')),
      findsOneWidget,
    );
    expect(find.text('All evidence'), findsOneWidget);
    expect(find.textContaining(_thenQuote), findsWidgets);
    expect(find.text('Chronology'), findsOneWidget);
    expect(find.text('Alternative explanation'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_detail_alternative_statement')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('post_save_detail_alternative_rationale')),
      findsOneWidget,
    );
    expect(find.text('Method'), findsOneWidget);
    expect(
      find.text(
        'Both moments name the same report and the same evening routine.',
      ),
      findsOneWidget,
    );
    expect(find.text('Uncertainty'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_detail_uncertainty_note')),
      findsOneWidget,
    );
    expect(find.text('Open exact moment'), findsNWidgets(2));
    expect(
      find.byKey(const Key('post_save_detail_record_next')),
      findsOneWidget,
    );
  });

  testWidgets('Hide removes the single conclusion', (tester) async {
    await _pumpCompact(tester);

    await tester.tap(find.byKey(const Key('post_save_feedback_hide')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_save_compact_conclusion')), findsNothing);
  });

  testWidgets('compact post-save layout golden', (tester) async {
    await _pumpCompact(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/post_save_compact.png'),
    );
  });

  testWidgets('expanded post-save detail golden', (tester) async {
    await _pumpCompact(tester, size: const Size(390, 2200));
    await tester.tap(find.byKey(const Key('post_save_check_all_evidence')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/post_save_expanded.png'),
    );
  });

  test('the strongest evidence drives the compact quote and date', () {
    final view = PostSaveConclusionView.of(_validated());

    expect(view.label, 'Possible change');
    expect(view.strongestQuote, _nowQuote);
    expect(view.strongestDate, '31 July 2026');
    expect(view.evidenceCount, 2);
    expect(view.confidenceBandLabel, 'Repeated across several moments');
    expect(view.additionalEvidence.single.quote, _thenQuote);
    expect(view.chronology.map((citation) => citation.entryId), [
      'entry-then',
      'entry-now',
    ]);
  });
}
