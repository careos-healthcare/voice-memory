import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainability_history_store.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_widgets.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';

void main() {
  const transcript = 'Exact quoted evidence.';
  const transcripts = {'entry': transcript};

  ExplainableConclusion conclusion({String quote = 'Exact'}) =>
      ExplainableConclusion(
        id: 'stable-id',
        statement: quote == 'Exact'
            ? 'Exact visible statement'
            : 'Invalid statement',
        confidence: 60,
        reasoning: const [
          'The exact cited wording supports the visible statement.',
        ],
        uncertaintyNote: 'There may be another explanation.',
        evidence: [
          TranscriptEvidenceCitation(
            entryId: 'entry',
            quote: quote,
            startUtf16: 0,
            endUtf16: 5,
            role: TranscriptEvidenceRole.supporting,
            sourceCapturedAt: DateTime.utc(2025, 12, 31),
            sourceType: EvidenceSourceType.text,
          ),
        ],
        alternatives: const [
          ExplainableAlternative(
            statement: 'Alternative statement',
            rationale: 'Alternative rationale',
            confidence: 40,
          ),
        ],
        provenance: ExplainableConclusionProvenance(
          source: 'widget_test',
          generatedAt: DateTime.utc(2026),
          schemaVersion: ExplainableConclusion.schemaVersion,
        ),
      );

  testWidgets('card renders exact evidence and one inline alternative', (
    tester,
  ) async {
    final gated = ExplainableConclusionRenderGate.visible(
      conclusion(),
      canonicalTranscripts: transcripts,
    )!;
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplainableConclusionCard(
            conclusion: gated,
            onEvidenceSelected: (_, _) => selected = true,
          ),
        ),
      ),
    );

    expect(find.text('Exact visible statement'), findsOneWidget);
    expect(find.text('“Exact”'), findsOneWidget);
    await tester.tap(find.text('Open exact moment'));
    expect(selected, isTrue);
    expect(find.byKey(const Key('receipt_open_memory_graph')), findsNothing);
    expect(
      find.byKey(const Key('explainable_alternatives_button')),
      findsNothing,
    );
    expect(find.text('Alternative statement'), findsOneWidget);
  });

  testWidgets('validating card hides invalid observations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ValidatingExplainableConclusionCard(
              conclusion: conclusion(quote: 'Wrong'),
              canonicalTranscripts: transcripts,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Invalid statement'), findsNothing);
    expect(find.byType(ExplainableConclusionCard), findsNothing);
  });

  testWidgets(
    'correction controls collect a private wrong-angle note and can hide',
    (tester) async {
      final gated = ExplainableConclusionRenderGate.visible(
        conclusion(),
        canonicalTranscripts: transcripts,
      )!;
      InsightFeedbackChoice? choice;
      String? correction;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ExplainableConclusionCard(
                  conclusion: gated,
                  onEvidenceSelected: (_, _) {},
                  onFeedbackSubmitted: (value, note) {
                    choice = value;
                    correction = note;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('explainable_correction_controls')),
        findsOneWidget,
      );
      expect(find.text('Accurate'), findsOneWidget);
      expect(find.text('Wrong angle'), findsOneWidget);
      expect(find.text('Too generic'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Wrong angle'));
      await tester.tap(find.text('Wrong angle'));
      await tester.pumpAndSettle();
      expect(find.text('What did ArchiveMe misunderstand?'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('explainable_correction_input')),
        'The deadline mattered more than the workload.',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();
      expect(choice, InsightFeedbackChoice.wrongAngle);
      expect(correction, 'The deadline mattered more than the workload.');
      expect(gated.value.evidence.single.quote, 'Exact');

      expect(
        find.byKey(const Key('explainable_conclusion_card')),
        findsNothing,
      );
    },
  );

  testWidgets('validating card fails legacy conclusions to honest fallback', (
    tester,
  ) async {
    final legacy = conclusion().copyWith(isLegacy: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValidatingExplainableConclusionCard(
            conclusion: legacy,
            canonicalTranscripts: const {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('evidence_receipt_unavailable')),
      findsOneWidget,
    );
    expect(find.text('A legacy cached observation.'), findsNothing);
  });

  testWidgets('history sheet renders only gated versions', (tester) async {
    final now = DateTime.utc(2026);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplainableHistorySheet(
            entries: [
              ExplainabilityHistoryEntry(
                conclusion: conclusion(),
                appendedAt: now,
              ),
              ExplainabilityHistoryEntry(
                conclusion: conclusion(quote: 'Wrong'),
                appendedAt: now,
              ),
            ],
            canonicalTranscripts: transcripts,
          ),
        ),
      ),
    );

    expect(find.text('Exact visible statement'), findsOneWidget);
    expect(find.text('Invalid statement'), findsNothing);
  });

  testWidgets(
    'custom actions open evidence and history and expose history state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final gated = ExplainableConclusionRenderGate.visible(
        conclusion(),
        canonicalTranscripts: transcripts,
      )!;
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ExplainableConclusionCard(
                conclusion: gated,
                onEvidenceSelected: (_, _) => selected = true,
                onShowHistory: () => ExplainableHistorySheet.show(
                  context,
                  entries: [
                    ExplainabilityHistoryEntry(
                      conclusion: conclusion(),
                      appendedAt: DateTime.utc(2026),
                    ),
                  ],
                  canonicalTranscripts: transcripts,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      _performCustomAction(
        tester,
        _semanticsNode(
          tester,
          'Supporting moment. Exact. Captured 31 December 2025. Text source.',
        )!,
        'Open exact moment',
      );
      await tester.pump();
      expect(selected, isTrue);

      _performCustomAction(
        tester,
        _semanticsNode(tester, 'Evidence-backed insight')!,
        'View conclusion history',
      );
      await tester.pumpAndSettle();
      final version = _semanticsNode(
        tester,
        'Version 1, Exact visible statement, Some supporting evidence',
      )!;
      expect(
        version.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      _performCustomAction(tester, version, 'Expand version 1');
      await tester.pump();
      final expanded = _semanticsNode(
        tester,
        'Version 1, Exact visible statement, Some supporting evidence',
      )!;
      expect(
        expanded.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isTrue,
      );
      _performCustomAction(tester, expanded, 'Collapse version 1');
      await tester.pump();
      expect(
        _semanticsNode(
          tester,
          'Version 1, Exact visible statement, Some supporting evidence',
        )!.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      Navigator.of(
        tester.element(find.byKey(const Key('explainable_history_sheet'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        Focus.of(
          tester.element(find.byKey(const Key('explainable_history_button'))),
        ).hasFocus,
        isTrue,
      );
      semantics.dispose();
    },
  );
}

SemanticsNode? _semanticsNode(WidgetTester tester, String label) {
  SemanticsNode? result;
  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) {
      result = node;
      return false;
    }
    node.visitChildren(visit);
    return result == null;
  }

  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return result;
}

void _performCustomAction(
  WidgetTester tester,
  SemanticsNode node,
  String label,
) {
  final action = CustomSemanticsAction(label: label);
  final actionId = CustomSemanticsAction.getIdentifier(action);
  expect(node.getSemanticsData().customSemanticsActionIds, contains(actionId));
  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.customAction,
    actionId,
  );
}
