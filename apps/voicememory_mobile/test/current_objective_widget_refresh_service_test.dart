import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/objective/current_objective_model.dart';
import 'package:voicememory_mobile/features/objective/current_objective_snapshot_store.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_bridge.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_refresh_service.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_snapshot.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _FakeBridge implements CurrentObjectiveWidgetBridge {
  bool available = true;
  bool throwOnUpdate = false;
  Map<String, String>? lastPayload;
  int updateCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount++;
  }

  @override
  Future<String> consumePendingWidgetRoute() async => '';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> update(Map<String, String> payload) async {
    if (throwOnUpdate) throw Exception('bridge failed');
    updateCount++;
    lastPayload = payload;
  }
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_widget_refresh_journal_$stamp.json',
    prefsPath: '/tmp/vm_widget_refresh_prefs_$stamp.json',
  );
  CurrentObjectiveWidgetRefreshService.resetInstanceForTest();
}

void main() {
  test('refresh service updates fake bridge from snapshot', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final prefs = AppServices.instance.prefs;
    final store = CurrentObjectiveSnapshotStore(prefs);
    final bridge = _FakeBridge();
    final service = CurrentObjectiveWidgetRefreshService(
      snapshotStore: store,
      bridge: bridge,
    );

    await store.saveWidgetSnapshot(
      CurrentObjectiveWidgetSnapshot(
        title: 'Today\u2019s check',
        body: 'Answer the check you chose yesterday.',
        primaryActionLabel: 'Answer check',
        route: '/record',
        type: 'answerTodayCheck',
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );

    await service.refreshFromSnapshot();

    expect(bridge.updateCount, 1);
    expect(bridge.lastPayload?['title'], 'Today\u2019s check');
    final counts = await ActivationEventsStore(prefs).read();
    expect(counts.objectiveWidgetRefreshAttempted, 1);
    expect(counts.objectiveWidgetRefreshSucceeded, 1);
  });

  test('refresh service fails softly when bridge unavailable', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final prefs = AppServices.instance.prefs;
    final bridge = _FakeBridge()..available = false;
    final service = CurrentObjectiveWidgetRefreshService(
      snapshotStore: CurrentObjectiveSnapshotStore(prefs),
      bridge: bridge,
    );

    await service.refreshFromSnapshot();

    expect(bridge.updateCount, 0);
    final counts = await ActivationEventsStore(prefs).read();
    expect(counts.objectiveWidgetRefreshFailed, 1);
  });

  test('refresh service fails softly on bridge exception', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final prefs = AppServices.instance.prefs;
    final bridge = _FakeBridge()..throwOnUpdate = true;
    final service = CurrentObjectiveWidgetRefreshService(
      snapshotStore: CurrentObjectiveSnapshotStore(prefs),
      bridge: bridge,
    );

    await service.refreshWithObjective(
      const CurrentObjective(
        type: CurrentObjectiveType.answerTodayCheck,
        title: 'Today\u2019s check',
        body: 'Answer the check you chose yesterday.',
        primaryCtaLabel: 'Answer check',
        route: '/record',
      ),
    );

    final counts = await ActivationEventsStore(prefs).read();
    expect(counts.objectiveWidgetRefreshFailed, 1);
  });

  test('clearWidget calls bridge clear and tracks cleared', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final prefs = AppServices.instance.prefs;
    final store = CurrentObjectiveSnapshotStore(prefs);
    final bridge = _FakeBridge();
    final service = CurrentObjectiveWidgetRefreshService(
      snapshotStore: store,
      bridge: bridge,
    );

    await store.saveWidgetSnapshot(
      CurrentObjectiveWidgetSnapshot(
        title: 'Record a moment',
        body: 'Add one moment from today.',
        primaryActionLabel: 'Record moment',
        route: '/record',
        type: 'recordAnyMoment',
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );

    await service.clearWidget();

    expect(bridge.clearCount, 1);
    expect(await store.loadWidgetSnapshot(), isNull);
    final counts = await ActivationEventsStore(prefs).read();
    expect(counts.objectiveWidgetCleared, 1);
  });
}
