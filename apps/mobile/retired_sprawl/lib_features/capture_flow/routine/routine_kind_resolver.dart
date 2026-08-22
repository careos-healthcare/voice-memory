import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';

/// Resolves which routine prompt to load on the capture screen.
abstract final class RoutineKindResolver {
  RoutineKindResolver._();

  static JournalRoutineKind resolve({
    JournalRoutineKind? explicit,
    RoutineAnchor? routineAnchor,
    DateTime? now,
  }) {
    if (explicit != null) return explicit;

    final fromAnchor = _fromAnchor(routineAnchor);
    if (fromAnchor != null) return fromAnchor;

    return _fromClock(now ?? DateTime.now());
  }

  static JournalRoutineKind? _fromAnchor(RoutineAnchor? anchor) {
    if (anchor == null) return null;
    return switch (anchor.type) {
      RoutineAnchorType.morning => JournalRoutineKind.morning,
      RoutineAnchorType.evening ||
      RoutineAnchorType.beforeSleep => JournalRoutineKind.evening,
      RoutineAnchorType.afterWork => JournalRoutineKind.evening,
      RoutineAnchorType.afterHardMoment ||
      RoutineAnchorType.custom => null,
    };
  }

  static JournalRoutineKind _fromClock(DateTime clock) {
    final hour = clock.hour;
    if (hour >= 5 && hour < 12) return JournalRoutineKind.morning;
    if (hour >= 17 && hour < 24) return JournalRoutineKind.evening;
    return JournalRoutineKind.morning;
  }
}
