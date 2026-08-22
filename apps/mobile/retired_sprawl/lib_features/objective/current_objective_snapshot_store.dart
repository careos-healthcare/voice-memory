import 'dart:async';

import 'package:archiveme_mobile/features/objective/current_objective_model.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_refresh_service.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_snapshot.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Simple legacy snapshot for in-app reads (title, body, check, route).
class CurrentObjectiveSnapshot {
  const CurrentObjectiveSnapshot({
    required this.title,
    required this.body,
    required this.route,
    this.checkQuestion,
  });

  factory CurrentObjectiveSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CurrentObjectiveSnapshot(
        title: '',
        body: '',
        route: '/record',
      );
    }
    return CurrentObjectiveSnapshot(
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      checkQuestion: json['checkQuestion']?.toString(),
      route: json['route']?.toString() ?? '/record',
    );
  }

  final String title;
  final String body;
  final String? checkQuestion;
  final String route;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    if (checkQuestion != null) 'checkQuestion': checkQuestion,
    'route': route,
  };
}

/// Persists objective snapshots for widget extensions and shortcuts.
class CurrentObjectiveSnapshotStore {
  CurrentObjectiveSnapshotStore(this._prefs);

  final MobilePrefsStore _prefs;

  /// Legacy in-app snapshot key (unchanged for backward compatibility).
  static const _legacyKey = 'current_objective_snapshot';

  /// Stable key for home-screen widget contract.
  static const widgetSnapshotKey = 'current_objective_widget_snapshot';

  static CurrentObjectiveSnapshotStore instance() =>
      CurrentObjectiveSnapshotStore(AppServices.instance.prefs);

  /// Saves the legacy simple snapshot from [objective].
  Future<void> saveSnapshot(CurrentObjective objective) async {
    await _prefs.writeMap(
      _legacyKey,
      CurrentObjectiveSnapshot(
        title: objective.title,
        body: objective.body,
        checkQuestion: objective.checkQuestion,
        route: objective.route,
      ).toJson(),
    );
    if (!V1CapabilityRegistry.nativeExtensions) return;
    await saveWidgetSnapshot(buildWidgetSnapshot(objective));
    unawaited(
      CurrentObjectiveWidgetRefreshService.instance().refreshFromSnapshot(),
    );
  }

  Future<CurrentObjectiveSnapshot?> loadSnapshot() async {
    final map = await _prefs.readMap(_legacyKey);
    if (map == null || map.isEmpty) return null;
    return CurrentObjectiveSnapshot.fromJson(map);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_legacyKey, {});
    if (!V1CapabilityRegistry.nativeExtensions) return;
    await clearWidgetSnapshot();
    unawaited(CurrentObjectiveWidgetRefreshService.instance().clearWidget());
  }

  /// Saves the widget-safe snapshot contract.
  Future<void> saveWidgetSnapshot(
    CurrentObjectiveWidgetSnapshot snapshot,
  ) async {
    if (!V1CapabilityRegistry.nativeExtensions) return;
    await _prefs.writeMap(widgetSnapshotKey, snapshot.toJson());
  }

  /// Loads the widget snapshot, or null when missing or invalid.
  Future<CurrentObjectiveWidgetSnapshot?> loadWidgetSnapshot() async {
    try {
      final map = await _prefs.readMap(widgetSnapshotKey);
      return CurrentObjectiveWidgetSnapshot.tryFromJson(map);
    } catch (_, stackTrace) {
      return null;
    }
  }

  Future<void> clearWidgetSnapshot() async {
    await _prefs.writeMap(widgetSnapshotKey, {});
  }
}