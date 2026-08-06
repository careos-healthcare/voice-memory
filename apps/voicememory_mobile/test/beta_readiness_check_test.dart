import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_readiness/beta_readiness_analytics.dart';
import 'package:voicememory_mobile/features/beta_readiness/beta_readiness_copy.dart';
import 'package:voicememory_mobile/features/beta_readiness/beta_readiness_engine.dart';
import 'package:voicememory_mobile/features/beta_readiness/beta_readiness_model.dart';
import 'package:archiveme_research/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/account/beta_readiness_check_sheet.dart';

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    BetaReadinessAnalytics.resetForTest();
    BetaReadinessAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/beta_readiness/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/beta_readiness/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    BetaReadinessAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    analyticsEvents.clear();
  });

  group('BetaReadinessEngine', () {
    test('build includes all sections and required items', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final report = BetaReadinessEngine.build();

      expect(report.sections.map((s) => s.title), [
        BetaReadinessCopy.sectionCapture,
        BetaReadinessCopy.sectionFirstProof,
        BetaReadinessCopy.sectionTrustControls,
        BetaReadinessCopy.sectionReturnLoop,
        BetaReadinessCopy.sectionBetaFeedback,
      ]);

      expect(report.allItems.map((item) => item.label), [
        BetaReadinessCopy.itemFirstUseOnboardingAtZero,
        BetaReadinessCopy.itemMicCtaPrimary,
        BetaReadinessCopy.itemTypedFallbackAvailable,
        BetaReadinessCopy.itemNoDailyMapBeforeFirstSave,
        BetaReadinessCopy.itemThreeMomentsUnlockFirstProof,
        BetaReadinessCopy.itemGenericEntriesNoFirstProof,
        BetaReadinessCopy.itemFirstProofPayoffAppears,
        BetaReadinessCopy.itemFirstProofTruthFollowUp,
        BetaReadinessCopy.itemFirstProofActionLoopAfterAnswer,
        BetaReadinessCopy.itemSavedMomentsOpens,
        BetaReadinessCopy.itemDeleteMomentAvailable,
        BetaReadinessCopy.itemRemoveFromPatternAvailable,
        BetaReadinessCopy.itemCorrectTranscriptAvailable,
        BetaReadinessCopy.itemPrivacyCentreOpens,
        BetaReadinessCopy.itemExportLocalBackupAvailable,
        BetaReadinessCopy.itemRestoreLocalBackupAvailable,
        BetaReadinessCopy.itemReturnTomorrowCue,
        BetaReadinessCopy.itemReturnDayFlowAvailable,
        BetaReadinessCopy.itemWhatChangedAfterFourthMoment,
        BetaReadinessCopy.itemSendBetaFeedbackAvailable,
        BetaReadinessCopy.itemBetaProgressSummaryAvailable,
        BetaReadinessCopy.itemCopySummaryWorks,
      ]);

      expect(report.warnings.map((w) => w.text), [
        BetaReadinessCopy.warningAppStoreProducts,
        BetaReadinessCopy.warningLocalBackupPlainJson,
        BetaReadinessCopy.warningArchiveLocalUnlessExport,
      ]);
    });

    test('visible copy blocks avoid transcript text', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final blocks = BetaReadinessEngine.build().visibleCopyBlocks
          .join('\n')
          .toLowerCase();
      expect(blocks, isNot(contains('transcript:')));
      expect(
        blocks.split('\n').where((line) => line.contains(' said ')),
        isEmpty,
      );
    });

    test('build does not mutate archive', () async {
      final before = await AppServices.instance.journalStore.loadAll();
      BetaReadinessEngine.build();
      final after = await AppServices.instance.journalStore.loadAll();
      expect(after.length, before.length);
    });

    test('engine source avoids seeding or fake journal entries', () {
      const enginePath =
          'lib/features/beta_readiness/beta_readiness_engine.dart';
      final source = File(enginePath).readAsStringSync().toLowerCase();
      expect(source.contains('journalstore.save'), isFalse);
      expect(source.contains('seed'), isFalse);
      expect(source.contains('fake'), isFalse);
      expect(source.contains('journalentry('), isFalse);
    });
  });

  group('BetaReadinessAnalytics', () {
    test('opened emits source only', () {
      BetaReadinessAnalytics.opened(source: 'testing_archiveme_screen');
      final event = analyticsEvents.single;
      expect(event.event, BetaReadinessAnalytics.openedEvent);
      expect(event.props.keys.toSet(), {'source'});
      expect(event.props['source'], 'testing_archiveme_screen');
    });
  });

  group('TestingArchiveMeScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TestingArchiveMeScreen(),
        ),
      );
      await tester.pump();
    }

    testWidgets('readiness tile appears when beta flag enabled', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);
      expect(
        find.byKey(const Key('testing_archiveme_beta_readiness_check')),
        findsOneWidget,
      );
      expect(find.text(BetaReadinessCopy.openLink), findsOneWidget);
    });

    testWidgets('readiness tile hidden when beta flag disabled', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await pumpScreen(tester);
      expect(
        find.byKey(const Key('testing_archiveme_beta_readiness_check')),
        findsNothing,
      );
      expect(find.text(BetaReadinessCopy.openLink), findsNothing);
    });

    testWidgets('sheet opens with sections and warnings', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        find.byKey(const Key('testing_archiveme_beta_readiness_check')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const Key('testing_archiveme_beta_readiness_check')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beta_readiness_check_sheet')),
        findsOneWidget,
      );
      expect(find.text(BetaReadinessCopy.sectionCapture), findsOneWidget);
      expect(find.text(BetaReadinessCopy.sectionFirstProof), findsOneWidget);
      expect(find.text(BetaReadinessCopy.sectionTrustControls), findsOneWidget);
      expect(find.text(BetaReadinessCopy.sectionReturnLoop), findsOneWidget);
      expect(find.text(BetaReadinessCopy.sectionBetaFeedback), findsOneWidget);
      expect(
        find.text(BetaReadinessCopy.sectionReleaseWarnings),
        findsOneWidget,
      );
      expect(
        find.text(BetaReadinessCopy.warningAppStoreProducts),
        findsOneWidget,
      );
      expect(
        find.text(BetaReadinessCopy.warningLocalBackupPlainJson),
        findsOneWidget,
      );
      expect(
        find.text(BetaReadinessCopy.warningArchiveLocalUnlessExport),
        findsOneWidget,
      );
      expect(
        find.text(BetaReadinessCopy.itemExportLocalBackupAvailable),
        findsOneWidget,
      );
      expect(
        find.text(BetaReadinessCopy.itemRestoreLocalBackupAvailable),
        findsOneWidget,
      );

      final event = analyticsEvents.single;
      expect(event.event, BetaReadinessAnalytics.openedEvent);
      expect(event.props['source'], 'testing_archiveme_screen');
    });
  });

  group('Protected areas', () {
    test('beta readiness files avoid billing signing and backend surfaces', () {
      const banned = [
        'RevenueCat',
        'Purchases.',
        'CFBundleVersion',
        'signing',
        'product_id',
        'api.archive',
      ];
      final files = [
        'lib/features/beta_readiness/beta_readiness_model.dart',
        'lib/features/beta_readiness/beta_readiness_engine.dart',
        'lib/features/beta_readiness/beta_readiness_analytics.dart',
        'lib/widgets/account/beta_readiness_check_sheet.dart',
        'packages/archiveme_research/lib/screens/testing_archiveme_screen.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });

    test('copy avoids unsupported encryption claims', () {
      for (final line in BetaReadinessCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('encrypted backup')));
        expect(lower, isNot(contains('cloud sync')));
      }
    });
  });
}
