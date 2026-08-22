import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required String id}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 6, 12, 10),
    transcript: 'A saved moment transcript for responsive layout testing.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  group('ArchiveResponsiveLayout', () {
    test('uses three columns on very wide dashboards', () {
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(1200), 3);
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(800), 2);
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(500), 1);
    });

    test('centers content inset on wide viewports', () {
      expect(
        ArchiveResponsiveLayout.horizontalCenterInset(viewportWidth: 1000),
        140,
      );
      expect(
        ArchiveResponsiveLayout.horizontalCenterInset(viewportWidth: 600),
        0,
      );
    });
  });

  group('ArchiveEntryCard', () {
    testWidgets('registers hero tags for card-to-detail transitions', (
      tester,
    ) async {
      final entry = _entry(id: 'hero-entry');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveEntryCard(entry: entry, onTap: () {}),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Hero &&
              widget.tag == ArchiveEntryHeroTags.surface('hero-entry'),
        ),
        findsOneWidget,
      );
    });
  });
}
