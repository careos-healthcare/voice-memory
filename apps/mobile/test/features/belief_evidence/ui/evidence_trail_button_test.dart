import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_changes/ui/belief_change_pattern_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_tap.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _storedTranscript =
    'I always say yes before checking my calendar, and then I resent it.';

const _modelParaphrase =
    'You have a deep fear of disappointing people and that is why you agree.';

InsightEvidenceLine _line({
  required String entryId,
  required String quote,
}) => InsightEvidenceLine(
  entryId: entryId,
  quote: quote,
  recordedAt: DateTime.utc(2026, 6),
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _rememberStoredEntry() {
  TranscriptEvidenceIndex.resetForTest();
  TranscriptEvidenceIndex.remember(
    SpokenTranscript.fromCaptureText(
      entryId: 'e1',
      transcript: _storedTranscript,
      recordedAt: DateTime.utc(2026, 6),
    )!,
  );
}

void main() {
  setUp(TranscriptEvidenceIndex.resetForTest);
  tearDown(TranscriptEvidenceIndex.resetForTest);

  group('EvidenceTrailButton', () {
    test('EvidenceTap remains a typedef of EvidenceTrailButton', () {
      const alias = EvidenceTap(evidence: []);
      expect(alias, isA<EvidenceTrailButton>());
    });

    testWidgets('one tap opens the verified proof sheet', (tester) async {
      _rememberStoredEntry();

      await tester.pumpWidget(
        _host(
          EvidenceTrailButton.fromLines(
            lines: [
              _line(
                entryId: 'e1',
                quote: 'I always say yes before checking my calendar',
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(EvidenceTrailButton.buttonKey), findsOneWidget);
      expect(find.byKey(EvidenceTrailButton.tapKey), findsOneWidget);
      expect(find.byKey(EvidenceTap.tapKey), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofLink.linkKey), findsOneWidget);
      expect(find.textContaining(EvidenceTrustCopy.howWeKnow), findsOneWidget);
      expect(find.textContaining(EvidenceTrustCopy.viewSourceProof), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);

      await tester.tap(find.byKey(EvidenceTrailButton.buttonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.howWeKnowThisPattern), findsOneWidget);
      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(find.text(EvidenceCitationCopy.verbatimHelper), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.sheetLead), findsOneWidget);
    });

    testWidgets(
      'unverified model text is never shown as a transcript excerpt',
      (tester) async {
        _rememberStoredEntry();

        await tester.pumpWidget(
          _host(
            EvidenceTrailButton.fromLines(
              lines: [_line(entryId: 'e1', quote: _modelParaphrase)],
            ),
          ),
        );

        expect(find.byKey(EvidenceTrailButton.buttonKey), findsOneWidget);
        expect(find.byKey(EvidenceTap.tapKey), findsOneWidget);
        expect(find.text(_modelParaphrase), findsNothing);
        expect(find.text(EvidenceTrustCopy.transcriptExcerptLabel), findsNothing);

        await tester.tap(find.byKey(EvidenceTrailButton.buttonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
        expect(find.text(EvidenceTrustCopy.howWeKnowThisPattern), findsOneWidget);
        expect(
          find.text(EvidenceTrustCopy.sourceQuotesUnavailable),
          findsOneWidget,
        );
        expect(find.text(_modelParaphrase), findsNothing);
        expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
        expect(
          find.text(EvidenceTrustCopy.transcriptExcerptLabel),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a belief-change card already using ViewSourceProofSection exposes EvidenceTrailButton',
      (tester) async {
        _rememberStoredEntry();
        TranscriptEvidenceIndex.remember(
          SpokenTranscript.fromCaptureText(
            entryId: 'e2',
            transcript: 'I paused and checked first this time.',
            recordedAt: DateTime.utc(2026, 7),
          )!,
        );

        await tester.pumpWidget(
          _host(
            const BeliefChangePatternCard(
              moment: BeliefChangeMoment(
                changeType: BeliefChangeType.softened,
                earlierBeliefExample: 'You always say yes before checking.',
                changeExample: 'You paused and checked first this time.',
                earlierSnippet: BeliefChangeEvidenceSnippet(
                  entryId: 'e1',
                  label: 'Earlier',
                  quote: 'I always say yes before checking my calendar',
                ),
                laterSnippet: BeliefChangeEvidenceSnippet(
                  entryId: 'e2',
                  label: 'Later',
                  quote: 'I paused and checked first this time',
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(EvidenceTrailButton.buttonKey), findsOneWidget);
        expect(find.byKey(VerifiedSourceProofLink.linkKey), findsOneWidget);
        expect(find.textContaining(EvidenceTrustCopy.howWeKnow), findsOneWidget);

        await tester.tap(find.byKey(EvidenceTrailButton.buttonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
        expect(find.text(LegacyProvenanceCopy.title), findsNothing);
        expect(find.text(_modelParaphrase), findsNothing);
      },
    );
  });
}
