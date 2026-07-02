import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/beta_release_qa_copy.dart';
import 'package:voicememory_mobile/features/beta/beta_release_qa_engine.dart';
import 'package:voicememory_mobile/features/beta/beta_release_qa_model.dart';
import 'package:voicememory_mobile/features/debug/archive_beta_debug_gate.dart';
import 'package:voicememory_mobile/widgets/debug/beta_release_qa_card.dart';

void main() {
  tearDown(() {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaDebugGate.resetForTest();
    BetaReleaseQaEngine.resetForTest();
  });

  group('BetaReleaseQaEngine', () {
    test('rows render in order', () {
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveBetaDebugGate.visibleOverride = true;

      final report = BetaReleaseQaEngine.build();
      expect(report.rows, hasLength(11));
      expect(report.rows.map((row) => row.label).toList(), [
        BetaReleaseQaCopy.rowBetaMissionFlag,
        BetaReleaseQaCopy.rowApiBaseUrlPresent,
        BetaReleaseQaCopy.rowRevenueCatKeyPresent,
        BetaReleaseQaCopy.rowFirstUsePromptAvailable,
        BetaReleaseQaCopy.rowTesterMissionAvailable,
        BetaReleaseQaCopy.rowFirstProofPathAvailable,
        BetaReleaseQaCopy.rowReturnCheckPathAvailable,
        BetaReleaseQaCopy.rowEvidenceTimelineAvailable,
        BetaReleaseQaCopy.rowPrivateReportPreviewAvailable,
        BetaReleaseQaCopy.rowProBridgeRouteAvailable,
        BetaReleaseQaCopy.rowActivationDropoffReviewAvailable,
      ]);
    });

    test('all ready shows tester build summary', () {
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveBetaDebugGate.visibleOverride = true;

      final report = BetaReleaseQaEngine.build();
      expect(report.readyForTesterBuild, isTrue);
      expect(report.summary, BetaReleaseQaCopy.summaryReady);
    });

    test('missing beta mission shows needs attention', () {
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = false;
      ArchiveBetaDebugGate.visibleOverride = true;

      final report = BetaReleaseQaEngine.build();
      expect(report.readyForTesterBuild, isFalse);
      expect(report.summary, BetaReleaseQaCopy.summaryNeedsAttention);
      expect(
        report.rows.first.status,
        BetaReleaseQaStatus.missing,
      );
    });

    test('missing config shows Missing not crash', () {
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = false;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = false;
      ArchiveBetaMissionGate.enabledOverride = false;

      final report = BetaReleaseQaEngine.build();
      expect(report.rows, hasLength(11));

      final apiRow = report.rows.firstWhere(
        (row) => row.id == BetaReleaseQaRowId.apiBaseUrlPresent,
      );
      expect(apiRow.detail, BetaReleaseQaCopy.detailMissing);
      expect(apiRow.status, BetaReleaseQaStatus.missing);

      final rcRow = report.rows.firstWhere(
        (row) => row.id == BetaReleaseQaRowId.revenueCatKeyPresent,
      );
      expect(rcRow.detail, BetaReleaseQaCopy.detailMissing);
    });

    test('keys are masked and never printed in full', () {
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = true;

      final joined = BetaReleaseQaEngine.build().visibleCopyBlocks.join('\n');
      expect(joined, isNot(contains('REVENUECAT_')));
      expect(joined, isNot(contains('http://')));
      expect(joined, isNot(contains('https://')));
      expect(joined, contains(BetaReleaseQaCopy.detailSet));
    });

    test('visible copy avoids transcript and user entry text', () {
      final joined =
          BetaReleaseQaEngine.build().visibleCopyBlocks.join('\n').toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes again')));
      expect(joined, isNot(contains('journal entry')));
    });
  });

  group('BetaReleaseQaCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
          ),
        ),
      );

      expect(find.byKey(const Key('beta_release_qa_hidden')), findsOneWidget);
      expect(find.byKey(const Key('beta_release_qa_card')), findsNothing);
    });

    testWidgets('visible when developer diagnostics unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveBetaDebugGate.visibleOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('beta_release_qa_card')), findsOneWidget);
      expect(find.text(BetaReleaseQaCopy.sectionTitle), findsOneWidget);
      expect(find.text(BetaReleaseQaCopy.summaryReady), findsOneWidget);
    });

    testWidgets('manual tester checklist renders', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = true;
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveBetaDebugGate.visibleOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
            ),
          ),
        ),
      );

      expect(
        find.text(BetaReleaseQaCopy.manualChecklistTitle),
        findsOneWidget,
      );
      for (var i = 0; i < BetaReleaseQaCopy.manualChecklistSteps.length; i++) {
        expect(
          find.text('${i + 1}. ${BetaReleaseQaCopy.manualChecklistSteps[i]}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('row statuses render without secrets', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      BetaReleaseQaEngine.apiBaseUrlPresentOverride = true;
      BetaReleaseQaEngine.revenueCatKeyPresentOverride = false;
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('beta_release_qa_row_detail_apiBaseUrlPresent')),
        findsOneWidget,
      );
      expect(find.text(BetaReleaseQaCopy.detailSet), findsOneWidget);
      expect(
        find.byKey(
          const Key('beta_release_qa_row_status_revenueCatKeyPresent'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('REVENUECAT'), findsNothing);
    });
  });
}
