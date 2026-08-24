import 'dart:async';

import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact words held in storage for `e1`.
const _storedTranscript =
    'I said yes before checking my calendar again, and then I felt trapped '
    'for the rest of the week.';

/// The exact words held in storage for `e2`.
const _laterTranscript =
    'This time I paused and checked first before I answered them.';

InsightEvidenceLine _line({
  required String entryId,
  required String quote,
  String? label,
}) => InsightEvidenceLine(
  entryId: entryId,
  quote: quote,
  recordedAt: DateTime.utc(2026, 6),
  label: label,
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUp(TranscriptEvidenceIndex.resetForTest);
  tearDown(TranscriptEvidenceIndex.resetForTest);

  group('ViewSourceProofSection with grounded evidence', () {
    setUp(() {
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: 'e1',
          transcript: _storedTranscript,
          recordedAt: DateTime.utc(2026, 6),
        )!,
      );
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: 'e2',
          transcript: _laterTranscript,
          recordedAt: DateTime.utc(2026, 7),
        )!,
      );
    });

    testWidgets('one tap on the link opens the verified proof sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ViewSourceProofSection.fromLines(
            lines: [
              _line(entryId: 'e1', quote: 'I said yes before checking my calendar'),
              _line(entryId: 'e2', quote: 'I paused and checked first'),
            ],
          ),
        ),
      );

      expect(find.byKey(ViewSourceProofSection.sectionKey), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofLink.linkKey), findsOneWidget);
      // Nothing is quoted before the tap.
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);

      await tester.tap(find.byKey(VerifiedSourceProofLink.linkKey));
      await tester.pumpAndSettle();

      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.sheetLead), findsOneWidget);
    });

    testWidgets('the sheet quotes stored words, not the candidate string', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ViewSourceProofSection.fromLines(
            // Lower-cased and differently spaced on purpose: the sheet must
            // show the stored spelling, not what the caller passed in.
            lines: [
              _line(entryId: 'e1', quote: 'i said   YES before checking my calendar'),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(VerifiedSourceProofLink.linkKey));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(find.text(EvidenceCitationCopy.verbatimHelper), findsOneWidget);

      final quote = tester
          .widget<Text>(find.byKey(EvidenceCitationCard.quoteTextKey))
          .data;
      expect(quote, contains('I said yes before checking my calendar'));
      expect(quote, isNot(contains('YES')));
    });

    testWidgets('counts only the lines that verified', (tester) async {
      await tester.pumpWidget(
        _host(
          ViewSourceProofSection.fromLines(
            lines: [
              _line(entryId: 'e1', quote: 'I said yes before checking my calendar'),
              // Not present in any stored transcript.
              _line(entryId: 'e1', quote: 'you are avoiding your own boundaries'),
            ],
          ),
        ),
      );

      expect(find.text(EvidenceTrustCopy.supportedByEntries(1)), findsOneWidget);
      expect(find.textContaining(EvidenceTrustCopy.sourceCount(1)), findsOneWidget);
    });

    testWidgets('link meets the minimum touch target and is a labelled button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ViewSourceProofSection.fromLines(
            lines: [
              _line(entryId: 'e1', quote: 'I said yes before checking my calendar'),
            ],
          ),
        ),
      );

      final size = tester.getSize(find.byKey(VerifiedSourceProofLink.linkKey));
      expect(
        size.height,
        greaterThanOrEqualTo(VerifiedSourceProofLink.minTapTarget),
      );

      final semantics = tester.getSemantics(
        find.byKey(VerifiedSourceProofLink.linkKey),
      );
      expect(semantics.label, contains(EvidenceTrustCopy.viewSourceProof));
    });
  });

  group('ViewSourceProofSection without grounded evidence', () {
    testWidgets(
      'tap opens an honest-empty sheet and never invents a quote',
      (tester) async {
        await tester.pumpWidget(
          _host(
            ViewSourceProofSection.fromLines(
              lines: [
                _line(
                  entryId: 'missing',
                  quote: 'you avoid difficult conversations',
                ),
              ],
            ),
          ),
        );

        expect(find.byKey(ViewSourceProofSection.sectionKey), findsOneWidget);
        expect(find.byKey(VerifiedSourceProofLink.linkKey), findsOneWidget);
        expect(find.text('you avoid difficult conversations'), findsNothing);

        await tester.tap(find.byKey(VerifiedSourceProofLink.linkKey));
        await tester.pumpAndSettle();

        expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
        expect(
          find.text(EvidenceTrustCopy.howWeKnowThisPattern),
          findsOneWidget,
        );
        expect(
          find.text(EvidenceTrustCopy.sourceQuotesUnavailable),
          findsOneWidget,
        );
        expect(find.text('you avoid difficult conversations'), findsNothing);
        expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
      },
    );

    testWidgets('paraphrase of a stored entry is not quoted as an excerpt', (
      tester,
    ) async {
      TranscriptEvidenceIndex.remember(
        SpokenTranscript.fromCaptureText(
          entryId: 'e1',
          transcript: _storedTranscript,
        )!,
      );

      await tester.pumpWidget(
        _host(
          ViewSourceProofSection.fromLines(
            lines: [
              // A plausible summary of the stored transcript, but not its words.
              _line(entryId: 'e1', quote: 'You agree to things before you check.'),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(VerifiedSourceProofLink.linkKey));
      await tester.pumpAndSettle();

      expect(find.text('You agree to things before you check.'), findsNothing);
      expect(
        find.text(EvidenceTrustCopy.sourceQuotesUnavailable),
        findsOneWidget,
      );
    });

    testWidgets(
      'the sheet opens empty when nothing verified — no invented excerpt',
      (tester) async {
        late BuildContext hostContext;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        unawaited(
          VerifiedSourceProofSheet.show(
            hostContext,
            lines: [_line(entryId: 'missing', quote: 'a generated observation')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
        expect(find.text('a generated observation'), findsNothing);
        expect(
          find.text(EvidenceTrustCopy.sourceQuotesUnavailable),
          findsOneWidget,
        );
      },
    );
  });
}
