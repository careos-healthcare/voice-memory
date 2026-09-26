import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/insights/knowledge_catalog.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/features/insights/views/knowledge_manager_view.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  List<String> themes = const [],
  String? place,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 6, 12),
    transcript: transcript,
    durationSeconds: 4,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    display: JournalDisplayMetadata(locationLabel: place),
  );
}

ArchiveFact _contact(String id, String label, String entryId) {
  return ArchiveFact(
    id: id,
    sourceEntryId: entryId,
    label: label,
    value: 'named in the journal',
    note: '',
    createdAt: DateTime.utc(2026, 6, 12),
    updatedAt: DateTime.utc(2026, 6, 12),
    factType: FactType.contact.id,
  );
}

void main() {
  test('people, places, and themes stay in their own groups', () {
    final entries = [
      _entry(
        id: 'a',
        transcript: 'Maya met me by the river.',
        themes: ['river (80% match)'],
        place: 'River cafe',
      ),
      _entry(
        id: 'b',
        transcript: 'The river was quieter today.',
        themes: ['river'],
      ),
    ];
    final catalog = buildKnowledgeCatalog(
      entries,
      contacts: [_contact('fact-1', 'Maya', 'a')],
      forgotten: {'quiet'},
    );

    expect(
      catalog.map((item) => '${item.kind.name}:${item.label}').toList(),
      ['people:Maya', 'places:River cafe', 'themes:river'],
    );
    expect(catalog.last.entryIds, ['a', 'b']);
  });

  test('forgetting a theme removes that tag and leaves the entry', () {
    final entry = _entry(
      id: 'a',
      transcript: 'I mentioned the river.',
      themes: ['river', 'work'],
      place: 'River cafe',
    );
    final next = entryWithoutKnowledge(
      entry,
      KnowledgeItem(
        kind: KnowledgeKind.themes,
        label: 'river',
        citations: [entry],
      ),
    );
    expect(next?.reflection.recurringThemes, ['work']);
    expect(next?.display.locationLabel, 'River cafe');
    expect(next?.transcript, 'I mentioned the river.');
  });

  test('cloud delete runs only when cloud features are on', () async {
    expect(AppServices.isInitialized, isFalse);
    final deleted = <String>[];
    final item = KnowledgeItem(
      kind: KnowledgeKind.themes,
      label: 'river',
      citations: const [],
    );
    await KnowledgeForgetService(
      isCloudSyncEnabled: () async => true,
      deleteCloudLabel: (label) async => deleted.add(label),
    ).forget(item);
    await KnowledgeForgetService(
      isCloudSyncEnabled: () async => false,
      deleteCloudLabel: (label) async => deleted.add('off-$label'),
    ).forget(item);
    expect(deleted, ['river']);
  });

  testWidgets('a row opens the cited words and Forget this removes it', (
    tester,
  ) async {
    final forgotten = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeManagerView(
          initialEntries: [
            _entry(
              id: 'a',
              transcript: 'Maya met me by the river.',
              themes: ['river'],
              place: 'River cafe',
            ),
          ],
          contacts: [_contact('fact-1', 'Maya', 'a')],
          onForget: (item) async => forgotten.add(item.label),
        ),
      ),
    );

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('· View evidence'), findsWidgets);

    await tester.tap(find.text('river'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge_citation_a')), findsOneWidget);
    expect(find.text('Maya met me by the river.'), findsWidgets);

    await tester.tap(find.byKey(const Key('knowledge_forget_river')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge_forget_confirm_river')));
    await tester.pumpAndSettle();

    expect(forgotten, ['river']);
    expect(find.text('river'), findsNothing);
    expect(find.text('Maya'), findsOneWidget);
  });
}
