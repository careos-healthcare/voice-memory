import 'package:archiveme_mobile/features/objective/current_objective_snapshot_builder.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_exporter.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exporter fills safe defaults when snapshot is null', () {
    final payload = buildWidgetPayload(null);
    expect(payload['title'], kWidgetPayloadDefaultTitle);
    expect(payload['body'], kWidgetPayloadDefaultBody);
    expect(payload['primaryActionLabel'], kWidgetPayloadDefaultAction);
    expect(payload['route'], kWidgetPayloadDefaultRoute);
    expect(payload['checkQuestion'], '');
    expect(payload['type'], '');
    expect(payload['updatedAt'], isNotEmpty);
  });

  test('exporter maps snapshot fields with no null values', () {
    final snapshot = CurrentObjectiveWidgetSnapshot(
      title: 'Today\u2019s check',
      body: 'Answer the check you chose yesterday.',
      checkQuestion: 'What happens right before it shows up?',
      primaryActionLabel: 'Answer check',
      route: '/record',
      type: 'answerTodayCheck',
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    final payload = buildWidgetPayload(snapshot);
    expect(payload['title'], snapshot.title);
    expect(payload['body'], snapshot.body);
    expect(payload['checkQuestion'], snapshot.checkQuestion);
    expect(payload['primaryActionLabel'], snapshot.primaryActionLabel);
    expect(payload['route'], '/record');
    expect(payload['type'], 'answerTodayCheck');
    expect(payload.containsKey('updatedAt'), isTrue);
    for (final value in payload.values) {
      expect(value, isA<String>());
    }
  });

  test('exporter caps long text and omits private overflow', () {
    final snapshot = CurrentObjectiveWidgetSnapshot(
      title: 'T' * 100,
      body: 'B' * 200,
      checkQuestion: 'Q' * 150,
      primaryActionLabel: 'A' * 60,
      route: '/record',
      type: 'answerTodayCheck',
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    final payload = buildWidgetPayload(snapshot);
    expect(payload['title']!.length, lessThanOrEqualTo(80));
    expect(payload['body']!.length, lessThanOrEqualTo(120));
    expect(payload['checkQuestion']!.length, lessThanOrEqualTo(100));
    expect(payload['primaryActionLabel']!.length, lessThanOrEqualTo(40));
  });

  test('builder caps align with exporter max constants', () {
    expect(kWidgetSnapshotMaxTitleLength, 80);
    expect(kWidgetSnapshotMaxBodyLength, 120);
    expect(kWidgetSnapshotMaxCheckQuestionLength, 100);
    expect(kWidgetSnapshotMaxActionLabelLength, 40);
  });
}