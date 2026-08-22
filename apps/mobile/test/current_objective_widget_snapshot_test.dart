import 'package:archiveme_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON roundtrip preserves fields', () {
    final original = CurrentObjectiveWidgetSnapshot(
      title: 'Today\u2019s check',
      body: 'Answer the check you chose yesterday.',
      checkQuestion: 'What happens right before it shows up?',
      primaryActionLabel: 'Answer check',
      route: '/record',
      type: 'answerTodayCheck',
      updatedAt: DateTime.utc(2026, 6, 6, 12),
    );

    final restored = CurrentObjectiveWidgetSnapshot.tryFromJson(
      original.toJson(),
    );

    expect(restored, isNotNull);
    expect(restored!.title, original.title);
    expect(restored.body, original.body);
    expect(restored.checkQuestion, original.checkQuestion);
    expect(restored.primaryActionLabel, original.primaryActionLabel);
    expect(restored.route, original.route);
    expect(restored.type, original.type);
    expect(restored.updatedAt, original.updatedAt);
  });

  test('tryFromJson returns null for empty map', () {
    expect(CurrentObjectiveWidgetSnapshot.tryFromJson({}), isNull);
    expect(CurrentObjectiveWidgetSnapshot.tryFromJson(null), isNull);
  });

  test('tryFromJson returns null when required fields missing', () {
    expect(
      CurrentObjectiveWidgetSnapshot.tryFromJson({'title': 'Only title'}),
      isNull,
    );
  });

  test('copyWith overrides selected fields', () {
    final snapshot = CurrentObjectiveWidgetSnapshot(
      title: 'Record a moment',
      body: 'Add one moment from today.',
      primaryActionLabel: 'Record moment',
      route: '/record',
      type: 'recordAnyMoment',
      updatedAt: DateTime.utc(2026),
    );

    final copy = snapshot.copyWith(title: 'Today\u2019s check');
    expect(copy.title, 'Today\u2019s check');
    expect(copy.body, snapshot.body);
  });

  test('contract max length constants match builder caps', () {
    expect(kWidgetSnapshotMaxTitleLength, 80);
    expect(kWidgetSnapshotMaxBodyLength, 120);
    expect(kWidgetSnapshotMaxCheckQuestionLength, 100);
    expect(kWidgetSnapshotMaxActionLabelLength, 40);
  });
}