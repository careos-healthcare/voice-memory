import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_quote_chip.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _entryId = 'entry_1';
final _recordedAt = DateTime(2026, 8, 14);

const _transcript =
    'I keep telling myself I want to speak at the conference, but every time '
    'the invite lands I find a reason to say no. It is the same story as last '
    'quarter.';

const _longTranscript =
    'I keep telling myself I want to speak at the conference, but every time '
    'the invite lands I find a reason to say no. It is the same story as last '
    'quarter, and the quarter before that, and honestly for most of the last '
    'two years I have been circling the same decision without ever actually '
    'making it, which is starting to feel like the real pattern here rather '
    'than any single missed opportunity or scheduling conflict.';

VerbatimEvidence _evidenceFor(
  String candidate, {
  String source = _transcript,
  DateTime? recordedAt,
}) {
  final grounding = VerbatimEvidenceVerifier.verify(
    entryId: _entryId,
    candidate: candidate,
    sourceText: source,
    recordedAt: recordedAt ?? _recordedAt,
  );
  final evidence = grounding.evidence;
  if (evidence == null) {
    throw StateError('fixture candidate is not in the source transcript');
  }
  return evidence;
}

Widget _host(Widget child, {double textScale = 1, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(TranscriptEvidenceIndex.resetForTest);
  tearDown(TranscriptEvidenceIndex.resetForTest);

  group('VerbatimEvidenceVerifier', () {
    test('returns the stored spelling, not the candidate spelling', () {
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'i find a REASON to say no',
        sourceText: _transcript,
      );

      expect(grounding.isGrounded, isTrue);
      expect(grounding.evidence!.text, 'I find a reason to say no');
      expect(_transcript.contains(grounding.evidence!.text), isTrue);
    });

    test('rejects a paraphrase that is not in the transcript', () {
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'You avoid public speaking opportunities',
        sourceText: _transcript,
      );

      expect(grounding.isGrounded, isFalse);
      expect(grounding.failure, EvidenceGroundingFailure.notPresentInSource);
    });

    test('rejects a quote stitched together from two entries', () {
      // Mirrors the prediction mapper, which joins a trigger quote and an
      // outcome quote from different entries with an arrow.
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'I want to speak at the conference \u2192 I say no',
        sourceText: _transcript,
      );

      expect(grounding.isGrounded, isFalse);
      expect(grounding.failure, EvidenceGroundingFailure.notPresentInSource);
    });

    test('reports source unavailable when no transcript is held', () {
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'I find a reason to say no',
        sourceText: null,
      );

      expect(grounding.failure, EvidenceGroundingFailure.sourceUnavailable);
    });

    test('resolves a candidate that upstream shortened with an ellipsis', () {
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'I keep telling myself I want to sp\u2026',
        sourceText: _transcript,
      );

      expect(grounding.isGrounded, isTrue);
      // Grown to the enclosing word rather than cut mid-word.
      expect(grounding.evidence!.text, 'I keep telling myself I want to speak');
    });

    test('tolerates differing whitespace but keeps stored whitespace', () {
      final grounding = VerbatimEvidenceVerifier.verify(
        entryId: _entryId,
        candidate: 'reason   to\n say no',
        sourceText: _transcript,
      );

      expect(grounding.evidence!.text, 'reason to say no');
    });

    test('groundLines drops ungrounded lines instead of substituting', () {
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: _entryId,
          transcript: _transcript,
        )!,
      );

      final verified = VerbatimEvidenceVerifier.groundLines([
        InsightEvidenceLine(
          entryId: _entryId,
          quote: 'I find a reason to say no',
          recordedAt: _recordedAt,
        ),
        InsightEvidenceLine(
          entryId: _entryId,
          quote: 'You are afraid of visibility',
          recordedAt: _recordedAt,
        ),
      ]);

      expect(verified, hasLength(1));
      expect(verified.single.text, 'I find a reason to say no');
    });
  });

  group('EvidenceCitationCard', () {
    testWidgets('renders the quote verbatim with its recorded date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EvidenceCitationCard(
            evidence: _evidenceFor('I find a reason to say no'),
          ),
        ),
      );

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      final quote = tester.widget<Text>(
        find.byKey(EvidenceCitationCard.quoteTextKey),
      );
      expect(quote.data, '\u201CI find a reason to say no\u201D');
      expect(find.text(EvidenceCitationCopy.quoteLabel), findsOneWidget);
      expect(
        find.text(
          EvidenceCitationCopy.recordedOn(formatUserFacingDate(_recordedAt)),
        ),
        findsOneWidget,
      );
      expect(find.text(EvidenceCitationCopy.verbatimHelper), findsOneWidget);
    });

    testWidgets('announces itself as a quotation with its timestamp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          EvidenceCitationCard(
            evidence: _evidenceFor('I find a reason to say no'),
          ),
        ),
      );

      final expected = EvidenceCitationCopy.quotationSemantics(
        quote: 'I find a reason to say no',
        recorded: EvidenceCitationCopy.recordedOn(
          formatUserFacingDate(_recordedAt),
        ),
      );
      expect(find.bySemanticsLabel(expected), findsOneWidget);
      expect(expected, contains('Quote:'));
      expect(expected, contains('End of quote'));
      handle.dispose();
    });

    testWidgets('short quotes offer no expand control', (tester) async {
      await tester.pumpWidget(
        _host(
          EvidenceCitationCard(
            evidence: _evidenceFor('I find a reason to say no'),
          ),
        ),
      );

      expect(find.byKey(EvidenceCitationCard.expandKey), findsNothing);
    });

    testWidgets('long quotes truncate with an expand affordance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final evidence = _evidenceFor(
        _longTranscript,
        source: _longTranscript,
      );
      await tester.pumpWidget(_host(EvidenceCitationCard(evidence: evidence)));

      final collapsed = tester.widget<Text>(
        find.byKey(EvidenceCitationCard.quoteTextKey),
      );
      expect(collapsed.maxLines, EvidenceCitationMetrics.collapsedQuoteLines);
      expect(collapsed.overflow, TextOverflow.ellipsis);
      // Truncation is a display limit only — the full stored text is intact.
      expect(collapsed.data, contains(_longTranscript));

      expect(find.text(EvidenceCitationCopy.expandQuote), findsOneWidget);
      await tester.tap(find.byKey(EvidenceCitationCard.expandKey));
      await tester.pumpAndSettle();

      final expanded = tester.widget<Text>(
        find.byKey(EvidenceCitationCard.quoteTextKey),
      );
      expect(expanded.maxLines, isNull);
      expect(find.text(EvidenceCitationCopy.collapseQuote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow at phone, tablet, and 2x text', (
      tester,
    ) async {
      final evidence = _evidenceFor(
        _longTranscript,
        source: _longTranscript,
      );

      for (final size in const [Size(390, 844), Size(1024, 1366)]) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _host(
              EvidenceCitationCard(evidence: evidence),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'overflowed at $size @${scale}x',
          );
        }
      }
    });

    testWidgets('expand and open-entry keep a 48pt minimum tap target', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          EvidenceCitationCard(
            evidence: _evidenceFor(_longTranscript, source: _longTranscript),
            onOpenEntry: (_) {},
          ),
        ),
      );
      await tester.pump();

      final expand = tester.getSize(find.byKey(EvidenceCitationCard.expandKey));
      final open = tester.getSize(find.byKey(EvidenceCitationCard.openEntryKey));
      expect(expand.height, greaterThanOrEqualTo(EvidenceCitationCard.minTapTarget));
      expect(open.height, greaterThanOrEqualTo(EvidenceCitationCard.minTapTarget));
    });

    testWidgets('renders in the dark theme without overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          EvidenceCitationCard(
            evidence: _evidenceFor('I find a reason to say no'),
          ),
          theme: AppTheme.dark(),
        ),
      );

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EvidenceCitationList', () {
    testWidgets('shows the no-evidence state instead of an empty card', (
      tester,
    ) async {
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: _entryId,
          transcript: _transcript,
        )!,
      );

      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [
              InsightEvidenceLine(
                entryId: _entryId,
                quote: 'You avoid visibility because of imposter feelings',
                recordedAt: _recordedAt,
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsOneWidget);
      expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
      expect(find.text(EvidenceCitationCopy.ungroundedTitle), findsOneWidget);
      expect(find.text(EvidenceCitationCopy.ungroundedHelper), findsOneWidget);
    });

    testWidgets('distinguishes an unloaded source from an unproven claim', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [
              InsightEvidenceLine(
                entryId: 'never_loaded',
                quote: 'I find a reason to say no',
                recordedAt: _recordedAt,
              ),
            ],
          ),
        ),
      );

      expect(
        find.text(EvidenceCitationCopy.sourceUnavailableTitle),
        findsOneWidget,
      );
      expect(find.text(EvidenceCitationCopy.ungroundedTitle), findsNothing);
    });

    testWidgets('renders a card per verified quote', (tester) async {
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: _entryId,
          transcript: _transcript,
        )!,
      );

      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [
              InsightEvidenceLine(
                entryId: _entryId,
                quote: 'I find a reason to say no',
                recordedAt: _recordedAt,
              ),
              InsightEvidenceLine(
                entryId: _entryId,
                quote: 'It is the same story as last quarter',
                recordedAt: _recordedAt,
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(EvidenceCitationCard.cardKey), findsNWidgets(2));
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
    });

    testWidgets('can suppress the notice where the claim is suppressed too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [
              InsightEvidenceLine(
                entryId: 'never_loaded',
                quote: 'I find a reason to say no',
                recordedAt: _recordedAt,
              ),
            ],
            showUngroundedNotice: false,
          ),
        ),
      );

      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
      expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
    });
  });

  group('SourceQuoteChip', () {
    testWidgets('shows one truncated line and expands to the full card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final evidence = _evidenceFor(
        _longTranscript,
        source: _longTranscript,
      );
      await tester.pumpWidget(_host(SourceQuoteChip(evidence: evidence)));

      final chipText = tester.widget<Text>(
        find.byKey(SourceQuoteChip.chipTextKey),
      );
      expect(chipText.maxLines, 1);
      expect(chipText.overflow, TextOverflow.ellipsis);
      expect(find.text(EvidenceCitationCopy.expandQuote), findsWidgets);

      await tester.tap(find.byKey(SourceQuoteChip.chipKey));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces the quote and its date as shortened', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SourceQuoteChip(
            evidence: _evidenceFor('I find a reason to say no'),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          EvidenceCitationCopy.truncatedQuotationSemantics(
            quote: 'I find a reason to say no',
            recorded: EvidenceCitationCopy.recordedOn(
              formatUserFacingDate(_recordedAt),
            ),
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('lays out without overflow at tablet width and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          SourceQuoteChip(
            evidence: _evidenceFor(
              _longTranscript,
              source: _longTranscript,
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
