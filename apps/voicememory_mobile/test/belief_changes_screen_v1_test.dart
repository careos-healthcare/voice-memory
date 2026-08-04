import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';

void main() {
  const thenText = 'My work response felt uncertain after the meeting.';
  const nowText =
      'My work response felt more certain after the meeting this time.';
  final thenAt = DateTime(2026, 7, 1, 10);
  final nowAt = DateTime(2026, 7, 8, 10);

  Future<void> pumpChanges(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observation = _conclusion(
      id: 'observation',
      kind: ExplainableInsightKind.observation,
      statement: 'You described an uncertain work response.',
      evidence: [_citation('then', thenText, thenAt)],
      generatedAt: thenAt.add(const Duration(minutes: 1)),
    );
    final change = _conclusion(
      id: 'change',
      kind: ExplainableInsightKind.change,
      statement:
          'Your work response wording shifted from uncertain to more certain.',
      evidence: [
        _citation(
          'then',
          thenText,
          thenAt,
          temporalRole: EvidenceTemporalRole.then,
        ),
        _citation(
          'now',
          nowText,
          nowAt,
          temporalRole: EvidenceTemporalRole.now,
        ),
      ],
      generatedAt: nowAt.add(const Duration(minutes: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BeliefChangesScreen(
          previewConclusions: [change, observation],
          previewTranscripts: const {'then': thenText, 'now': nowText},
          previewHasHistory: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Changes defaults to one compact row per thread', (tester) async {
    await pumpChanges(tester);

    expect(find.text('Changes'), findsOneWidget);
    // Asserted against the constant, not a copy of it. This test is about the
    // screen rendering the canonical lead, not about the wording, which the
    // copy guards own.
    expect(find.text(ConsumerUiCopy.changesScreenLead), findsOneWidget);
    expect(find.textContaining('1 possible change'), findsOneWidget);

    // Both findings share one subject, so they read as one continuing thread
    // rather than two unrelated cards.
    expect(find.byType(ChangeThreadSummaryCard), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('The signal appears stronger.'), findsOneWidget);
    expect(find.textContaining('2 saved moments'), findsOneWidget);
    expect(find.textContaining('1 July 2026 — 8 July 2026'), findsOneWidget);
    expect(find.text('“$nowText”'), findsOneWidget);

    // The compact row stays compact: no quotes-and-reasoning wall by default.
    expect(find.text('Open exact moment'), findsNothing);
    expect(find.textContaining('Then ·'), findsNothing);
    for (final forbidden in ['Graph', 'Analyst', 'Blind spot', 'Life OS']) {
      expect(find.textContaining(forbidden), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a thread shows its chronological evidence', (
    tester,
  ) async {
    await pumpChanges(tester);
    await tester.tap(find.byType(ChangeThreadSummaryCard));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeThreadDetailScreen), findsOneWidget);
    expect(find.text('First noticed'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('The signal appears stronger.'), findsNWidgets(2));
    expect(find.textContaining('Then · 1 July 2026'), findsOneWidget);
    expect(find.textContaining('Now · 8 July 2026'), findsOneWidget);
    expect(find.text('“$thenText”'), findsNWidgets(2));
    expect(find.text('“$nowText”'), findsOneWidget);
    expect(find.text('Open exact moment'), findsNWidgets(3));
    expect(find.textContaining('What moved:'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('First noticed')).dy,
      lessThan(tester.getTopLeft(find.text('Changed')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

ExplainableConclusion _conclusion({
  required String id,
  required ExplainableInsightKind kind,
  required String statement,
  required List<TranscriptEvidenceCitation> evidence,
  required DateTime generatedAt,
}) => ExplainableConclusion(
  id: id,
  statement: statement,
  confidence: kind == ExplainableInsightKind.observation ? 60 : 75,
  reasoning: const ['The exact saved wording supports this cautious read.'],
  uncertaintyNote: 'More moments may support or challenge this interpretation.',
  evidence: evidence,
  alternatives: const [
    ExplainableAlternative(
      statement: 'The difference may be specific to these moments.',
      rationale: 'Two moments cannot establish a lasting change on their own.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: generatedAt,
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  kind: kind,
);

TranscriptEvidenceCitation _citation(
  String entryId,
  String quote,
  DateTime capturedAt, {
  EvidenceTemporalRole temporalRole = EvidenceTemporalRole.single,
}) => TranscriptEvidenceCitation(
  entryId: entryId,
  quote: quote,
  startUtf16: 0,
  endUtf16: quote.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: capturedAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
  confidenceScore: 0.82,
);
