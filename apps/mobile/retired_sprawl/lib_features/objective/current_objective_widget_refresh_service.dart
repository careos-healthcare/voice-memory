import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/objective/current_objective_model.dart';
import 'package:archiveme_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:archiveme_mobile/features/objective/current_objective_snapshot_store.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_bridge.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_exporter.dart';
import 'package:archiveme_mobile/features/objective/objective_widget_pending_route_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Pushes the latest objective snapshot to native widgets when available.
class CurrentObjectiveWidgetRefreshService {
  CurrentObjectiveWidgetRefreshService({
    required this._snapshotStore,
    required this._bridge,
    this._pendingRouteStore,
  });

  final CurrentObjectiveSnapshotStore _snapshotStore;
  final CurrentObjectiveWidgetBridge _bridge;
  final ObjectiveWidgetPendingRouteStore? _pendingRouteStore;

  static CurrentObjectiveWidgetRefreshService? _instance;

  static CurrentObjectiveWidgetRefreshService instance({
    CurrentObjectiveSnapshotStore? snapshotStore,
    CurrentObjectiveWidgetBridge? bridge,
    ObjectiveWidgetPendingRouteStore? pendingRouteStore,
  }) {
    return _instance ??= CurrentObjectiveWidgetRefreshService(
      snapshotStore: snapshotStore ?? CurrentObjectiveSnapshotStore.instance(),
      bridge: bridge ??
          (V1CapabilityRegistry.nativeExtensions
              ? MethodChannelCurrentObjectiveWidgetBridge()
              : const NoOpCurrentObjectiveWidgetBridge()),
      pendingRouteStore: pendingRouteStore,
    );
  }

  static void resetInstanceForTest() {
    _instance = null;
  }

  /// Captures a widget tap route from the platform, if any.
  static Future<void> capturePendingLaunchRoute({
    CurrentObjectiveWidgetBridge? bridge,
    ObjectiveWidgetPendingRouteStore? pendingRouteStore,
  }) async {
    if (!V1CapabilityRegistry.nativeExtensions) return;
    if (!AppServices.isInitialized) return;
    final route = await (bridge ?? MethodChannelCurrentObjectiveWidgetBridge())
        .consumePendingWidgetRoute();
    if (route.isEmpty) return;
    final store =
        pendingRouteStore ?? ObjectiveWidgetPendingRouteStore.instance();
    await store.savePendingRoute(route);
    // TODO: track objectiveWidgetOpenedCount when native tap telemetry exists.
  }

  Future<void> refreshFromSnapshot() async {
    await ActivationTracker.trackObjectiveWidgetRefreshAttempted();
    try {
      if (!await _bridge.isAvailable()) {
        await ActivationTracker.trackObjectiveWidgetRefreshFailed();
        return;
      }
      final snapshot = await _snapshotStore.loadWidgetSnapshot();
      await _bridge.update(buildWidgetPayload(snapshot));
      await ActivationTracker.trackObjectiveWidgetRefreshSucceeded();
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      await ActivationTracker.trackObjectiveWidgetRefreshFailed();
    }
  }

  Future<void> refreshWithObjective(CurrentObjective objective) async {
    await ActivationTracker.trackObjectiveWidgetRefreshAttempted();
    try {
      if (!await _bridge.isAvailable()) {
        await ActivationTracker.trackObjectiveWidgetRefreshFailed();
        return;
      }
      final snapshot = buildWidgetSnapshot(objective);
      await _snapshotStore.saveWidgetSnapshot(snapshot);
      await _bridge.update(buildWidgetPayload(snapshot));
      await ActivationTracker.trackObjectiveWidgetRefreshSucceeded();
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      await ActivationTracker.trackObjectiveWidgetRefreshFailed();
    }
  }

  Future<void> clearWidget() async {
    await ActivationTracker.trackObjectiveWidgetRefreshAttempted();
    try {
      await _snapshotStore.clearWidgetSnapshot();
      await _pendingRouteStore?.clear();
      if (await _bridge.isAvailable()) {
        await _bridge.clear();
      }
      await ActivationTracker.trackObjectiveWidgetCleared();
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      await ActivationTracker.trackObjectiveWidgetRefreshFailed();
    }
  }
}