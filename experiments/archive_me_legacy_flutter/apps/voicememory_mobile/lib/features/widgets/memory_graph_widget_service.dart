import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import '../../services/local_storage/shared_vault_storage.dart';
import '../action_plans/action_plan_engine.dart';
import '../action_plans/action_plan_models.dart';
import '../action_plans/action_plan_store.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'memory_graph_widget_models.dart';

class MemoryGraphWidgetService {
  MemoryGraphWidgetService({
    required this.actionPlanStore,
    required this.actionPlanEngine,
    required this.clusterStore,
    required this.journalStore,
    required this.preferencesStore,
    required this.platform,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const preferencesKey = 'memory_graph_widget_preferences_v1';

  final ActionPlanStore actionPlanStore;
  final ActionPlanEngine actionPlanEngine;
  final SemanticClusterStore clusterStore;
  final JournalStore journalStore;
  final MobilePrefsStore preferencesStore;
  final SharedVaultPlatformBridge platform;
  final DateTime Function() _clock;

  Future<MemoryGraphWidgetPreferences> preferences() async {
    final value = await preferencesStore.readMap(preferencesKey);
    return value == null
        ? const MemoryGraphWidgetPreferences()
        : MemoryGraphWidgetPreferences.fromJson(value);
  }

  Future<void> savePreferences(MemoryGraphWidgetPreferences value) async {
    await preferencesStore.writeMap(preferencesKey, value.toJson());
    await refresh();
  }

  Future<MemoryGraphWidgetStatus> status() async =>
      MemoryGraphWidgetStatus.fromJson(await platform.extensionStatus());

  Future<void> refresh() async {
    final settings = await preferences();
    final today = _clock().toLocal();
    final day = DateTime(today.year, today.month, today.day);
    final dayKey = canonicalActionPlanDate(day);
    final plans = await actionPlanStore.list();
    final habits = <Map<String, Object?>>[];
    for (final plan in plans.where(
      (candidate) =>
          candidate.status == ActionPlanStatus.active &&
          (settings.selectedActionPlanIds.isEmpty ||
              settings.selectedActionPlanIds.contains(candidate.id)),
    )) {
      for (final step in plan.steps) {
        if (step.frequency.isScheduled(day) &&
            step.completionHistory[dayKey] != true) {
          habits.add({
            'planId': plan.id,
            'stepId': step.id,
            'title': step.title,
            'streak': step.streakCount,
          });
        }
      }
    }
    habits.sort(
      (left, right) =>
          (right['streak'] as int).compareTo(left['streak'] as int),
    );

    final clusters =
        (await clusterStore.list())
            .where(
              (cluster) =>
                  settings.selectedClusterIds.isEmpty ||
                  settings.selectedClusterIds.contains(cluster.id),
            )
            .toList()
          ..sort(
            (left, right) =>
                right.activityVelocity.compareTo(left.activityVelocity),
          );
    final entries = await journalStore.loadAll();
    final moodValence = entries.isEmpty
        ? 0.0
        : _moodValence(entries.first.reflection.mood);
    final leadingHabit = habits.firstOrNull;
    final leadingCluster = clusters.firstOrNull;
    final clusterDirection = leadingCluster == null
        ? 'steady'
        : leadingCluster.activityVelocity >= .66
        ? 'rising'
        : leadingCluster.activityVelocity <= .33
        ? 'quiet'
        : 'steady';

    await platform.publishWidgetSnapshot({
      'schemaVersion': 1,
      'generatedAt': _clock().toUtc().toIso8601String(),
      'theme': settings.theme.name,
      'lockScreenEnabled': settings.lockScreenEnabled,
      'quickCapture': {
        'enabled': settings.quickCaptureEnabled,
        'route': 'archiveme://capture?source=widget',
      },
      'habits': settings.habitWidgetEnabled ? habits.take(3).toList() : [],
      'clusters': settings.clusterWidgetEnabled
          ? [
              for (final cluster in clusters.take(3))
                {
                  'clusterId': cluster.id,
                  'title': cluster.title,
                  'velocity': cluster.activityVelocity,
                  'moodValence': moodValence,
                },
            ]
          : [],
      'quickCaptureLabel': 'Quick capture',
      'quickCaptureRoute': '/record',
      'habitTitle': leadingHabit?['title'] ?? 'Open today’s small steps',
      'habitCompleted': false,
      'habitStepId': leadingHabit?['stepId'],
      'habitRoute': '/life-os',
      'clusterTitle': leadingCluster?.title ?? 'Memory pulse',
      'clusterSummary': leadingCluster == null
          ? 'Open your semantic clusters'
          : '${(leadingCluster.activityVelocity * 100).round()}% momentum',
      'clusterRoute': '/life-os',
      'habitStreak': {
        'title': leadingHabit?['title'] ?? 'Open today’s small steps',
        'currentStreak': leadingHabit?['streak'] ?? 0,
        'stepId': leadingHabit?['stepId'],
        'route': '/life-os',
      },
      'clusterPulse': {
        'title': leadingCluster?.title ?? 'Memory pulse',
        'summary': leadingCluster == null
            ? 'Open your semantic clusters'
            : '${(leadingCluster.activityVelocity * 100).round()}% momentum',
        'direction': clusterDirection,
        'moodValence': moodValence,
        'route': '/life-os',
      },
    });
    await platform.reloadWidgets();
  }

  Future<int> applyPendingActions() async {
    final actions = await platform.drainWidgetActions();
    var applied = 0;
    var refreshRequested = false;
    for (final action in actions.take(32)) {
      if (action['type'] == 'semanticClusterPulse') {
        refreshRequested = true;
        applied++;
        continue;
      }
      if (action['type'] != 'completeHabit') continue;
      final stepId = action['stepId'];
      if (stepId is! String || stepId.trim().isEmpty) continue;
      final rawDate = action['localDay'];
      final date = rawDate is String
          ? DateTime.tryParse(rawDate)
          : _clock().toLocal();
      if (date == null) continue;
      try {
        await actionPlanEngine.checkIn(stepId, date);
        applied++;
      } on ArgumentError {
        // Ignore expired, malformed, or no-longer-scheduled widget actions.
      } on StateError {
        // The action plan may have been removed while the app was closed.
      }
    }
    if (applied > 0 || refreshRequested) await refresh();
    return applied;
  }
}

double _moodValence(String mood) {
  final value = mood.toLowerCase();
  if (RegExp(
    r'\b(calm|good|grateful|happy|hopeful|steady|energized|positive)\b',
  ).hasMatch(value)) {
    return 1;
  }
  if (RegExp(
    r'\b(angry|anxious|bad|down|sad|stressed|tired|upset|worried)\b',
  ).hasMatch(value)) {
    return -1;
  }
  return 0;
}
