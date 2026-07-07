import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_engine.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_exporter.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/product/testflight_invite_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

const _bannedFragments = [
  'VoiceMemory listens',
  'VoiceMemory gets clearer',
  'VoiceMemory tracks',
  'VoiceMemory notices',
  'VoiceMemory connects',
  'Today VoiceMemory',
  'VoiceMemory Pro',
  'Cloud processing pending',
  'Cloud sync is unavailable',
  'Anything else connected to',
  'I want freedom',
  'I talk about achievement',
  'A pattern that used to drive me',
  'diagnosis',
  'therapy',
  'coach',
  'AI friend',
];

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_invite_journal_$stamp.json',
    prefsPath: '/tmp/vm_invite_prefs_$stamp.json',
  );
}

void _expectNoBanned(String text) {
  for (final fragment in _bannedFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason: 'Found banned fragment: $fragment',
    );
  }
}

void main() {
  group('loop acquisition copy', () {
    test('has prove, capacity, and generic variants with prove first', () {
      expect(LoopAcquisitionCopy.all, hasLength(3));
      expect(LoopAcquisitionCopy.all.first.id, 'prove_enough');
      expect(LoopAcquisitionCopy.capacityYes.id, 'capacity_yes');
      expect(LoopAcquisitionCopy.generic.id, 'generic');
    });

    test('capacity variant includes required fields', () {
      final v = LoopAcquisitionCopy.capacityYes;
      expect(v.headline, contains('Catch the yes before it costs you'));
      expect(v.subheadline, contains('before checking your capacity'));
      expect(v.bullets, hasLength(3));
      expect(v.cta, 'Save yes moment');
    });

    test('prove variant includes required fields', () {
      final v = LoopAcquisitionCopy.proveEnough;
      expect(v.headline, contains('do more to feel enough'));
      expect(v.bullets, hasLength(4));
      expect(v.cta, contains('proving-enough'));
    });

    test('generic variant uses landing alignment headline', () {
      final v = LoopAcquisitionCopy.generic;
      expect(v.headline, 'See what keeps returning');
      expect(v.subheadline.toLowerCase(), contains('keeps returning'));
      expect(v.cta, 'Start with one moment');
      expect(v.bullets, isEmpty);
    });

    test('forId resolves variants', () {
      expect(LoopAcquisitionCopy.forId('capacity_yes'), isNotNull);
      expect(LoopAcquisitionCopy.forId('unknown'), isNull);
    });
  });

  group('TestFlight invite copy', () {
    test('includes tester tasks for capacity and prove', () {
      expect(
        TestFlightInviteCopy.testerTask(TestFlightInviteVariant.capacityYes),
        contains('said yes before checking capacity'),
      );
      expect(
        TestFlightInviteCopy.testerTask(TestFlightInviteVariant.proveEnough),
        contains('stopping felt uncomfortable'),
      );
    });

    test('short and long text include ArchiveMe', () {
      for (final variant in TestFlightInviteVariant.values) {
        expect(TestFlightInviteCopy.shortText(variant), contains('ArchiveMe'));
        expect(TestFlightInviteCopy.longText(variant), contains('ArchiveMe'));
      }
    });

    test('clipboard pack includes task and route', () {
      final pack = TestFlightInviteCopy.clipboardPack(
        TestFlightInviteVariant.capacityYes,
      );
      expect(pack, contains('Tester task:'));
      expect(pack, contains('/start/capacity-yes'));
      expect(pack, contains(TestFlightInviteCopy.cohortRouteLabel));
    });

    test('invite copy does not contain banned strings', () {
      for (final variant in TestFlightInviteVariant.values) {
        _expectNoBanned(TestFlightInviteCopy.shortText(variant));
        _expectNoBanned(TestFlightInviteCopy.longText(variant));
        _expectNoBanned(TestFlightInviteCopy.testerTask(variant));
        _expectNoBanned(TestFlightInviteCopy.clipboardPack(variant));
      }
      for (final variant in LoopAcquisitionCopy.all) {
        _expectNoBanned(variant.headline);
        _expectNoBanned(variant.subheadline);
        _expectNoBanned(variant.cta);
        for (final bullet in variant.bullets) {
          _expectNoBanned(bullet);
        }
      }
    });
  });

  group('cohort links', () {
    test('generates safe internal route paths', () {
      expect(
        TestFlightInviteCopy.cohortRouteFor(
          TestFlightInviteVariant.capacityYes,
        ),
        '/start/capacity-yes',
      );
      expect(
        TestFlightInviteCopy.cohortRouteFor(
          TestFlightInviteVariant.proveEnough,
        ),
        '/start/prove-enough',
      );
      expect(
        TestFlightInviteCopy.cohortRouteFor(TestFlightInviteVariant.generic),
        '/start/prove-enough',
      );
    });

    test('route label marks internal TestFlight helper', () {
      expect(
        TestFlightInviteCopy.cohortRouteLabel,
        contains('Internal TestFlight'),
      );
      expect(
        TestFlightInviteCopy.shortText(TestFlightInviteVariant.capacityYes),
        isNot(contains('archiveMe://')),
      );
    });

    test('landing variants expose cohort route paths', () {
      expect(
        LoopAcquisitionCopy.capacityYes.cohortRoutePath,
        '/start/capacity-yes',
      );
      expect(
        LoopAcquisitionCopy.proveEnough.cohortRoutePath,
        '/start/prove-enough',
      );
    });
  });

  group('invite copied counters', () {
    test('increment and appear in trial export', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.capacityInviteCopied,
      );
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveInviteCopied,
      );
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.genericInviteCopied,
      );

      final summary = await const TrialSummaryEngine().build();
      expect(summary.capacityInviteCopiedCount, greaterThanOrEqualTo(1));
      expect(summary.proveInviteCopiedCount, greaterThanOrEqualTo(1));
      expect(summary.genericInviteCopiedCount, greaterThanOrEqualTo(1));

      final markdown = const TrialSummaryExporter().toMarkdown(summary);
      expect(markdown, contains('## Tester invite copy'));
      expect(markdown, contains('Capacity invite copied'));
    });

    test('activation tracker invite methods increment metrics', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      ActivationTracker.trackCapacityInviteCopied();
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.capacityInviteCopied,
      );

      final count = await RetentionMetricsStore.instance().count(
        RetentionMetricsTracker.capacityInviteCopied,
      );
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Trial Control invite section', () {
    test('invite button labels match Trial Control copy', () {
      expect(
        TestFlightInviteCopy.clipboardPack(TestFlightInviteVariant.capacityYes),
        contains('yes before checking capacity'),
      );
      expect(
        TestFlightInviteCopy.clipboardPack(TestFlightInviteVariant.proveEnough),
        contains('proving-enough'),
      );
      expect(
        TestFlightInviteCopy.clipboardPack(TestFlightInviteVariant.generic),
        contains('keeps returning'),
      );
    });
  });
}
