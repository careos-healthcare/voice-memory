import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/reflection/reflection_prompts.dart';

/// Delivers a planned prompt.
///
/// Production leaves [V1CapabilityRegistry.notifications] false, so this
/// library does not import flutter_local_notifications. When that capability
/// is on, a backend forwards each request to
/// `FlutterLocalNotificationsPlugin.zonedSchedule` (see the archived
/// implementation under experiments/archive/local_notifications).
abstract interface class ReflectionNotificationBackend {
  Future<void> cancelPending();

  Future<void> schedule(ScheduledReflectionNotification notification);
}

/// Plans Evening Check-in and Sunday Review, then hands them to a backend.
class ProactiveReflectionScheduler {
  ProactiveReflectionScheduler({
    bool? notificationsEnabled,
    this.backend,
    DateTime Function()? clock,
    this.templates = ReflectionPromptTemplates.defaults,
  }) : notificationsEnabled =
           notificationsEnabled ?? V1CapabilityRegistry.notifications,
       _clock = clock ?? DateTime.now;

  final bool notificationsEnabled;
  final ReflectionNotificationBackend? backend;
  final DateTime Function() _clock;
  final List<ReflectionPromptTemplate> templates;

  List<ScheduledReflectionNotification> pending =
      const <ScheduledReflectionNotification>[];

  /// Reads mature goals, then schedules the configured prompts.
  Future<List<ScheduledReflectionNotification>> scheduleFromGraph(
    Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args)
    query,
  ) async {
    final rows = await query(matureGoalSql, const ['goals', 'mature']);
    return schedule(triggers: matureGoalsFromEntityRows(rows));
  }

  /// Builds prompt titles and, when notifications are enabled, delivers them.
  Future<List<ScheduledReflectionNotification>> schedule({
    List<ReflectionGraphTrigger> triggers = const [],
  }) async {
    final now = _clock();
    final planned = [
      for (final template in templates)
        ScheduledReflectionNotification(
          id: reflectionNotificationId(template.id),
          templateId: template.id,
          title: reflectionPromptTitle(template: template, triggers: triggers),
          body: template.body,
          scheduledDate: nextReflectionInstant(template, now),
          payload: ReflectionCallPayload.encode(template.id),
          matchComponents: reflectionMatchComponents(template),
        ),
    ];
    pending = planned;
    final delivery = backend;
    if (!notificationsEnabled || delivery == null) return planned;
    await delivery.cancelPending();
    for (final notification in planned) {
      await delivery.schedule(notification);
    }
    return planned;
  }
}
