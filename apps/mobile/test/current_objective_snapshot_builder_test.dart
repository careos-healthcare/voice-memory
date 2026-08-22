import 'package:archiveme_mobile/features/objective/current_objective_model.dart';
import 'package:archiveme_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildWidgetSnapshot trims and caps long text', () {
    final longBody = 'A' * 200;
    final longQuestion = 'Q' * 150;

    final snapshot = buildWidgetSnapshot(
      CurrentObjective(
        type: CurrentObjectiveType.answerTodayCheck,
        title: '  Today\u2019s check  ',
        body: longBody,
        checkQuestion: longQuestion,
        primaryCtaLabel: 'Answer check',
        route: '/record',
      ),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    expect(snapshot.title, 'Today\u2019s check');
    expect(snapshot.body.length, lessThanOrEqualTo(120));
    expect(snapshot.body, endsWith('\u2026'));
    expect(snapshot.checkQuestion!.length, lessThanOrEqualTo(100));
    expect(snapshot.checkQuestion, endsWith('\u2026'));
    expect(snapshot.primaryActionLabel, 'Answer check');
    expect(snapshot.type, 'answerTodayCheck');
    expect(snapshot.updatedAt, DateTime.utc(2026, 6, 6));
  });

  test('route defaults to /record when empty', () {
    final snapshot = buildWidgetSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.recordAnyMoment,
        title: 'Record a moment',
        body: 'Add one moment from today.',
        primaryCtaLabel: 'Record moment',
        route: '   ',
      ),
    );

    expect(snapshot.route, '/record');
    expect(snapshot.title, isNotEmpty);
    expect(snapshot.body, isNotEmpty);
  });

  test('omits empty checkQuestion', () {
    final snapshot = buildWidgetSnapshot(
      const CurrentObjective(
        type: CurrentObjectiveType.recordFirstMoment,
        title: 'Record your first moment',
        body: 'Start with one moment from today.',
        primaryCtaLabel: 'Record moment',
        route: '/record',
      ),
    );

    expect(snapshot.checkQuestion, isNull);
  });
}