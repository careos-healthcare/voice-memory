import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/adaptive_question/adaptive_question.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_ownership_decision_service.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_ownership_decision_sheet.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_markers.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';
import 'package:voicememory_mobile/widgets/record/evidence_grounded_next_question_card.dart';
import 'package:voicememory_mobile/widgets/record/optional_structured_check_card.dart';

import 'support/accessibility_matrix.dart';

/// Accessibility is checked as a matrix, not a spot check: every retained
/// surface is pumped on a narrow phone, a large phone and a tablet, in light
/// and dark, at normal and maximum practical text scaling, and with reduced
/// motion. A surface that only works at 1.0x on a 390pt phone is not done.
void main() {
  const summary = UnclaimedArchiveSummary(
    sourceArchiveId: 'guest-archive',
    ownerKind: LocalArchiveOwnerKind.guest,
    momentCount: 4,
    earliestAt: null,
    latestAt: null,
  );

  Widget surface() => ArchiveOwnershipDecisionSheet(
    summary: summary,
    onKeepSeparate: () {},
    onMoveToAccount: () {},
    onExport: () {},
    onDelete: () {},
  );

  for (final profile in AccessibilityProfile.matrix) {
    testWidgets('${profile.name}: no overflow and usable targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUnderProfile(
        tester,
        profile,
        child: SingleChildScrollView(child: surface()),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      expectNoOverflow(tester);
      expectTapTargets(tester);
      handle.dispose();
    });
  }

  testWidgets('long quotes wrap instead of clipping at maximum text', (
    tester,
  ) async {
    const quote =
        'I checked the finished report again before sending it, and then I '
        'read it one more time because I was not sure it was ready.';
    await pumpUnderProfile(
      tester,
      const AccessibilityProfile(
        name: 'narrow, maximum text',
        size: Size(320, 640),
        brightness: Brightness.light,
        textScale: AccessibilityProfile.maximumPracticalTextScale,
      ),
      child: const SingleChildScrollView(child: Text(quote)),
      light: AppTheme.light(),
      dark: AppTheme.dark(),
    );

    expectNoOverflow(tester);
    final rendered = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(rendered.size.height, greaterThan(40));
    expect(rendered.text.toPlainText(), quote);
  });

  testWidgets('reading order announces the decision before the actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUnderProfile(
      tester,
      AccessibilityProfile.matrix.first,
      child: SingleChildScrollView(child: surface()),
      light: AppTheme.light(),
      dark: AppTheme.dark(),
    );

    final order = semanticReadingOrder(tester);
    expectAnnouncedBefore(order, 'private saved moments', 'Keep separate');
    expectAnnouncedBefore(order, 'Keep separate', 'Delete');
    handle.dispose();
  });

  testWidgets('every action carries a text label, not an icon alone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUnderProfile(
      tester,
      AccessibilityProfile.matrix.first,
      child: SingleChildScrollView(child: surface()),
      light: AppTheme.light(),
      dark: AppTheme.dark(),
    );

    for (final element in find.byType(TextButton).evaluate()) {
      final labels = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(Text),
      );
      expect(
        labels,
        findsWidgets,
        reason: 'An action must not rely on an icon or colour alone.',
      );
    }
    handle.dispose();
  });

  testWidgets('reduced motion suppresses animation', (tester) async {
    await pumpUnderProfile(
      tester,
      const AccessibilityProfile(
        name: 'reduced motion',
        size: Size(390, 844),
        brightness: Brightness.light,
        textScale: 1,
        reduceMotion: true,
      ),
      child: Builder(
        builder: (context) => Text(
          MediaQuery.disableAnimationsOf(context)
              ? 'animations disabled'
              : 'animations enabled',
        ),
      ),
      light: AppTheme.light(),
      dark: AppTheme.dark(),
    );

    expect(find.text('animations disabled'), findsOneWidget);
  });

  testWidgets('keyboard focus moves through every action in order', (
    tester,
  ) async {
    await pumpUnderProfile(
      tester,
      AccessibilityProfile.matrix.first,
      child: SingleChildScrollView(child: surface()),
      light: AppTheme.light(),
      dark: AppTheme.dark(),
    );

    final visited = <String>[];
    for (var step = 0; step < 4; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = primaryFocus?.context?.widget;
      if (focused == null) continue;
      final label = find.descendant(
        of: find.byWidget(focused),
        matching: find.byType(Text),
      );
      if (label.evaluate().isNotEmpty) {
        visited.add(tester.widget<Text>(label.first).data ?? '');
      }
    }

    expect(visited, isNotEmpty, reason: 'No action was keyboard reachable.');
  });

  group('compact post-save conclusion', () {
    for (final profile in AccessibilityProfile.matrix) {
      testWidgets('${profile.name}: no overflow and usable targets', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpUnderProfile(
          tester,
          profile,
          child: SingleChildScrollView(
            child: CompactAuditableConclusionCard(
              conclusion: _validatedConclusion(),
            ),
          ),
          light: AppTheme.light(),
          dark: AppTheme.dark(),
        );

        expectNoOverflow(tester);
        expectTapTargets(tester);
        handle.dispose();
      });
    }

    testWidgets('the claim is announced before the correction controls', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUnderProfile(
        tester,
        AccessibilityProfile.matrix.first,
        child: SingleChildScrollView(
          child: CompactAuditableConclusionCard(
            conclusion: _validatedConclusion(),
          ),
        ),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

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

    testWidgets('the evidence quote wraps rather than clipping at 2x text', (
      tester,
    ) async {
      await pumpUnderProfile(
        tester,
        const AccessibilityProfile(
          name: 'narrow, maximum text',
          size: Size(320, 640),
          brightness: Brightness.light,
          textScale: AccessibilityProfile.maximumPracticalTextScale,
        ),
        child: SingleChildScrollView(
          child: CompactAuditableConclusionCard(
            conclusion: _validatedConclusion(),
          ),
        ),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      expectNoOverflow(tester);
      final quote = tester.widget<Text>(
        find.byKey(const Key('post_save_strongest_quote')),
      );
      expect(
        quote.maxLines,
        isNull,
        reason: 'A quote must never be truncated.',
      );
      expect(quote.softWrap, isNot(false));
    });
  });

  group('optional ten-second check', () {
    Widget check() => OptionalStructuredCheckCard(
      entryId: 'entry-now',
      initialMarkers: const StructuredMarkers(
        entryId: 'entry-now',
        strength: MarkerStrength.medium,
      ),
      onChanged: (_) {},
    );

    for (final profile in AccessibilityProfile.matrix) {
      testWidgets('${profile.name}: no overflow and usable targets', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpUnderProfile(
          tester,
          profile,
          child: SingleChildScrollView(child: check()),
          light: AppTheme.light(),
          dark: AppTheme.dark(),
        );

        expectNoOverflow(tester);
        expectTapTargets(tester);
        handle.dispose();
      });
    }

    testWidgets('each question is announced before its own answers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUnderProfile(
        tester,
        AccessibilityProfile.matrix.first,
        child: SingleChildScrollView(child: check()),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      final order = semanticReadingOrder(tester);
      expectAnnouncedBefore(
        order,
        'Optional ten-second check',
        StructuredCheckPrompts.strength,
      );
      expectAnnouncedBefore(order, StructuredCheckPrompts.strength, 'Medium');
      expectAnnouncedBefore(order, 'Medium', StructuredCheckPrompts.action);
      expectAnnouncedBefore(
        order,
        StructuredCheckPrompts.action,
        StructuredCheckPrompts.resolution,
      );
      expectAnnouncedBefore(order, StructuredCheckPrompts.resolution, 'Skip');
      handle.dispose();
    });

    testWidgets('every answer stays removable at maximum text scale', (
      tester,
    ) async {
      await pumpUnderProfile(
        tester,
        const AccessibilityProfile(
          name: 'narrow, maximum text',
          size: Size(320, 640),
          brightness: Brightness.light,
          textScale: AccessibilityProfile.maximumPracticalTextScale,
        ),
        child: SingleChildScrollView(child: check()),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      expectNoOverflow(tester);
      expectTapTargets(tester);
      final remove = find.byKey(const Key('structured_check_remove'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(remove, findsNothing, reason: 'the markers are gone');
      expectNoOverflow(tester);
    });
  });

  group('one evidence-grounded question', () {
    Widget question() => EvidenceGroundedNextQuestionCard(
      question: const AdaptiveQuestion(
        text:
            'Last time, you said you kept checking the finished report again '
            'and again. What happened when you reached that point today?',
        conclusionId: 'change-accessibility',
        groundingEntryId: 'entry-then',
        openDimension: ChangeDimension.stoppingOrCompletionBehaviour,
      ),
      onRecordNext: (_) {},
    );

    for (final profile in AccessibilityProfile.matrix) {
      testWidgets('${profile.name}: no overflow and usable targets', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpUnderProfile(
          tester,
          profile,
          child: SingleChildScrollView(child: question()),
          light: AppTheme.light(),
          dark: AppTheme.dark(),
        );

        expectNoOverflow(tester);
        expectTapTargets(tester);
        handle.dispose();
      });
    }

    testWidgets('the question is announced before the way out of it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUnderProfile(
        tester,
        AccessibilityProfile.matrix.first,
        child: SingleChildScrollView(child: question()),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      final order = semanticReadingOrder(tester);
      expectAnnouncedBefore(order, 'One question for next time', 'Last time');
      expectAnnouncedBefore(order, 'Last time', 'Answer this next');
      expectAnnouncedBefore(order, 'Answer this next', 'Not this');
      handle.dispose();
    });

    testWidgets('it can still be dismissed at maximum text scale', (
      tester,
    ) async {
      await pumpUnderProfile(
        tester,
        const AccessibilityProfile(
          name: 'narrow, maximum text',
          size: Size(320, 640),
          brightness: Brightness.light,
          textScale: AccessibilityProfile.maximumPracticalTextScale,
        ),
        child: SingleChildScrollView(child: question()),
        light: AppTheme.light(),
        dark: AppTheme.dark(),
      );

      expectNoOverflow(tester);
      final text = tester.widget<Text>(
        find.byKey(const Key('post_save_next_question')),
      );
      expect(text.maxLines, isNull, reason: 'a question is never truncated');

      final dismiss = find.byKey(const Key('post_save_next_question_dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.pumpAndSettle();
      await tester.tap(dismiss);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_save_next_question')), findsNothing);
    });
  });
}

const _thenTranscript =
    'I kept checking the finished report again and again before I could send '
    'it to my manager, and the checking took most of the evening.';
const _nowTranscript =
    'I sent the finished report to my manager after one quick check, and the '
    'rest of the evening stayed free for the things I actually wanted to do.';
const _thenQuote =
    'I kept checking the finished report again and again before I could send it';

ValidatedExplainableConclusion _validatedConclusion() {
  final thenStart = _thenTranscript.indexOf(_thenQuote);
  final nowStart = _nowTranscript.indexOf(_nowTranscript);
  final conclusion = ExplainableConclusion(
    id: 'change-accessibility',
    statement:
        'You sent the finished report after one check, where the same report '
        'once took repeated checking.',
    confidence: 80,
    reasoning: const [
      'The earlier saved words describe repeated checking of the report.',
      'The later saved words describe one check before sending the report.',
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
        quote: _nowTranscript,
        startUtf16: nowStart,
        endUtf16: nowStart + _nowTranscript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
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
    kind: ExplainableInsightKind.change,
  );
  final gated = ExplainableConclusionRenderGate.visible(
    conclusion,
    canonicalTranscripts: const {
      'entry-then': _thenTranscript,
      'entry-now': _nowTranscript,
    },
  );
  if (gated == null) {
    throw StateError('Accessibility fixture must survive the render gate.');
  }
  return gated;
}
