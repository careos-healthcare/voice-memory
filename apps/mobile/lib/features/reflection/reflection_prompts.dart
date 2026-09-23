import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';

/// A daily or weekly reflection the scheduler can place on the calendar.
class ReflectionPromptTemplate {
  const ReflectionPromptTemplate({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.weekday,
    this.body = 'Tap to start a voice reflection.',
  });

  final String id;
  final String title;
  final int hour;
  final int minute;

  /// Null means every day. Otherwise a [DateTime] weekday.
  final int? weekday;
  final String body;
}

/// Built-in prompts people can keep or replace.
abstract final class ReflectionPromptTemplates {
  static const eveningId = 'evening_check_in';
  static const sundayId = 'sunday_review';

  static const evening = ReflectionPromptTemplate(
    id: eveningId,
    title: 'Evening Check-in',
    hour: 20,
    minute: 0,
  );

  static const sunday = ReflectionPromptTemplate(
    id: sundayId,
    title: 'Sunday Review',
    hour: 18,
    minute: 0,
    weekday: DateTime.sunday,
  );

  static const defaults = <ReflectionPromptTemplate>[evening, sunday];
}

/// One entity the prompt title can mention.
class ReflectionGraphTrigger {
  const ReflectionGraphTrigger({
    required this.name,
    required this.category,
    required this.mature,
  });

  final String name;
  final String category;
  final bool mature;
}

/// Notification payload that opens the reflection call.
abstract final class ReflectionCallPayload {
  static const prefix = 'reflection:';

  static String encode(String templateId) => '$prefix$templateId';

  static String? templateIdOf(String? payload) {
    if (payload == null || !payload.startsWith(prefix)) return null;
    final id = payload.substring(prefix.length).trim();
    return id.isEmpty ? null : id;
  }
}

/// Rows from the entity graph that are mature goals.
const matureGoalSql = '''
SELECT name, category, description
FROM entities
WHERE category = ? AND description = ?
''';

/// Goals whose description is `mature`.
List<ReflectionGraphTrigger> matureGoalsFromEntityRows(
  List<Map<String, Object?>> rows,
) {
  final triggers = <ReflectionGraphTrigger>[];
  for (final row in rows) {
    final name = row['name'];
    final category = row['category'];
    final description = row['description'];
    if (name is! String || name.trim().isEmpty) continue;
    if (category != EntityCategories.goals) continue;
    if (description != 'mature') continue;
    triggers.add(
      ReflectionGraphTrigger(
        name: name.trim(),
        category: EntityCategories.goals,
        mature: true,
      ),
    );
  }
  return triggers;
}

/// Title for [template], using a mature goal when the graph has one.
String reflectionPromptTitle({
  required ReflectionPromptTemplate template,
  required List<ReflectionGraphTrigger> triggers,
}) {
  for (final trigger in triggers) {
    if (!trigger.mature || trigger.category != EntityCategories.goals) {
      continue;
    }
    final name = trigger.name.trim();
    if (name.isEmpty) continue;
    if (template.weekday == null) return 'How did your $name go today?';
    return 'How did your $name go this week?';
  }
  return template.title;
}

/// Next local instant strictly after [now] for [template].
DateTime nextReflectionInstant(ReflectionPromptTemplate template, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  for (var offset = 0; offset < 8; offset++) {
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      template.hour,
      template.minute,
    );
    final weekdayMatches =
        template.weekday == null || candidate.weekday == template.weekday;
    if (weekdayMatches && candidate.isAfter(now)) return candidate;
    day = day.add(const Duration(days: 1));
  }
  return DateTime(now.year, now.month, now.day, template.hour, template.minute);
}

/// One scheduled prompt, using the fields a local notification plugin expects.
class ScheduledReflectionNotification {
  const ScheduledReflectionNotification({
    required this.id,
    required this.templateId,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.payload,
    required this.matchComponents,
  });

  final int id;
  final String templateId;
  final String title;
  final String body;
  final DateTime scheduledDate;
  final String payload;

  /// `time` for a daily prompt, `dayOfWeekAndTime` for a weekly one.
  ///
  /// These names match flutter_local_notifications `DateTimeComponents`.
  final String matchComponents;
}

int reflectionNotificationId(String templateId) {
  return switch (templateId) {
    ReflectionPromptTemplates.eveningId => 4101,
    ReflectionPromptTemplates.sundayId => 4102,
    _ => templateId.hashCode & 0x7fffffff,
  };
}

String reflectionMatchComponents(ReflectionPromptTemplate template) {
  return template.weekday == null ? 'time' : 'dayOfWeekAndTime';
}
