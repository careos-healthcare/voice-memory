import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_changes/ui/belief_change_pattern_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:archiveme_mobile/shared/ui/evidence_trail.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _previewMoment = BeliefChangeMoment(
  changeType: BeliefChangeType.softened,
  earlierBeliefExample: 'You checked the kitchen before sitting down.',
  changeExample: 'You walked first, then opened the laptop.',
  earlierSnippet: BeliefChangeEvidenceSnippet(
    entryId: 'preview-e1',
    label: 'Earlier',
    quote: 'made tea before sitting down',
  ),
  laterSnippet: BeliefChangeEvidenceSnippet(
    entryId: 'preview-e2',
    label: 'Later',
    quote: 'walked around the block',
  ),
);

void main() {
  group('EvidenceTrailBottomSheet preview', () {
    testWidgets('opens a preview sheet, not the verified proof sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EvidenceTrailButton(
            points: EvidencePoint.previewJournalSamples,
          ),
        ),
      );

      expect(find.byKey(EvidenceTrailButton.buttonKey), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);

      await tester.tap(find.byKey(EvidenceTrailButton.buttonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceTrailBottomSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrailBottomSheet.previewTitle), findsOneWidget);
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);
      expect(find.text(EvidenceTrustCopy.howWeKnowThisPattern), findsNothing);
      expect(find.text(EvidenceTrustCopy.transcriptExcerptLabel), findsNothing);
      expect(find.text(EvidenceTrustCopy.sheetLead), findsNothing);
      expect(find.text(EvidencePoint.sampleLabel), findsNWidgets(2));
      expect(
        find.text(EvidencePoint.previewJournalSamples.first.text),
        findsOneWidget,
      );
      expect(
        find.text(EvidencePoint.previewJournalSamples.last.text),
        findsOneWidget,
      );
    });

    testWidgets('debug preview hides when forced off (release stand-in)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const EvidenceTrailDebugPreview(forceVisible: false)),
      );

      expect(find.byKey(EvidenceTrailDebugPreview.bannerKey), findsNothing);
      expect(find.byKey(EvidenceTrailButton.previewButtonKey), findsNothing);
      expect(
        find.text(EvidencePoint.previewJournalSamples.first.text),
        findsNothing,
      );
    });
  });

  group('BeliefChangePatternCard debug preview', () {
    testWidgets('debug-only chip opens sample rows, not verified quotes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BeliefChangePatternCard(moment: _previewMoment)),
      );

      expect(find.byKey(EvidenceTrailDebugPreview.bannerKey), findsOneWidget);
      expect(find.byKey(EvidenceTrailButton.previewButtonKey), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(
        find.text(EvidencePoint.previewJournalSamples.first.text),
        findsNothing,
      );

      await tester.tap(find.byKey(EvidenceTrailButton.previewButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceTrailBottomSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrailBottomSheet.previewTitle), findsOneWidget);
      expect(find.text(EvidencePoint.sampleLabel), findsNWidgets(2));
      expect(find.byKey(VerifiedSourceProofSheet.sheetKey), findsNothing);
      expect(find.text(EvidenceTrustCopy.transcriptExcerptLabel), findsNothing);
      expect(
        find.text(EvidencePoint.previewJournalSamples.first.text),
        findsOneWidget,
      );
    });

    testWidgets('compact cards omit the debug preview chip', (tester) async {
      await tester.pumpWidget(
        _host(
          const BeliefChangePatternCard(
            moment: _previewMoment,
            compact: true,
          ),
        ),
      );

      expect(find.byKey(EvidenceTrailDebugPreview.bannerKey), findsNothing);
      expect(find.byKey(EvidenceTrailButton.previewButtonKey), findsNothing);
    });
  });
}
