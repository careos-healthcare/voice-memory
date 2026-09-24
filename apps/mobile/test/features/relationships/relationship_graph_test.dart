import 'package:archiveme_mobile/features/entities/relationship_extractor.dart';
import 'package:archiveme_mobile/features/relationships/presentation/relationship_graph_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entries yield people, tone, and last contact', () async {
    final people = await const RelationshipExtractor().extract([
      RelationshipSource(
        entryId: 'maya-day',
        createdAt: DateTime.utc(2026, 3, 1),
        text: 'Maya seemed distant at lunch.',
      ),
      RelationshipSource(
        entryId: 'alex-day',
        createdAt: DateTime.utc(2026, 3, 20),
        text: 'I thanked my partner Alex for staying.',
      ),
    ]);

    expect(people.map((person) => person.name), ['Alex', 'Maya']);
    final alex = people.first;
    expect(alex.relationship, 'partner');
    expect(alex.sentiment, greaterThan(0));
    expect(alex.lastContact, DateTime.utc(2026, 3, 20));
    expect(alex.entryIds, ['alex-day']);
    expect(people.last.sentiment, lessThan(0));
    expect(people.last.entryIds, ['maya-day']);
  });

  test('a model mention is kept when the local scan misses the name', () async {
    final people =
        await RelationshipExtractor(
          llm: (text) async => const [
            ExtractedMention(name: 'sam', relationship: 'friend'),
          ],
        ).extract([
          RelationshipSource(
            entryId: 'walk',
            createdAt: DateTime.utc(2026, 4, 2),
            text: 'sam and i walked by the river.',
          ),
        ]);

    expect(people.single.name, 'Sam');
    expect(people.single.relationship, 'friend');
    expect(people.single.entryIds, ['walk']);
  });

  testWidgets('people graph shows tone and a reachable evidence link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final people = await const RelationshipExtractor().extract([
      RelationshipSource(
        entryId: 'alex-day',
        createdAt: DateTime.utc(2026, 3, 20),
        text: 'I thanked my partner Alex for staying.',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: RelationshipGraphScreen(people: people)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('relationship_graph_screen')), findsOneWidget);
    expect(find.byKey(const Key('relationship_person_Alex')), findsOneWidget);
    expect(
      find.byKey(const Key('relationship_sentiment_Alex')),
      findsOneWidget,
    );
    expect(find.textContaining('View evidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
