import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/quick_help/quick_help_engine.dart';
import 'package:voicememory_mobile/features/quick_help/quick_help_model.dart';

void main() {
  test('whatToRecord returns a practical, recordable prompt', () {
    final r = buildQuickHelpResponse(intent: QuickHelpIntent.whatToRecord);
    expect(r.title, 'Record one moment');
    expect(r.action, QuickHelpAction.startRecording);
    expect(r.actionLabel, 'Start recording');
    expect(r.example, isNotNull);
  });

  test('anotherPerspective points at the moment before the pattern', () {
    final r = buildQuickHelpResponse(
      intent: QuickHelpIntent.anotherPerspective,
    );
    expect(r.action, QuickHelpAction.showPerspective);
    expect(r.nextCheck, 'What happened right before it showed up?');
  });

  test('practicalNextStep offers one check to use', () {
    final r = buildQuickHelpResponse(
      intent: QuickHelpIntent.practicalNextStep,
    );
    expect(r.action, QuickHelpAction.useThisCheck);
    expect(r.nextCheck, isNotNull);
  });

  test('kinderAngle stays grounded with a hardest-moment check', () {
    final r = buildQuickHelpResponse(intent: QuickHelpIntent.kinderAngle);
    expect(r.title, 'A kinder angle');
    expect(r.nextCheck, 'What was the hardest moment today?');
  });

  test('whatToCheckNext uses the existing next check when available', () {
    final r = buildQuickHelpResponse(
      intent: QuickHelpIntent.whatToCheckNext,
      nextCheck: 'What helped make it lighter?',
    );
    expect(r.nextCheck, 'What helped make it lighter?');
    expect(r.body, 'What helped make it lighter?');
    expect(r.action, QuickHelpAction.useThisCheck);
  });

  test('whatToCheckNext falls back when no next check is available', () {
    final r = buildQuickHelpResponse(intent: QuickHelpIntent.whatToCheckNext);
    expect(r.nextCheck, 'What happens right before it starts?');
    expect(r.body, 'Check what happens right before it starts.');
  });

  test('bodies stay short and practical', () {
    for (final intent in QuickHelpIntent.values) {
      final r = buildQuickHelpResponse(intent: intent);
      expect(r.body.length, lessThan(120));
      expect(r.title, isNotEmpty);
    }
  });
}
