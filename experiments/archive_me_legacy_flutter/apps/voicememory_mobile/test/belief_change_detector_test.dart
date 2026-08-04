import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/belief_change/belief_change_detector.dart';
import 'package:voicememory_mobile/features/belief_change/belief_change_models.dart';
import 'package:voicememory_mobile/features/discover/discover_cache.dart';
import 'package:voicememory_mobile/features/discover/discover_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: const ['confidence'],
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() => DiscoverYourselfCache.instance.invalidate());

  test('detects confidence decrease with month labels', () {
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 'old$i',
          at: DateTime(2026, 3, 5 + i),
          line: 'I need external validation from everyone at work today',
        ),
      ),
      ...List.generate(
        6,
        (i) => _entry(
          id: 'new$i',
          at: DateTime(2026, 5, 10 + i),
          line: 'Quiet reflection about confidence without validation language',
        ),
      ),
    ];

    const detector = BeliefChangeDetector();
    final alerts = detector.detect(entries: entries, state: null);

    expect(alerts, isNotEmpty);
    final decrease = alerts.where(
      (a) =>
          a.type == BeliefChangeAlertType.confidenceDecrease ||
          a.type == BeliefChangeAlertType.disappearingBelief,
    );
    expect(decrease, isNotEmpty);
    final top = decrease.first;
    expect(top.evidenceEntryIds.length, greaterThanOrEqualTo(3));
    expect(top.headline, anyOf(contains('less'), contains('fading')));
    expect(
      top.magnitude,
      greaterThanOrEqualTo(BeliefChangeDetector.minMagnitude),
    );
  });

  test('detects emerging belief with rising confidence', () {
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 'e$i',
          at: DateTime(2026, 2, i + 1),
          line: 'Neutral daily reflection without trust language here',
        ),
      ),
      ...List.generate(
        6,
        (i) => _entry(
          id: 't$i',
          at: DateTime(2026, 5, i + 1),
          line: 'I can trust myself to decide without approval from others',
        ),
      ),
    ];

    final alerts = const BeliefChangeDetector().detect(entries: entries);
    expect(alerts, isNotEmpty);
    final emerging = alerts.where(
      (a) =>
          a.type == BeliefChangeAlertType.newBeliefEmerging ||
          a.type == BeliefChangeAlertType.confidenceIncrease,
    );
    expect(emerging, isNotEmpty);
    expect(alerts.first.magnitude, greaterThanOrEqualTo(alerts.last.magnitude));
  });

  test('alerts sorted by magnitude descending', () {
    final entries = List.generate(
      14,
      (i) => _entry(
        id: 's$i',
        at: DateTime(2026, 1, 1).add(Duration(days: i * 8)),
        line: i < 7
            ? 'I need external validation and approval constantly'
            : 'I trust myself and feel independent in my choices',
      ),
    );

    final alerts = const BeliefChangeDetector().detect(entries: entries);
    if (alerts.length < 2) return;
    for (var i = 0; i < alerts.length - 1; i++) {
      expect(
        alerts[i].magnitude,
        greaterThanOrEqualTo(alerts[i + 1].magnitude),
      );
    }
  });

  test('discover engine maps alerts to Beliefs That Changed section', () {
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 'd0$i',
          at: DateTime(2026, 2, 1 + i),
          line: 'I need external validation before every decision I make',
        ),
      ),
      ...List.generate(
        6,
        (i) => _entry(
          id: 'd1$i',
          at: DateTime(2026, 5, 1 + i),
          line: 'I can trust myself and I am learning each week',
        ),
      ),
    ];

    final snapshot = const DiscoverYourselfEngine().build(entries: entries);
    expect(snapshot.beliefChanges, isNotEmpty);
    final change = snapshot.beliefChanges.first;
    expect(change.headline, isNotEmpty);
    expect(change.beliefStatement, isNotEmpty);
    expect(change.priorPercent, greaterThanOrEqualTo(0));
    expect(change.currentPercent, greaterThanOrEqualTo(0));
    expect(change.magnitude, greaterThan(0));
  });
}
