import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_changes/ui/belief_change_pattern_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _earlierTranscript =
    'I always say yes before checking my calendar, and then I resent it.';
const _laterTranscript =
    'I paused and checked first this time, which felt unfamiliar.';

const _groundedMoment = BeliefChangeMoment(
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
);

/// Same shape, but the quotes were never spoken — nothing in storage matches.
const _ungroundedMoment = BeliefChangeMoment(
  changeType: BeliefChangeType.softened,
  earlierBeliefExample: 'You always say yes before checking.',
  changeExample: 'You paused and checked first this time.',
  earlierSnippet: BeliefChangeEvidenceSnippet(
    entryId: 'e1',
    label: 'Earlier',
    quote: 'You have a deep fear of disappointing people',
  ),
  laterSnippet: BeliefChangeEvidenceSnippet(
    entryId: 'e2',
    label: 'Later',
    quote: 'You are learning to hold your own boundaries',
  ),
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _rememberBothEntries() {
  TranscriptEvidenceIndex.resetForTest();
  TranscriptEvidenceIndex.remember(
    SpokenTranscript.fromCaptureText(
      entryId: 'e1',
      transcript: _earlierTranscript,
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
}

void main() {
  setUp(TranscriptEvidenceIndex.resetForTest);
  tearDown(TranscriptEvidenceIndex.resetForTest);

  group('BeliefChangePatternCard', () {
    testWidgets('a single tap opens the proof sheet with verified quotes', (
      tester,
    ) async {
      _rememberBothEntries();

      await tester.pumpWidget(
        _host(const BeliefChangePatternCard(moment: _groundedMoment)),
      );

      expect(find.byKey(VerifiedSourceProofLink.linkKey), findsOneWidget);

      await tester.tap(find.byKey(VerifiedSourceProofLink.linkKey));
      await tester.pumpAndSettle();

      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsOneWidget);
      // Both halves of the comparison are provable, so both are shown.
      expect(find.byKey(EvidenceCitationCard.cardKey), findsNWidgets(2));
      expect(find.text(EvidenceCitationCopy.verbatimHelper), findsNWidgets(2));
    });

    testWidgets('an ungrounded card offers no proof affordance', (tester) async {
      _rememberBothEntries();

      await tester.pumpWidget(
        _host(const BeliefChangePatternCard(moment: _ungroundedMoment)),
      );

      // The claim still renders, but it says plainly that it has no quote
      // rather than offering a tap that would open invented proof.
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofLink.linkKey), findsNothing);
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);
    });

    testWidgets('no proof affordance when no transcript was ever indexed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BeliefChangePatternCard(moment: _groundedMoment)),
      );

      expect(find.byKey(VerifiedSourceProofLink.linkKey), findsNothing);
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsOneWidget);
    });
  });
}
