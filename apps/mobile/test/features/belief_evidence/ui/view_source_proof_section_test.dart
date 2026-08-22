import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViewSourceProofSection', () {
    const citations = [
      FactLedgerResolvedCitation(
        entryId: 'e1',
        quote: 'I said yes before checking my calendar.',
      ),
      FactLedgerResolvedCitation(
        entryId: 'e2',
        quote: 'I paused and checked first this time.',
      ),
    ];

    testWidgets('shows inline source count and opens proof sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ViewSourceProofSection(
              citations: citations,
              leadLine: 'Supported by 2 entries',
            ),
          ),
        ),
      );

      expect(find.byKey(ViewSourceProofSection.sectionKey), findsOneWidget);
      expect(find.text('2 sources'), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.viewSourceProof), findsOneWidget);
      expect(find.text('Supported by 2 entries'), findsOneWidget);
      expect(find.textContaining('I said yes'), findsNothing);

      await tester.tap(find.byKey(ViewSourceProofSection.toggleKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ViewSourceProofSheet.sheetKey), findsOneWidget);
      expect(find.text(EvidenceTrustCopy.sheetLead), findsOneWidget);
      expect(find.textContaining('I said yes'), findsOneWidget);
      expect(find.textContaining('I paused'), findsOneWidget);
      expect(
        find.text(EvidenceTrustCopy.transcriptExcerptLabel),
        findsNWidgets(2),
      );
    });

    test('uses neutral source-count copy helper', () {
      expect(EvidenceTrustCopy.sourceCount(3), '3 sources');
      expect(EvidenceTrustCopy.sourceCount(1), '1 source');
      expect(EvidenceTrustCopy.sourceCount(0), '0 sources');
      expect(
        EvidenceTrustCopy.supportedByEntries(3),
        'Supported by 3 entries',
      );
    });
  });
}
