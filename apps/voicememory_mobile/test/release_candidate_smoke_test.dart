import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/release_candidate_smoke_copy.dart';
import 'package:voicememory_mobile/features/beta/release_candidate_smoke_engine.dart';
import 'package:voicememory_mobile/features/beta/release_candidate_smoke_model.dart';
import 'package:voicememory_mobile/widgets/debug/release_candidate_smoke_card.dart';

void main() {
  tearDown(() {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
    ArchiveBetaMissionGate.resetForTest();
    ReleaseCandidateSmokeEngine.resetForTest();
  });

  group('ReleaseCandidateSmokeEngine', () {
    test('rows render in order', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      final report = ReleaseCandidateSmokeEngine.build();
      expect(report.rows, hasLength(12));
      expect(report.rows.map((row) => row.label).toList(), [
        ReleaseCandidateSmokeCopy.rowFirstLaunchRecord,
        ReleaseCandidateSmokeCopy.rowFirstUseCapture,
        ReleaseCandidateSmokeCopy.rowSaveOneMoment,
        ReleaseCandidateSmokeCopy.rowSecondMomentGuidance,
        ReleaseCandidateSmokeCopy.rowFirstProofPath,
        ReleaseCandidateSmokeCopy.rowCoreValueFeedback,
        ReleaseCandidateSmokeCopy.rowPatternsArchive,
        ReleaseCandidateSmokeCopy.rowEvidenceTimeline,
        ReleaseCandidateSmokeCopy.rowPrivateReportPreview,
        ReleaseCandidateSmokeCopy.rowProRoute,
        ReleaseCandidateSmokeCopy.rowRestorePurchasesRoute,
        ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
      ]);
    });

    test('summary ready when all ready', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      final report = ReleaseCandidateSmokeEngine.build();
      expect(report.readyForTestFlight, isTrue);
      expect(report.summary, ReleaseCandidateSmokeCopy.summaryReady);
    });

    test('summary needs attention when one missing', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      final report = ReleaseCandidateSmokeEngine.build();
      expect(report.readyForTestFlight, isFalse);
      expect(report.summary, ReleaseCandidateSmokeCopy.summaryNeedsAttention);
      expect(
        report.rows
            .firstWhere(
              (row) => row.id == ReleaseCandidateSmokeRowId.coreValueFeedback,
            )
            .status,
        ReleaseCandidateSmokeStatus.missing,
      );
    });

    test('manual checklist renders', () {
      final report = ReleaseCandidateSmokeEngine.build();
      expect(
        report.manualChecklistTitle,
        ReleaseCandidateSmokeCopy.manualChecklistTitle,
      );
      expect(
        report.manualChecklistSteps,
        ReleaseCandidateSmokeCopy.manualChecklistSteps,
      );
      expect(report.manualChecklistSteps, hasLength(13));
    });

    test('no secrets displayed', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      final joined =
          ReleaseCandidateSmokeEngine.build().visibleCopyBlocks.join('\n');
      expect(joined, isNot(contains('REVENUECAT_')));
      expect(joined, isNot(contains('http://')));
      expect(joined, isNot(contains('https://')));
      expect(joined, isNot(contains('sk_')));
      expect(joined, isNot(contains('api_key')));
    });

    test('visible copy avoids transcript phrase and user content', () {
      final joined = ReleaseCandidateSmokeEngine.build()
          .visibleCopyBlocks
          .join('\n')
          .toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes again')));
      expect(joined, isNot(contains('journal entry')));
      expect(joined, isNot(contains('phrase text')));
    });
  });

  group('ReleaseCandidateSmokeCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReleaseCandidateSmokeCard(
              report: ReleaseCandidateSmokeEngine.build(),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('release_candidate_smoke_hidden')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('release_candidate_smoke_card')),
        findsNothing,
      );
    });

    testWidgets('visible when unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseCandidateSmokeCard(
                report: ReleaseCandidateSmokeEngine.build(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('release_candidate_smoke_card')),
        findsOneWidget,
      );
      expect(
        find.text(ReleaseCandidateSmokeCopy.sectionTitle),
        findsOneWidget,
      );
      expect(
        find.text(ReleaseCandidateSmokeCopy.summaryReady),
        findsOneWidget,
      );
    });

    testWidgets('manual checklist renders in card', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseCandidateSmokeCard(
                report: ReleaseCandidateSmokeEngine.build(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(ReleaseCandidateSmokeCopy.manualChecklistTitle),
        findsOneWidget,
      );
      for (var i = 0;
          i < ReleaseCandidateSmokeCopy.manualChecklistSteps.length;
          i++) {
        expect(
          find.text(
            '${i + 1}. ${ReleaseCandidateSmokeCopy.manualChecklistSteps[i]}',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('row statuses render without secrets', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      ArchiveBetaMissionGate.enabledOverride = true;
      ReleaseCandidateSmokeEngine.developerDiagnosticsLockedOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseCandidateSmokeCard(
                report: ReleaseCandidateSmokeEngine.build(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('release_candidate_smoke_row_status_firstLaunchRecord'),
        ),
        findsOneWidget,
      );
      expect(find.text(ReleaseCandidateSmokeCopy.statusReady), findsWidgets);
      expect(find.textContaining('REVENUECAT'), findsNothing);
    });
  });
}
