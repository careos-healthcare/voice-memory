/// Dart-only registry of supported shortcut / deep-link actions.
///
/// Native Siri Shortcuts, App Intents, and Android shortcuts will map to
/// these ids in a later phase — no platform code here yet.
class ObjectiveShortcutAction {
  const ObjectiveShortcutAction({
    required this.id,
    required this.label,
    required this.route,
  });

  final String id;
  final String label;
  final String route;
}

/// Supported shortcut actions for ArchiveMe objective flows.
abstract class ObjectiveShortcutRegistry {
  ObjectiveShortcutRegistry._();

  static const openRecord = ObjectiveShortcutAction(
    id: 'openRecord',
    label: 'Open Record',
    route: '/record',
  );

  static const answerCheck = ObjectiveShortcutAction(
    id: 'answerCheck',
    label: 'Answer check',
    route: '/record',
  );

  static const recordMoment = ObjectiveShortcutAction(
    id: 'recordMoment',
    label: 'Record moment',
    route: '/record',
  );

  static const openPatterns = ObjectiveShortcutAction(
    id: 'openPatterns',
    label: 'Open Patterns',
    route: '/patterns',
  );

  static const List<ObjectiveShortcutAction> all = [
    openRecord,
    answerCheck,
    recordMoment,
    openPatterns,
  ];

  static ObjectiveShortcutAction? byId(String id) {
    for (final action in all) {
      if (action.id == id) return action;
    }
    return null;
  }
}