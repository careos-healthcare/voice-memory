import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_markers.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';

import 'support/accessibility_matrix.dart';

/// The evidence card is the reading and its receipt. Collapsed it must be
/// readable at a glance and correctable in place; expanded it must show
/// everything the reading rests on. Neither state may claim precision the
/// evidence does not have.
void main() {
  group('collapsed after save', () {
    testWidgets(
      'it shows the reading, one quote, the full date and the count',
      (tester) async {
        await _pump(tester);

        expect(find.text('Possible change'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('post_save_conclusion_statement')),
              )
              .data,
          _statement,
        );
        expect(find.text('“$_nowQuote”'), findsOneWidget);
        expect(find.text('Text · 31 July 2026'), findsOneWidget);
        expect(
          find.text(
            'Based on 2 saved moments · Repeated across several moments',
          ),
          findsOneWidget,
        );
        for (final control in const [
          'Accurate',
          'Wrong angle',
          'Too generic',
          'Hide',
        ]) {
          expect(find.text(control), findsOneWidget);
        }
        expect(find.text('Check all evidence'), findsOneWidget);
      },
    );

    testWidgets('exactly one quote, and never the second one', (tester) async {
      await _pump(tester);

      expect(
        find.byKey(const Key('post_save_strongest_quote')),
        findsOneWidget,
      );
      expect(find.textContaining(_thenQuote), findsNothing);
    });

    testWidgets('the full date is never abbreviated to a relative one', (
      tester,
    ) async {
      await _pump(tester);

      final date = tester
          .widget<Text>(find.byKey(const Key('post_save_evidence_date')))
          .data;
      expect(date, 'Text · 31 July 2026');
      for (final vague in const ['ago', 'Yesterday', 'Today', 'Last week']) {
        expect(find.textContaining(vague), findsNothing, reason: vague);
      }
    });

    testWidgets('no confidence percentage and no invented precision', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('80'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+(?:\.\d+)?\s*%')), findsNothing);
      expect(
        find.textContaining('Repeated across several moments'),
        findsOneWidget,
      );
    });

    testWidgets('one primary action, and no pile of nested cards', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      for (final competing in const [
        'Record another moment',
        'Upgrade',
        'Set a reminder',
        'Share',
      ]) {
        expect(find.widgetWithText(FilledButton, competing), findsNothing);
      }
    });

    testWidgets('a screen reader hears the claim before the corrections', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      final order = semanticReadingOrder(tester);
      expectAnnouncedBefore(order, 'Possible change', 'Based on');
      expectAnnouncedBefore(order, 'Based on', 'Correct this interpretation');
      expectAnnouncedBefore(
        order,
        'Correct this interpretation',
        'Check all evidence',
      );
      handle.dispose();
    });
  });

  group('at the largest text scale', () {
    testWidgets('every control still works and nothing clips', (tester) async {
      await _pump(
        tester,
        profile: const AccessibilityProfile(
          name: 'narrow phone, maximum text',
          size: Size(320, 640),
          brightness: Brightness.light,
          textScale: AccessibilityProfile.maximumPracticalTextScale,
        ),
      );

      expectNoOverflow(tester);
      expectTapTargets(tester);

      for (final control in const [
        'post_save_feedback_accurate',
        'post_save_feedback_wrong_angle',
        'post_save_feedback_too_generic',
        'post_save_feedback_hide',
        'post_save_check_all_evidence',
      ]) {
        final finder = find.byKey(Key(control));
        expect(finder, findsOneWidget, reason: control);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      await _expand(tester);
      expect(
        find.byKey(const Key('post_save_evidence_detail_sheet')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });
  });

  group('expanded evidence', () {
    testWidgets('it shows every quote once, in chronological order', (
      tester,
    ) async {
      await _pump(tester, size: const Size(390, 2400));
      await _expand(tester);

      expect(find.text('All evidence'), findsOneWidget);
      final quotes = _sheetText(
        tester,
      ).where((data) => data.startsWith('“')).toList();
      expect(quotes.toSet().length, quotes.length, reason: 'no duplicates');
      expect(quotes, ['“$_thenQuote”', '“$_nowQuote”']);

      expect(find.text('Chronology'), findsOneWidget);
      final chronology = _sheetText(
        tester,
      ).where((data) => data.contains('2026')).toList();
      expect(chronology.indexOf('Then · 1 June 2026 · Voice'), isNonNegative);
      expect(
        chronology.indexOf('Then · 1 June 2026 · Voice'),
        lessThan(chronology.indexOf('Now · 31 July 2026 · Text')),
      );
    });

    testWidgets('it names the dimensions that actually moved', (tester) async {
      await _pump(tester, size: const Size(390, 2400));
      await _expand(tester);

      expect(
        find.byKey(const Key('post_save_detail_changed_dimensions')),
        findsOneWidget,
      );
      expect(
        find.text('how strongly you felt it: more'),
        findsOneWidget,
        reason: 'the saved words moved on intensity',
      );
    });

    testWidgets('markers add an ending the words never compared', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(390, 2400),
        markers: const {
          'entry-then': StructuredMarkers(
            entryId: 'entry-then',
            resolution: MarkerResolution.unresolved,
          ),
          'entry-now': StructuredMarkers(
            entryId: 'entry-now',
            resolution: MarkerResolution.resolved,
          ),
        },
      );
      await _expand(tester);

      expect(find.text('how it turned out: more settled'), findsOneWidget);
    });

    testWidgets('it shows the uncertainty, the alternative and the sources', (
      tester,
    ) async {
      await _pump(tester, size: const Size(390, 2400));
      await _expand(tester);

      expect(find.text('Uncertainty'), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_detail_uncertainty_note')),
        findsOneWidget,
      );
      expect(find.text('Alternative explanation'), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_detail_alternative_rationale')),
        findsOneWidget,
      );
      expect(find.text('Open exact moment'), findsNWidgets(2));
    });

    testWidgets('the expansion is never carried into a fresh card', (
      tester,
    ) async {
      await _pump(tester, size: const Size(390, 2400));
      await _expand(tester);
      Navigator.of(tester.element(find.text('All evidence'))).pop();
      await tester.pumpAndSettle();

      // A card built again for the same reading opens collapsed: the expansion
      // lives in the widget tree for this session and nowhere else.
      await _pump(tester, size: const Size(390, 2400));

      expect(
        find.byKey(const Key('post_save_evidence_detail_sheet')),
        findsNothing,
      );
      expect(find.text('Check all evidence'), findsOneWidget);
    });
  });
}

/// Every string the expanded sheet renders, in traversal order. Scoped to the
/// sheet so the card still mounted behind it cannot look like a duplicate.
List<String> _sheetText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('post_save_evidence_detail_sheet')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data)
    .whereType<String>()
    .toList();

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('post_save_check_all_evidence')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  AccessibilityProfile? profile,
  Size size = const Size(390, 900),
  Map<String, StructuredMarkers> markers = const {},
}) async {
  final resolved =
      profile ??
      AccessibilityProfile(
        name: 'default',
        size: size,
        brightness: Brightness.light,
        textScale: 1,
      );
  await pumpUnderProfile(
    tester,
    resolved,
    child: SingleChildScrollView(
      child: CompactAuditableConclusionCard(
        conclusion: _validated(),
        markers: markers,
        onEvidenceSelected: (_, _) {},
      ),
    ),
    light: AppTheme.light(),
    dark: AppTheme.dark(),
  );
}

const _thenTranscript = 'I felt slightly worried before the meeting started.';
const _nowTranscript = 'I felt very worried before the meeting started.';
const _thenQuote = 'I felt slightly worried before the meeting';
const _nowQuote = 'I felt very worried before the meeting';
const _statement =
    'You described feeling worried before the meeting more strongly than in '
    'the earlier moment.';

ValidatedExplainableConclusion _validated() {
  final conclusion = ExplainableConclusion(
    id: 'change-intensity',
    statement: _statement,
    confidence: 80,
    reasoning: const [
      'The earlier saved words describe being slightly worried.',
      'The later saved words describe being very worried.',
    ],
    uncertaintyNote:
        'Two moments cannot show whether the stronger wording holds.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-then',
        quote: _thenQuote,
        startUtf16: _thenTranscript.indexOf(_thenQuote),
        endUtf16: _thenTranscript.indexOf(_thenQuote) + _thenQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 6, 1, 9),
        sourceType: EvidenceSourceType.voice,
        temporalRole: EvidenceTemporalRole.then,
        confidenceScore: 0.9,
      ),
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: _nowQuote,
        startUtf16: _nowTranscript.indexOf(_nowQuote),
        endUtf16: _nowTranscript.indexOf(_nowQuote) + _nowQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
        confidenceScore: 0.95,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'The later meeting may simply have carried more at stake.',
        rationale: 'Neither saved moment says what the meeting was about.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
    kind: ExplainableInsightKind.change,
  );
  final gated = ExplainableConclusionRenderGate.visible(
    conclusion,
    canonicalTranscripts: const {
      'entry-then': _thenTranscript,
      'entry-now': _nowTranscript,
    },
  );
  expect(gated, isNotNull, reason: 'fixture must survive the render gate');
  return gated!;
}
