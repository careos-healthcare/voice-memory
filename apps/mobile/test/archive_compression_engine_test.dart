import 'package:archiveme_mobile/features/archive_compression/archive_compression_engine.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:flutter_test/flutter_test.dart';

KeyMoment _moment({
  required String id,
  required DateTime date,
  String? patternTitle,
  List<String> tags = const [],
  String title = 'Moment',
}) => KeyMoment(
  id: id,
  date: date,
  title: title,
  originalText: 'text',
  shortSummary: 'text',
  patternTitle: patternTitle,
  tags: tags,
);

void main() {
  test('groups by patternTitle when count is at least 3', () {
    const title = 'Taking responsibility before asking for help';
    final groups = buildArchiveMomentGroups([
      _moment(id: 'a', date: DateTime(2026, 5), patternTitle: title),
      _moment(id: 'b', date: DateTime(2026, 5, 5), patternTitle: title),
      _moment(id: 'c', date: DateTime(2026, 5, 10), patternTitle: title),
    ]);
    expect(groups, hasLength(1));
    expect(groups.first.title, title);
    expect(groups.first.patternTitle, title);
    expect(groups.first.count, 3);
    expect(
      groups.first.suggestedAction,
      ArchiveCompressionSuggestedAction.keepTogether,
    );
  });

  test('does not create groups below 3 moments', () {
    final groups = buildArchiveMomentGroups([
      _moment(
        id: 'a',
        date: DateTime(2026, 5),
        patternTitle: 'Same pattern',
      ),
      _moment(
        id: 'b',
        date: DateTime(2026, 5, 2),
        patternTitle: 'Same pattern',
      ),
    ]);
    expect(groups, isEmpty);
  });

  test('groups by shared tags only with at least 2 overlapping tags', () {
    final groups = buildArchiveMomentGroups([
      _moment(
        id: 'a',
        date: DateTime(2026, 5),
        tags: const ['pressure', 'work', 'helped'],
      ),
      _moment(
        id: 'b',
        date: DateTime(2026, 5, 2),
        tags: const ['pressure', 'work', 'heavier'],
      ),
      _moment(
        id: 'c',
        date: DateTime(2026, 5, 3),
        tags: const ['pressure', 'work'],
      ),
    ]);
    expect(groups, hasLength(1));
    expect(groups.first.title, 'Similar moments');
    expect(groups.first.patternTitle, isNull);
  });

  test('does not group vague moments without patternTitle or tags', () {
    final groups = buildArchiveMomentGroups([
      _moment(id: 'a', date: DateTime(2026, 5)),
      _moment(id: 'b', date: DateTime(2026, 5, 2)),
      _moment(id: 'c', date: DateTime(2026, 5, 3)),
    ]);
    expect(groups, isEmpty);
  });

  test('tag groups with mixed titles suggest split', () {
    final groups = buildArchiveMomentGroups([
      _moment(
        id: 'a',
        date: DateTime(2026, 5),
        title: 'One title',
        tags: const ['pressure', 'work'],
      ),
      _moment(
        id: 'b',
        date: DateTime(2026, 5, 2),
        title: 'Another title',
        tags: const ['pressure', 'work'],
      ),
      _moment(
        id: 'c',
        date: DateTime(2026, 5, 3),
        title: 'Third title',
        tags: const ['pressure', 'work'],
      ),
    ]);
    expect(
      groups.first.suggestedAction,
      ArchiveCompressionSuggestedAction.split,
    );
  });

  test('sorts by count desc then latest lastDate desc', () {
    final groups = buildArchiveMomentGroups([
      _moment(id: 'a1', date: DateTime(2026, 5), patternTitle: 'Small'),
      _moment(id: 'a2', date: DateTime(2026, 5, 2), patternTitle: 'Small'),
      _moment(id: 'a3', date: DateTime(2026, 5, 3), patternTitle: 'Small'),
      _moment(id: 'b1', date: DateTime(2026, 5), patternTitle: 'Big'),
      _moment(id: 'b2', date: DateTime(2026, 5, 2), patternTitle: 'Big'),
      _moment(id: 'b3', date: DateTime(2026, 5, 3), patternTitle: 'Big'),
      _moment(id: 'b4', date: DateTime(2026, 5, 10), patternTitle: 'Big'),
    ]);
    expect(groups.first.title, 'Big');
    expect(groups.first.count, 4);
  });

  test('caps returned groups at 20', () {
    final moments = <KeyMoment>[];
    for (var i = 0; i < 21; i++) {
      for (var j = 0; j < 3; j++) {
        moments.add(
          _moment(
            id: 'p$i-$j',
            date: DateTime(2026, 1, 1 + i + j),
            patternTitle: 'Pattern $i',
          ),
        );
      }
    }
    final groups = buildArchiveMomentGroups(moments);
    expect(groups.length, 20);
  });

  test('never auto-hides — all moment ids remain in the group', () {
    final moments = [
      _moment(id: 'a', date: DateTime(2026, 5), patternTitle: 'Pattern'),
      _moment(id: 'b', date: DateTime(2026, 5, 2), patternTitle: 'Pattern'),
      _moment(id: 'c', date: DateTime(2026, 5, 3), patternTitle: 'Pattern'),
    ];
    final groups = buildArchiveMomentGroups(moments);
    expect(groups.first.momentIds, ['a', 'b', 'c']);
  });
}