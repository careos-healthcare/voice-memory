import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';

abstract final class RoutinePromptCopy {
  RoutinePromptCopy._();

  static String eyebrow(JournalRoutineKind routine) => switch (routine) {
    JournalRoutineKind.morning => 'Morning check-in',
    JournalRoutineKind.evening => 'Evening reflection',
  };

  static const skipAction = 'Not now';
  static const groundedNote =
      'Grounded in your archive — stays on this device.';
}
