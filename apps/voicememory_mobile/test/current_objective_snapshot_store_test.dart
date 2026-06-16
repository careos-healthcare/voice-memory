import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/objective/current_objective_model.dart';
import 'package:voicememory_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:voicememory_mobile/features/objective/current_objective_snapshot_store.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_bridge.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_refresh_service.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_snapshot.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _RecordingBridge implements CurrentObjectiveWidgetBridge {
  int updateCount = 0;
  Map<String, String>? lastPayload;

  @override
  Future<void> clear() async {}

  @override
  Future<String> consumePendingWidgetRoute() async => '';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> update(Map<String, String> payload) async {
    updateCount++;
    lastPayload = payload;
  }
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_objective_snap_journal_$stamp.json',
    prefsPath: '/tmp/vm_objective_snap_prefs_$stamp.json',
  );
}

void main() {
  test('snapshot stores and loads simple strings', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);

    await store.saveSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.answerTodayCheck,
        title: 'Today\u2019s check',
        body: 'Answer the check you chose yesterday.',
        checkQuestion: 'What happens right before it shows up?',
        primaryCtaLabel: 'Answer check',
        route: '/record',
      ),
    );

    final loaded = await store.loadSnapshot();
    expect(loaded?.title, 'Today\u2019s check');
    expect(loaded?.body, contains('Answer the check'));
    expect(loaded?.checkQuestion, isNotEmpty);
    expect(loaded?.route, '/record');
  });

  test('saveSnapshot also writes widget snapshot', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);

    await store.saveSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.answerTodayCheck,
        title: 'Today\u2019s check',
        body: 'Answer the check you chose yesterday.',
        checkQuestion: 'What happens right before it shows up?',
        primaryCtaLabel: 'Answer check',
        route: '/record',
      ),
    );

    final widgetSnapshot = await store.loadWidgetSnapshot();
    expect(widgetSnapshot, isNotNull);
    expect(widgetSnapshot!.title, 'Today\u2019s check');
    expect(widgetSnapshot.primaryActionLabel, 'Answer check');
    expect(widgetSnapshot.type, 'answerTodayCheck');
    expect(widgetSnapshot.route, '/record');
  });

  test('saveWidgetSnapshot and loadWidgetSnapshot roundtrip', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);

    final snapshot = CurrentObjectiveWidgetSnapshot(
      title: 'Record a moment',
      body: 'Add one moment from today.',
      primaryActionLabel: 'Record moment',
      route: '/record',
      type: 'recordAnyMoment',
      updatedAt: DateTime.utc(2026, 6, 6),
    );
    await store.saveWidgetSnapshot(snapshot);

    final loaded = await store.loadWidgetSnapshot();
    expect(loaded?.title, snapshot.title);
    expect(loaded?.type, snapshot.type);
    expect(loaded?.updatedAt, snapshot.updatedAt);
  });

  test('loadWidgetSnapshot returns null for bad JSON', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final prefs = AppServices.instance.prefs;
    await prefs.writeMap(CurrentObjectiveSnapshotStore.widgetSnapshotKey, {
      'title': 'Only title',
    });

    final store = CurrentObjectiveSnapshotStore(prefs);
    expect(await store.loadWidgetSnapshot(), isNull);
  });

  test('clearWidgetSnapshot removes widget snapshot only', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);

    await store.saveWidgetSnapshot(
      buildWidgetSnapshot(
        const CurrentObjective(
          type: CurrentObjectiveType.recordAnyMoment,
          title: 'Record a moment',
          body: 'Add one moment from today.',
          primaryCtaLabel: 'Record moment',
          route: '/record',
        ),
      ),
    );
    await store.clearWidgetSnapshot();
    expect(await store.loadWidgetSnapshot(), isNull);
  });

  test('saveSnapshot triggers widget refresh when bridge available', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    CurrentObjectiveWidgetRefreshService.resetInstanceForTest();
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);
    final bridge = _RecordingBridge();
    CurrentObjectiveWidgetRefreshService.instance(
      snapshotStore: store,
      bridge: bridge,
    );

    await store.saveSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.answerTodayCheck,
        title: 'Today\u2019s check',
        body: 'Answer the check you chose yesterday.',
        primaryCtaLabel: 'Answer check',
        route: '/record',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bridge.updateCount, 1);
    expect(bridge.lastPayload?['title'], 'Today\u2019s check');
  });

  test('clear removes snapshot', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = CurrentObjectiveSnapshotStore(AppServices.instance.prefs);
    await store.saveSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.recordAnyMoment,
        title: 'Record a moment',
        body: 'Add one moment from today.',
        primaryCtaLabel: 'Record moment',
        route: '/record',
      ),
    );
    await store.clear();
    expect(await store.loadSnapshot(), isNull);
  });
}
