import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_store.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/first25/first25_user_metrics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'support/test_storage_sandbox.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/beta_loop/prefs.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<Map<String, dynamic>> updateMap(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>? current) update,
  ) async {
    final next = update(maps[key]);
    maps[key] = next;
    return next;
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void main() {
  late TestStorageSandbox sandbox;
  late _MemoryPrefs prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    prefs = _MemoryPrefs();
    prefs.maps.clear();
    BetaActivationLoopTracker.resetSessionForTest();
    await BetaActivationLoopTracker.clearCounts();
    EarlyArchiveProofAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/beta_loop/${DateTime.now().microsecondsSinceEpoch}_tear.json',
    );
  });

  group('BetaActivationLoopStore', () {
    test('increments and reads counts', () async {
      final store = BetaActivationLoopStore(prefs);
      await store.increment('firstMomentSaved');
      await store.increment('firstMomentSaved');

      final counts = await store.read();
      expect(counts.firstMomentSaved, 2);
      expect(counts.secondMomentSaved, 0);
    });
  });

  group('BetaActivationLoopTracker', () {
    test('session dedupe prevents duplicate seen counts', () async {
      await BetaActivationLoopTracker.trackAppOpened();
      await BetaActivationLoopTracker.trackAppOpened();
      await BetaActivationLoopTracker.trackRecordScreenSeen();
      await BetaActivationLoopTracker.trackRecordScreenSeen();

      final counts = await BetaActivationLoopTracker.readCounts();
      expect(counts.appOpened, 1);
      expect(counts.recordScreenSeen, 1);
    });

    test('save milestones increment each time they fire', () async {
      await BetaActivationLoopTracker.trackFirstMomentSaved();
      await BetaActivationLoopTracker.trackSecondMomentSaved();
      await BetaActivationLoopTracker.trackThirdMomentSaved();

      final counts = await BetaActivationLoopTracker.readCounts();
      expect(counts.firstMomentSaved, 1);
      expect(counts.secondMomentSaved, 1);
      expect(counts.thirdMomentSaved, 1);
    });

    test('summary text lists all loop counters', () {
      const counts = BetaActivationLoopCounts(
        appOpened: 3,
        firstMomentSaved: 1,
        confirmedRepeatSeen: 1,
      );
      final summary = counts.toSummaryText();
      expect(summary, contains('App opened: 3'));
      expect(summary, contains('First moment saved: 1'));
      expect(summary, contains('Confirmed repeat seen: 1'));
    });

    test('clearCounts resets persisted values', () async {
      await BetaActivationLoopTracker.trackFirstMomentSaved();
      await BetaActivationLoopTracker.clearCounts();

      final counts = await BetaActivationLoopTracker.readCounts();
      expect(counts.firstMomentSaved, 0);
    });
  });

  group('Existing analytics bridges', () {
    test('early archive proof forwards one-entry and related states', () async {
      BetaActivationLoopTracker.resetSessionForTest();
      await BetaActivationLoopTracker.clearCounts();
      EarlyArchiveProofAnalytics.resetForTest();
      EarlyArchiveProofAnalytics.heardReceiptSeen(
        entryCount: 1,
        surface: 'record',
      );
      EarlyArchiveProofAnalytics.heardReceiptSeen(
        entryCount: 1,
        surface: 'record',
      );
      EarlyArchiveProofAnalytics.possiblePatternSeen(
        entryCount: 2,
        surface: 'record',
      );
      EarlyArchiveProofAnalytics.confirmedRepeatSeen(
        entryCount: 3,
        surface: 'record',
      );
      BetaActivationLoopCounts counts =
          await BetaActivationLoopTracker.readCounts();
      for (
        var i = 0;
        i < 50 &&
            (counts.oneEntryReturnScreenSeen == 0 ||
                counts.twoEntryRelatedSeen == 0 ||
                counts.confirmedRepeatSeen == 0);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        counts = await BetaActivationLoopTracker.readCounts();
      }

      expect(counts.oneEntryReturnScreenSeen, 1);
      expect(counts.twoEntryRelatedSeen, 1);
      expect(counts.confirmedRepeatSeen, 1);
    });

    test('first25 paywall hooks increment beta loop counters', () async {
      await First25UserMetrics.trackPaywallSeen(surface: 'paywall_screen');
      await First25UserMetrics.trackPaywallStarted(
        surface: 'paywall_screen',
        period: 'annual',
      );
      await Future<void>.delayed(Duration.zero);

      final counts = await BetaActivationLoopTracker.readCounts();
      expect(counts.paywallSeen, 1);
      expect(counts.purchaseTapped, 1);
    });
  });
}
