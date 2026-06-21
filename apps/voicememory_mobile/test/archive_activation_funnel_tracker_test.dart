import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_activation_funnel_store.dart';
import 'package:voicememory_mobile/features/beta/archive_activation_funnel_tracker.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_evidence_dashboard.dart';
import 'package:voicememory_mobile/features/debug/archive_beta_debug_gate.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

final _now = DateTime.utc(2026, 6, 15, 12);

ArchiveActivationFunnelEvent _event(
  ArchiveActivationFunnelEventType type, {
  int index = 0,
  String? entryId,
  String? mapId,
  String? proofId,
  String? source,
  Map<String, String> metadata = const {},
}) {
  return ArchiveActivationFunnelEvent(
    id: 'aaf_test_$index',
    createdAt: _now.add(Duration(minutes: index)),
    type: type,
    entryId: entryId,
    mapId: mapId,
    proofId: proofId,
    source: source,
    metadata: metadata,
  );
}

Future<MobilePrefsStore> _prefs(String stamp) async {
  final path = '/tmp/vm_activation_funnel_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  return MobilePrefsStore.open(path);
}

List<String> _captureLogs(void Function() body) {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return logs;
}

void main() {
  tearDown(() {
    ArchiveAppReviewAccessGate.resetForTest();
    ArchiveActivationFunnelPlacement.blockForTest = null;
    ArchiveActivationFunnelCoordinator.resetSessionForTest();
    ArchiveBetaDebugGate.resetForTest();
    ArchiveBetaEvidenceDashboardPlacement.blockForTest = null;
  });

  group('ArchiveActivationFunnelStore', () {
    test('events save correctly', () async {
      final prefs = await _prefs('save');
      final store = ArchiveActivationFunnelStore(prefs);
      final event = _event(ArchiveActivationFunnelEventType.firstRecordingStarted);
      await store.track(event);
      final all = await store.all();
      expect(all, hasLength(1));
      expect(all.first.type, ArchiveActivationFunnelEventType.firstRecordingStarted);
      expect(all.first.id, event.id);
    });

    test('summary computes counts', () async {
      final prefs = await _prefs('counts');
      final store = ArchiveActivationFunnelStore(prefs);
      await store.track(_event(ArchiveActivationFunnelEventType.mapSurfaceShown, index: 0));
      await store.track(
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 1),
      );
      await store.track(
        _event(ArchiveActivationFunnelEventType.firstRecordingCompleted, index: 2),
      );
      await store.track(
        _event(ArchiveActivationFunnelEventType.thirdRecordingCompleted, index: 3),
      );
      await store.track(_event(ArchiveActivationFunnelEventType.fullMapShown, index: 4));

      final summary = await store.summary();
      expect(summary.totalEvents, 5);
      expect(summary.mapSurfaceShownCount, 1);
      expect(summary.firstRecordingStartedCount, 1);
      expect(summary.firstRecordingCompletedCount, 1);
      expect(summary.thirdRecordingCompletedCount, 1);
      expect(summary.fullMapShownCount, 1);
    });

    test('first recording completion rate is correct', () {
      final summary = ArchiveActivationFunnelSummaryResolver.summarize([
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 0),
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 1),
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 2),
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 3),
        _event(ArchiveActivationFunnelEventType.firstRecordingCompleted, index: 4),
        _event(ArchiveActivationFunnelEventType.firstRecordingCompleted, index: 5),
        _event(ArchiveActivationFunnelEventType.firstRecordingCompleted, index: 6),
      ]);
      expect(summary.firstRecordingCompletionRate, closeTo(0.75, 0.001));
    });

    test('three recording completion rate is correct', () {
      final events = <ArchiveActivationFunnelEvent>[];
      for (var i = 0; i < 10; i++) {
        events.add(
          _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: i),
        );
      }
      for (var i = 0; i < 6; i++) {
        events.add(
          _event(
            ArchiveActivationFunnelEventType.thirdRecordingCompleted,
            index: 100 + i,
          ),
        );
      }
      final summary = ArchiveActivationFunnelSummaryResolver.summarize(events);
      expect(summary.threeRecordingCompletionRate, closeTo(0.60, 0.001));
    });

    test('full map reach rate is correct', () {
      final events = <ArchiveActivationFunnelEvent>[];
      for (var i = 0; i < 8; i++) {
        events.add(
          _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: i),
        );
      }
      for (var i = 0; i < 4; i++) {
        events.add(
          _event(ArchiveActivationFunnelEventType.fullMapShown, index: 50 + i),
        );
      }
      final summary = ArchiveActivationFunnelSummaryResolver.summarize(events);
      expect(summary.fullMapReachRate, closeTo(0.50, 0.001));
    });

    test('strongest drop-off detects first-preview-to-second-recording drop', () {
      final summary = ArchiveActivationFunnelSummaryResolver.summarize([
        _event(ArchiveActivationFunnelEventType.firstPreviewShown, index: 0),
        _event(ArchiveActivationFunnelEventType.firstPreviewShown, index: 1),
        _event(ArchiveActivationFunnelEventType.firstPreviewShown, index: 2),
        _event(ArchiveActivationFunnelEventType.firstPreviewShown, index: 3),
        _event(ArchiveActivationFunnelEventType.secondRecordingStarted, index: 4),
      ]);
      expect(
        summary.strongestDropOffLabel,
        ArchiveActivationFunnelSummaryResolver.dropOffPreviewNoSecond,
      );
    });

    test('activation readiness labels work', () {
      final tooEarly = ArchiveActivationFunnelSummaryResolver.summarize([
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 0),
      ]);
      expect(
        tooEarly.activationReadinessLabel,
        ArchiveActivationFunnelSummaryResolver.tooEarlyLabel,
      );

      final weakEvents = <ArchiveActivationFunnelEvent>[];
      for (var i = 0; i < 12; i++) {
        weakEvents.add(
          _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: i),
        );
      }
      for (var i = 0; i < 3; i++) {
        weakEvents.add(
          _event(
            ArchiveActivationFunnelEventType.thirdRecordingCompleted,
            index: 50 + i,
          ),
        );
      }
      final weak = ArchiveActivationFunnelSummaryResolver.summarize(weakEvents);
      expect(
        weak.activationReadinessLabel,
        ArchiveActivationFunnelSummaryResolver.weakLabel,
      );

      final promisingEvents = <ArchiveActivationFunnelEvent>[];
      for (var i = 0; i < 12; i++) {
        promisingEvents.add(
          _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: i),
        );
      }
      for (var i = 0; i < 7; i++) {
        promisingEvents.add(
          _event(
            ArchiveActivationFunnelEventType.thirdRecordingCompleted,
            index: 50 + i,
          ),
        );
        promisingEvents.add(
          _event(ArchiveActivationFunnelEventType.fullMapShown, index: 100 + i),
        );
      }
      final promising =
          ArchiveActivationFunnelSummaryResolver.summarize(promisingEvents);
      expect(
        promising.activationReadinessLabel,
        ArchiveActivationFunnelSummaryResolver.promisingLabel,
      );

      final strongEvents = <ArchiveActivationFunnelEvent>[];
      for (var i = 0; i < 12; i++) {
        strongEvents.add(
          _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: i),
        );
      }
      for (var i = 0; i < 9; i++) {
        strongEvents.add(
          _event(
            ArchiveActivationFunnelEventType.thirdRecordingCompleted,
            index: 50 + i,
          ),
        );
        strongEvents.add(
          _event(ArchiveActivationFunnelEventType.fullMapShown, index: 100 + i),
        );
      }
      final strong = ArchiveActivationFunnelSummaryResolver.summarize(strongEvents);
      expect(
        strong.activationReadinessLabel,
        ArchiveActivationFunnelSummaryResolver.strongLabel,
      );
    });

    test('export contains expected columns', () async {
      final prefs = await _prefs('export');
      final store = ArchiveActivationFunnelStore(prefs);
      await store.track(
        _event(
          ArchiveActivationFunnelEventType.guidedPromptSelected,
          index: 0,
          entryId: 'entry_1',
          source: 'onboarding',
          metadata: const {'promptId': 'p1'},
        ),
      );
      final rows = await store.exportCsvRows();
      expect(rows.first, [
        'createdAt',
        'type',
        'entryId',
        'mapId',
        'proofId',
        'source',
        'metadata',
      ]);
      expect(rows, hasLength(2));
      expect(rows[1][1], 'guidedPromptSelected');
      expect(rows[1][2], 'entry_1');
      expect(rows[1][5], 'onboarding');
      expect(rows[1][6], contains('promptId=p1'));
    });
  });

  group('ArchiveBetaEvidenceDashboard funnel integration', () {
    test('dashboard uses funnel summary instead of Not tracked yet', () async {
      final prefs = await _prefs('dashboard');
      final store = ArchiveActivationFunnelStore(prefs);
      await store.track(
        _event(ArchiveActivationFunnelEventType.firstRecordingStarted, index: 0),
      );
      await store.track(
        _event(ArchiveActivationFunnelEventType.firstRecordingCompleted, index: 1),
      );
      await store.track(
        _event(ArchiveActivationFunnelEventType.thirdRecordingCompleted, index: 2),
      );
      await store.track(_event(ArchiveActivationFunnelEventType.fullMapShown, index: 3));

      final dashboard = await ArchiveBetaEvidenceDashboardLoader.load(
        prefs: prefs,
        now: _now,
      );
      final activation = dashboard.activationSummary;
      expect(activation.hasFunnelData, isTrue);
      expect(activation.completedFirstRecordingCount, 1);
      expect(activation.completedThreeRecordingsCount, 1);
      expect(activation.sawFirstMapCount, 1);
      expect(activation.strongestDropOffLabel, isNot('Not tracked yet'));
      expect(activation.firstRecordingCompletionRate, closeTo(1.0, 0.001));
    });
  });

  group('ArchiveActivationFunnelPlacement', () {
    test('debug export hidden in App Review mode', () {
      ArchiveAppReviewAccessGate.enabledOverride = true;
      ArchiveBetaDebugGate.visibleOverride = true;
      expect(ArchiveActivationFunnelPlacement.shouldTrack(), isFalse);
      expect(ArchiveBetaEvidenceDashboardPlacement.shouldShow(), isFalse);
    });

    test('debug export hidden in release smoke', () {
      ArchiveActivationFunnelPlacement.blockForTest = true;
      ArchiveBetaEvidenceDashboardPlacement.blockForTest = true;
      ArchiveBetaDebugGate.visibleOverride = true;
      expect(ArchiveActivationFunnelPlacement.shouldTrack(), isFalse);
      expect(ArchiveBetaEvidenceDashboardPlacement.shouldShow(), isFalse);
    });
  });

  group('ArchiveActivationFunnel compliance', () {
    test('no RevenueCat or purchase logic changed in funnel modules', () {
      final sources = [
        File('lib/features/beta/archive_activation_funnel_tracker.dart'),
        File('lib/features/beta/archive_activation_funnel_store.dart'),
      ];
      for (final file in sources) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('RevenueCat')));
        expect(text, isNot(contains('purchases_flutter')));
        expect(text, isNot(contains('purchasePackage')));
      }
    });

    test('no diagnostic or therapy language introduced', () {
      final sources = [
        File('lib/features/beta/archive_activation_funnel_tracker.dart'),
        File('lib/features/beta/archive_activation_funnel_store.dart'),
        File('lib/widgets/beta/archive_beta_evidence_dashboard_card.dart'),
      ];
      for (final file in sources) {
        final text = file.readAsStringSync().toLowerCase();
        expect(text, isNot(contains('therapy')));
        expect(text, isNot(contains('diagnosis')));
        expect(text, isNot(contains('diagnose')));
      }
    });

    test('debug export key is registered behind beta gate', () {
      expect(
        ArchiveBetaDebugGate.debugControlKeys,
        contains('debug_export_activation_funnel'),
      );
    });

    test('logs use approved hygiene', () {
      final logs = _captureLogs(() {
        ArchiveActivationFunnelLog.event(
          type: ArchiveActivationFunnelEventType.firstRecordingStarted,
        );
        ArchiveActivationFunnelLog.summaryReady(readiness: 'Too early');
        ArchiveActivationFunnelLog.exportTapped();
      });
      for (final line in logs) {
        expect(line, isNot(contains('{{')));
        expect(line, isNot(contains('null')));
      }
      expect(
        logs.any((l) => l.contains('ARCHIVEME_ACTIVATION_FUNNEL_EVENT')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('ARCHIVEME_ACTIVATION_FUNNEL_SUMMARY_READY')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('ARCHIVEME_ACTIVATION_FUNNEL_EXPORT_TAPPED')),
        isTrue,
      );
    });
  });
}
