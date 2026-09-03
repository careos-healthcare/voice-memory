import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/product/loop_acquisition_copy.dart';
import 'package:archiveme_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_mobile/product/testflight_invite_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_prove_default_journal_$stamp.json',
    prefsPath: '/tmp/vm_prove_default_prefs_$stamp.json',
  );
}

void main() {
  group('prove_enough default wedge', () {
    test('onboarding has one welcome page before consent step', () {
      expect(OnboardingPages.pageCount, 1);
      expect(
        OnboardingPages.pages.first.title,
        ConsumerUiCopy.onboardingPositioningHeadline,
      );
      expect(
        ConsumerUiCopy.onboardingPositioningHeadline,
        'When it comes back, we show you the words.',
      );
    });

    test('loop acquisition copy lists prove_enough first', () {
      expect(LoopAcquisitionCopy.all.first.id, 'prove_enough');
      expect(LoopAcquisitionCopy.primaryWedge.isPrimaryWedge, isTrue);
    });

    test('intent wedges map to prove or capacity loops', () {
      expect(
        AudienceWedge.doingMoreToFeelEnough.mappedLoopId,
        LoopModeIds.proveEnough,
      );
      expect(
        AudienceWedge.sayingYesNoCapacity.mappedLoopId,
        LoopModeIds.capacityYes,
      );
      expect(AudienceWedge.notSureYet.mappedLoopId, LoopModeIds.proveEnough);
    });

    test('unknown deep link defaults to prove_enough cohort', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      final redirect = await AcquisitionCohortCoordinator.resolveStartRedirect(
        Uri.parse('/start'),
      );
      expect(redirect, '/start/prove-enough');
      final cohort = await AcquisitionCohortCoordinator.load();
      expect(cohort?.selectedLoopId, LoopModeIds.proveEnough);
    });

    test('prove default metrics increment', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveDefaultShown,
      );
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveDefaultStarted,
      );

      final shown = await RetentionMetricsStore.instance().count(
        RetentionMetricsTracker.proveDefaultShown,
      );
      final started = await RetentionMetricsStore.instance().count(
        RetentionMetricsTracker.proveDefaultStarted,
      );
      expect(shown, 1);
      expect(started, 1);
    });

    test('invite copy leads with prove promise', () {
      final text = TestFlightInviteCopy.shortText(
        TestFlightInviteVariant.proveEnough,
      );
      expect(text, contains('ambitious people'));
      expect(text, contains('stopping makes them feel behind'));
    });
  });

  group('capacity regression', () {
    test('capacity_yes loop still activates', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await LoopModeCoordinator.activate(LoopModeIds.capacityYes);
      final loop = await LoopModeCoordinator.loadActive();
      expect(loop?.id, LoopModeIds.capacityYes);
      expect(loop?.title, isNot(contains('prove')));
    });

    test('capacity handoff copy unchanged', () {
      expect(
        LoopModeCopy.capacityHandoffTitle,
        'Catch the yes before it costs you.',
      );
      expect(LoopModeCopy.capacityHandoffCta, 'Save yes moment');
      expect(LoopModeCopy.capacityHandoffPrompt, contains('agree'));
    });

    test('prove handoff copy is default shape', () {
      expect(
        LoopModeCopy.proveEnoughHandoffTitle,
        'Catch your first proving loop',
      );
      expect(
        LoopModeCopy.proveEnoughHandoffPrompt,
        'When did you feel pressure to do more to feel okay?',
      );
      expect(LoopModeCopy.proveEnoughHandoffCta, 'Record this moment');
    });

    test('onboarding loop screen lists prove_enough first', () {
      expect(
        LoopModeCopy.proveEnoughTitle,
        'Trying to prove I am doing enough',
      );
      expect(
        LoopModeCopy.proveEnoughPromise,
        contains('stopping makes you feel behind'),
      );
    });
  });

  group('paywall teaser prove copy', () {
    test('prove paywall uses stronger headline and bullets', () {
      expect(
        LoopModeCopy.paywallHeadlineForLoop(LoopModeIds.proveEnough),
        'Keep tracking the loop over time',
      );
      expect(
        LoopModeCopy.paywallBulletsForLoop(LoopModeIds.proveEnough),
        contains('See whether effort comes from choice or pressure'),
      );
    });
  });
}
