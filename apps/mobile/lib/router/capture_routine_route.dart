import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';

/// Parses `?routine=morning|evening` from capture deep links.
JournalRoutineKind? journalRoutineKindFromUri(Uri uri) {
  return journalRoutineKindFromQueryValue(uri.queryParameters['routine']);
}

JournalRoutineKind? journalRoutineKindFromQueryValue(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'morning' => JournalRoutineKind.morning,
    'evening' => JournalRoutineKind.evening,
    _ => null,
  };
}

/// Notification payloads use `routine:morning` / `routine:evening`.
JournalRoutineKind? journalRoutineKindFromNotificationPayload(String? payload) {
  final trimmed = payload?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (!lower.startsWith('routine:')) return null;
  return journalRoutineKindFromQueryValue(lower.substring('routine:'.length));
}

String notificationPayloadForRoutine(JournalRoutineKind routine) =>
    'routine:${routine.name}';

String captureRecordPath({JournalRoutineKind? routine}) {
  if (routine == null) return RouteCatalog.recordHome;
  return '${RouteCatalog.recordHome}?routine=${routine.name}';
}
