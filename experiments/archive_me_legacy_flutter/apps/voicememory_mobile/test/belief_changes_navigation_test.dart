import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/screens/belief_detail_screen.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

final _changeReceipt = ExplainableConclusion(
  id: 'change-receipt',
  statement: 'Your response may be becoming less immediate.',
  confidence: 80,
  reasoning: const [
    'The earlier and recent moments describe a different response.',
  ],
  uncertaintyNote: 'Two moments suggest change but do not prove a trend.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'then',
      quote: 'I answered immediately',
      startUtf16: 0,
      endUtf16: 22,
      role: TranscriptEvidenceRole.supporting,
      temporalRole: EvidenceTemporalRole.then,
      sourceCapturedAt: DateTime.utc(2026, 1),
      sourceType: EvidenceSourceType.voice,
      audioTimestampMs: 1200,
    ),
    TranscriptEvidenceCitation(
      entryId: 'now',
      quote: 'I waited before answering',
      startUtf16: 0,
      endUtf16: 25,
      role: TranscriptEvidenceRole.supporting,
      temporalRole: EvidenceTemporalRole.now,
      sourceCapturedAt: DateTime.utc(2026, 2),
      sourceType: EvidenceSourceType.text,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The situations may have been different.',
      rationale: 'Context could explain the different response.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 3),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  kind: ExplainableInsightKind.change,
);

const _changeTranscripts = {
  'then': 'I answered immediately',
  'now': 'I waited before answering',
};

void main() {
  testWidgets('BeliefChangesScreen renders as a tab without nested back UI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BeliefChangesScreen(
          previewReliableChange: _changeReceipt,
          previewTranscripts: _changeTranscripts,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Back'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text(ConsumerUiCopy.changesScreenTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.changesScreenLead), findsOneWidget);
  });

  testWidgets('/belief-changes route exposes the Changes tab content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/belief-changes',
      routes: [
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('patterns-home'))),
        ),
        GoRoute(
          path: '/belief-changes',
          builder: (context, state) => BeliefChangesScreen(
            previewReliableChange: _changeReceipt,
            previewTranscripts: _changeTranscripts,
          ),
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (context, state) =>
              Text('source-${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text(ConsumerUiCopy.changesScreenTitle), findsOneWidget);
    expect(find.text('See what changed'), findsOneWidget);
    expect(
      find.text(
        'Check the exact words and dates behind it. Correct anything ArchiveMe gets wrong.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 January 2026 — 1 February 2026'), findsOneWidget);
    expect(
      find.text('Then · 1 January 2026 · Voice · Audio 0:01'),
      findsOneWidget,
    );
    expect(find.text('Now · 1 February 2026 · Text'), findsOneWidget);
    expect(
      find.byKey(const Key('explainable_correction_controls')),
      findsOneWidget,
    );
    expect(find.text('Graph'), findsNothing);
    expect(find.text('Blind spots'), findsNothing);
    expect(find.text('Contradictions'), findsNothing);

    final sourceAction = find.byKey(const ValueKey('open_exact_moment_now_0'));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(sourceAction);
    await tester.pumpAndSettle();
    expect(find.text('source-now'), findsOneWidget);
  });

  testWidgets('history without a valid change stays honest and offers Record', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/belief-changes',
      routes: [
        GoRoute(
          path: '/belief-changes',
          builder: (_, _) => const BeliefChangesScreen(previewHasHistory: true),
        ),
        GoRoute(
          path: '/record',
          builder: (_, _) => const Text('record-destination'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(
      find.byKey(const Key('changes_insufficient_history')),
      findsOneWidget,
    );
    expect(
      find.text(
        'ArchiveMe needs more moments across time before it can show a reliable change.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('changes_record_another_moment')));
    await tester.pumpAndSettle();
    expect(find.text('record-destination'), findsOneWidget);
  });

  testWidgets('BeliefDetailScreen back pops to patterns home', (tester) async {
    final belief = ArchiveBeliefCardModel(
      id: 'belief-nav',
      statement: 'Work pressure keeps showing up before you agree.',
      confidencePercent: 72,
      evidenceSummary: 'Appeared in 3 reflections.',
      whyExplanation:
          'ArchiveMe noticed this topic repeating across months of reflections.',
      section: ArchiveBeliefSection.hiddenPattern,
    );

    final router = GoRouter(
      initialLocation: '/archive-belief',
      routes: [
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('patterns-home'))),
        ),
        GoRoute(
          path: '/belief-detail',
          builder: (context, state) => BeliefDetailScreen(
            belief: state.extra! as ArchiveBeliefCardModel,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();
    router.push('/belief-detail', extra: belief);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(belief.statement), findsOneWidget);
    await tester.tap(find.byKey(const Key('consumer_screen_back_header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('patterns-home'), findsOneWidget);
    expect(find.text(belief.statement), findsNothing);
  });
}
