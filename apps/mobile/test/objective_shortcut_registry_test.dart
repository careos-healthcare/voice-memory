import 'package:archiveme_mobile/features/objective/objective_shortcut_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry includes all supported actions', () {
    final ids = ObjectiveShortcutRegistry.all.map((a) => a.id).toSet();
    expect(
      ids,
      containsAll([
        'openRecord',
        'answerCheck',
        'recordMoment',
        'openPatterns',
      ]),
    );
    expect(ObjectiveShortcutRegistry.all.length, 4);
  });

  test('byId resolves known actions', () {
    expect(ObjectiveShortcutRegistry.byId('openRecord')?.route, '/record');
    expect(ObjectiveShortcutRegistry.byId('openPatterns')?.route, '/patterns');
    expect(ObjectiveShortcutRegistry.byId('unknown'), isNull);
  });

  test('each action has id, label, and route', () {
    for (final action in ObjectiveShortcutRegistry.all) {
      expect(action.id, isNotEmpty);
      expect(action.label, isNotEmpty);
      expect(action.route, startsWith('/'));
    }
  });
}