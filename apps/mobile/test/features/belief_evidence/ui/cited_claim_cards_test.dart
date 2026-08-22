import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_changes/ui/belief_change_pattern_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/belief_evidence_insight_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeliefChangePatternCard', () {
    testWidgets('shows inline source counts on each claim', (tester) async {
      const moment = BeliefChangeMoment(
        changeType: BeliefChangeType.softened,
        earlierBeliefExample: 'You always say yes before checking.',
        changeExample: 'You paused and checked first this time.',
        earlierSnippet: BeliefChangeEvidenceSnippet(
          entryId: 'e1',
          label: 'Earlier',
          quote: 'I always say yes before checking my calendar.',
        ),
        laterSnippet: BeliefChangeEvidenceSnippet(
          entryId: 'e2',
          label: 'Later',
          quote: 'I paused and checked first this time.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BeliefChangePatternCard(moment: moment),
          ),
        ),
      );

      expect(find.text('2 sources'), findsNWidgets(2));
      expect(find.text('1 source'), findsNWidgets(2));

      await tester.tap(find.byKey(Key('source_citation_indicator_tap_1')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(ViewSourceProofSheet.sheetKey), findsOneWidget);
      expect(find.textContaining('I always say yes'), findsOneWidget);
    });
  });

  group('BeliefEvidenceInsightCard', () {
    testWidgets('shows inline source counts on headline and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BeliefEvidenceInsightCard(
              headline: 'A recurring pattern may be softening',
              subheadline: 'Based on two saved entries',
              body: 'Your archive recorded different wording across time.',
              supportingEvidence: [
                InsightEvidenceLine(
                  entryId: 'e1',
                  quote: 'I said yes again before checking.',
                  recordedAt: DateTime.utc(2026, 6, 1),
                ),
                InsightEvidenceLine(
                  entryId: 'e2',
                  quote: 'I paused before agreeing this time.',
                  recordedAt: DateTime.utc(2026, 7, 1),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('2 sources'), findsNWidgets(3));
      expect(find.text(EvidenceTrustCopy.viewSourceProof), findsNothing);

      await tester.tap(find.byKey(Key('source_citation_indicator_tap_2')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(ViewSourceProofSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.sheetLead), findsOneWidget);
    });
  });
}
