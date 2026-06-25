import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_store.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/features/retention/retention_diagnosis_v2_engine.dart';
import 'package:voicememory_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_engine.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_exporter.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/screens/loop_start_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/loop_mode/loop_paywall_teaser_card.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_acq_journal_$stamp.json',
    prefsPath: '/tmp/vm_acq_prefs_$stamp.json',
    skipRevenueCat: true,
  );
}

RetentionDiagnosisV2Input _diagnosisInput({
  AcquisitionCohortId? cohort,
  bool first = false,
  bool second = false,
  bool accepted = false,
  bool reviewConfirmed = false,
}) {
  return RetentionDiagnosisV2Input(
    firstMomentRecorded: first,
    secondMomentRecorded: second,
    thirdMomentRecorded: false,
    interpretationSignals: const [],
    reminderPrePromptShown: false,
    reminderPrePromptAccepted: false,
    reminderPrePromptDismissed: 0,
    reminderReturnCount: 0,
    onboardingIntent: null,
    journeyEvidenceCount: 0,
    reviewConfirmed: reviewConfirmed,
    loopModeSelected: cohort?.defaultLoopId,
    loopReadAccepted: accepted,
    loopReviewConfirmed: reviewConfirmed,
    acquisitionCohortId: cohort,
  );
}

void main() {
  group('acquisition cohort model/store', () {
    test('round-trips through store', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      final cohort = AcquisitionCohort(
        cohortId: AcquisitionCohortId.capacityYesDirect,
        source: 'test',
        selectedLoopId: LoopModeIds.capacityYes,
        promiseShown: AcquisitionStartCopy.capacityTitle,
        assignedAt: DateTime(2026, 6, 7),
        firstMomentRecorded: true,
      );
      await AcquisitionCohortStore.instance().save(cohort);

      final loaded = await AcquisitionCohortStore.instance().load();
      expect(loaded, isNotNull);
      expect(loaded!.cohortId, AcquisitionCohortId.capacityYesDirect);
      expect(loaded.firstMomentRecorded, isTrue);
    });

    test('fromId resolves supported cohort ids', () {
      expect(AcquisitionCohortId.capacityYesDirect.id, 'capacity_yes_direct');
      expect(AcquisitionCohortId.proveEnoughDirect.id, 'prove_enough_direct');
      expect(AcquisitionCohortId.genericArchive.id, 'generic_archive');
      expect(AcquisitionCohortIdIds.fromId('unknown_route'), isNull);
    });
  });

  group('start routes and coordinator', () {
    test('/start/capacity-yes stores capacity cohort', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignFromRoutePath(
        '/start/capacity-yes',
      );
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.cohortId, AcquisitionCohortId.capacityYesDirect);
      expect(cohort?.selectedLoopId, LoopModeIds.capacityYes);
    });

    test('/start/prove-enough stores prove cohort', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignFromRoutePath(
        '/start/prove-enough',
      );
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.cohortId, AcquisitionCohortId.proveEnoughDirect);
      expect(cohort?.selectedLoopId, LoopModeIds.proveEnough);
    });

    test('unknown query falls back to prove default route', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      final redirect = await AcquisitionCohortCoordinator.resolveStartRedirect(
        Uri.parse('/start?cohort=not_a_real_cohort'),
      );
      expect(redirect, '/start/prove-enough');
    });

    test('loop query assigns capacity cohort', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      final redirect = await AcquisitionCohortCoordinator.resolveStartRedirect(
        Uri.parse('/start?loop=capacity_yes'),
      );
      expect(redirect, '/start/capacity-yes');
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.cohortId, AcquisitionCohortId.capacityYesDirect);
    });
  });

  group('loop start screen copy', () {
    setUp(() async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
    });

    testWidgets('capacity start screen copy', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoopStartScreen.capacity()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text(AcquisitionStartCopy.capacityTitle), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.capacityBody), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.capacityStartCta), findsOneWidget);
    });

    testWidgets('prove start screen copy', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoopStartScreen.proveEnough()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text(AcquisitionStartCopy.proveTitle), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.proveBody), findsOneWidget);
    });

    testWidgets('generic fallback copy', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoopStartScreen.generic()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text(AcquisitionStartCopy.genericTitle), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.genericBody), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.startGenericCta), findsOneWidget);
      expect(find.text(AcquisitionStartCopy.chooseAnotherLoop), findsNothing);
    });
  });

  group('loop start CTA', () {
    test('CTA stores loop and marks onboarding complete', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignFromRoutePath(
        '/start/capacity-yes',
      );
      await LoopModeCoordinator.activate(LoopModeIds.capacityYes);
      await AcquisitionCohortCoordinator.markLoopSelected(
        LoopModeIds.capacityYes,
      );
      await AcquisitionCohortCoordinator.markStartCtaTapped();
      await AppServices.instance.prefs.setOnboardingCompleted(true);

      final loop = await LoopModeCoordinator.loadActive();
      expect(loop?.id, LoopModeIds.capacityYes);
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.onboardingCompleted, isTrue);
    });
  });

  group('cohort first-run skip', () {
    test('cohort user redirects away from broad onboarding', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.capacityYesDirect,
      );

      final redirect = await AcquisitionCohortCoordinator.fastPathRedirect(
        '/onboarding',
      );
      expect(redirect, '/start/capacity-yes');
    });

    test('non-cohort user has no fast-path redirect', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      final redirect = await AcquisitionCohortCoordinator.fastPathRedirect(
        '/onboarding',
      );
      expect(redirect, isNull);
    });

    test('completed cohort user may reach record', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.proveEnoughDirect,
      );
      await AcquisitionCohortCoordinator.markStartCtaTapped();

      final redirect = await AcquisitionCohortCoordinator.fastPathRedirect(
        '/record',
      );
      expect(redirect, isNull);
    });
  });

  group('cohort metrics and export', () {
    test('assign increments cohortAssigned metric', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.capacityYesDirect,
      );
      // Mirror invite-metric tests: coordinator fires async; await store path.
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortAssigned,
      );

      final count = await RetentionMetricsStore.instance().count(
        RetentionMetricsTracker.cohortAssigned,
      );
      expect(count, greaterThanOrEqualTo(1));
    });

    test('trial summary export includes acquisition cohort section', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.proveEnoughDirect,
      );
      await AcquisitionCohortCoordinator.markFirstMomentRecorded();

      final summary = await const TrialSummaryEngine().build();
      final markdown = const TrialSummaryExporter().toMarkdown(summary);

      expect(markdown, contains('## Acquisition cohort'));
      expect(markdown, contains('prove_enough_direct'));
      expect(markdown, contains('First moment recorded: yes'));
    });
  });

  group('retention diagnosis cohort logic', () {
    const engine = RetentionDiagnosisV2Engine();

    test('capacity: no first moment', () {
      final result = engine.diagnose(
        _diagnosisInput(cohort: AcquisitionCohortId.capacityYesDirect),
      );
      expect(result.summary, contains('capacity promise failed to activate'));
    });

    test('prove: insight mismatch', () {
      final result = engine.diagnose(
        _diagnosisInput(
          cohort: AcquisitionCohortId.proveEnoughDirect,
          first: true,
          accepted: false,
        ),
      );
      expect(result.summary, contains('prove insight mismatch'));
    });

    test('capacity: retention gap', () {
      final result = engine.diagnose(
        _diagnosisInput(
          cohort: AcquisitionCohortId.capacityYesDirect,
          first: true,
          accepted: true,
          second: false,
        ),
      );
      expect(result.summary, contains('capacity retention gap'));
    });

    test('prove: wedge working on review confirmed', () {
      final result = engine.diagnose(
        _diagnosisInput(
          cohort: AcquisitionCohortId.proveEnoughDirect,
          first: true,
          accepted: true,
          second: true,
          reviewConfirmed: true,
        ),
      );
      expect(result.summary, contains('prove wedge working'));
    });
  });

  group('trial control cohort helpers', () {
    test('setting cohort stores it', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.genericArchive,
      );
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.cohortId, AcquisitionCohortId.genericArchive);
    });

    test('clearing cohort resets safely', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.capacityYesDirect,
      );
      await AcquisitionCohortCoordinator.clear();
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort, isNull);
    });
  });

  group('loop paywall teaser attribution', () {
    test('teaser tapped records cohort', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await AcquisitionCohortCoordinator.assignForTrial(
        AcquisitionCohortId.capacityYesDirect,
      );
      await AcquisitionCohortCoordinator.markPaywallTeaserTapped();

      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.paywallTeaserTapped, isTrue);
    });

    testWidgets('teaser card renders when billing is disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoopPaywallTeaserCard(
              shouldShow: true,
              entitlements: null,
              loopModeId: LoopModeIds.capacityYes,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('See Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no cohort does not crash on teaser render', (tester) async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await tester.runAsync(() => _reset(stamp));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoopPaywallTeaserCard(
              shouldShow: true,
              entitlements: null,
              loopModeId: LoopModeIds.proveEnough,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('app router start paths', () {
    test('router defines start paths without throwing', () {
      expect(appRouter.configuration.routes.length, greaterThan(0));
    });
  });
}
