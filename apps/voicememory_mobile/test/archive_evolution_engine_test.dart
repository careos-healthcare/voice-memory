import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_engine.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';

KeyMoment _moment({
  required String id,
  required DateTime date,
  String? patternTitle = 'Taking responsibility before asking for help',
  String? resultHint,
  String? nextCheck,
  String summary = 'A saved moment',
}) =>
    KeyMoment(
      id: id,
      date: date,
      title: 'Moment from today',
      originalText: summary,
      shortSummary: summary,
      patternTitle: patternTitle,
      resultHint: resultHint,
      nextCheck: nextCheck,
      source: KeyMomentSource.checkIn,
    );

void main() {
  test('returns null with not enough data', () {
    expect(
      buildArchiveEvolutionTimeline(
        keyMoments: [
          _moment(id: 'a', date: DateTime(2026, 5, 1)),
        ],
      ),
      isNull,
    );
    expect(buildArchiveEvolutionTimeline(keyMoments: const []), isNull);
  });

  test('builds firstSeen event for the earliest moment', () {
    final timeline = buildArchiveEvolutionTimeline(
      keyMoments: [
        _moment(id: 'a', date: DateTime(2026, 5, 1), summary: 'First time'),
        _moment(id: 'b', date: DateTime(2026, 5, 3), resultHint: 'same'),
      ],
    );
    expect(timeline, isNotNull);
    expect(timeline!.events.first.type, ArchiveEvolutionEventType.firstSeen);
    expect(timeline.events.first.title, 'First seen');
    expect(timeline.events.first.body, 'First time');
  });

  test('maps lighter, heavier, and changed result hints', () {
    final timeline = buildArchiveEvolutionTimeline(
      keyMoments: [
        _moment(id: 'a', date: DateTime(2026, 5, 1)),
        _moment(id: 'b', date: DateTime(2026, 5, 2), resultHint: 'lighter'),
        _moment(id: 'c', date: DateTime(2026, 5, 3), resultHint: 'heavier'),
        _moment(id: 'd', date: DateTime(2026, 5, 4), resultHint: 'changed'),
      ],
    );
    final types = timeline!.events.map((e) => e.type).toList();
    expect(types, contains(ArchiveEvolutionEventType.feltLighter));
    expect(types, contains(ArchiveEvolutionEventType.feltHeavier));
    expect(types, contains(ArchiveEvolutionEventType.changed));
  });

  test('maps showed_up_again to showedAgain', () {
    final timeline = buildArchiveEvolutionTimeline(
      keyMoments: [
        _moment(id: 'a', date: DateTime(2026, 5, 1)),
        _moment(id: 'b', date: DateTime(2026, 5, 2), resultHint: 'showed_up_again'),
      ],
    );
    expect(
      timeline!.events.last.type,
      ArchiveEvolutionEventType.showedAgain,
    );
  });

  test('maps nextCheck without result hint to checkChosen', () {
    final timeline = buildArchiveEvolutionTimeline(
      keyMoments: [
        _moment(id: 'a', date: DateTime(2026, 5, 1)),
        _moment(
          id: 'b',
          date: DateTime(2026, 5, 2),
          nextCheck: 'What happened right before?',
        ),
      ],
    );
    expect(
      timeline!.events.last.type,
      ArchiveEvolutionEventType.checkChosen,
    );
    expect(timeline.events.last.body, 'What happened right before?');
  });

  test('sorts events oldest to newest', () {
    final timeline = buildArchiveEvolutionTimeline(
      keyMoments: [
        _moment(id: 'c', date: DateTime(2026, 5, 10)),
        _moment(id: 'a', date: DateTime(2026, 5, 1)),
        _moment(id: 'b', date: DateTime(2026, 5, 5)),
      ],
    );
    final dates = timeline!.events.map((e) => e.date).toList();
    expect(dates, orderedEquals(dates.toList()..sort((a, b) => a.compareTo(b))));
  });

  test('limits displayed events to 20 but keeps total eventCount', () {
    final moments = List.generate(
      25,
      (i) => _moment(
        id: 'm$i',
        date: DateTime(2026, 5, 1).add(Duration(days: i)),
        resultHint: i == 0 ? null : 'same',
      ),
    );
    final timeline = buildArchiveEvolutionTimeline(keyMoments: moments);
    expect(timeline!.eventCount, 25);
    expect(timeline.events.length, 20);
    expect(timeline.events.first.id, 'm5');
    expect(timeline.events.last.id, 'm24');
  });
}
