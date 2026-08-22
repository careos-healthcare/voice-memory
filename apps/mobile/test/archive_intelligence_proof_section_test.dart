import 'package:archiveme_mobile/billing/archive_intelligence_proof_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';
import 'package:archiveme_mobile/widgets/archive_paywall/archive_intelligence_proof_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchiveIntelligenceProofSection', () {
    testWidgets('shows headline and bullets from real stats', (tester) async {
      const stats = ArchivePaywallStats(
        recordingCount: 20,
        spanDays: 30,
        recurringThemeCount: 4,
        activeTheoryCount: 1,
        changeCount: 3,
        contradictionCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArchiveIntelligenceProofSection(
              stats: stats,
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text(ArchiveIntelligenceProofCopy.headline), findsOneWidget);
      expect(find.textContaining('4 recurring themes'), findsOneWidget);
      expect(find.textContaining('1 active theory'), findsOneWidget);
      expect(find.textContaining('3 changes over time'), findsOneWidget);
      expect(find.text(ArchiveIntelligenceProofCopy.fallback), findsNothing);
    });

    testWidgets('shows fallback when counts are zero', (tester) async {
      const stats = ArchivePaywallStats(
        recordingCount: 2,
        spanDays: 1,
        recurringThemeCount: 0,
        activeTheoryCount: 0,
        changeCount: 0,
        contradictionCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArchiveIntelligenceProofSection(
              stats: stats,
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text(ArchiveIntelligenceProofCopy.fallback), findsOneWidget);
      expect(find.text(ArchiveIntelligenceProofCopy.headline), findsNothing);
    });
  });
}