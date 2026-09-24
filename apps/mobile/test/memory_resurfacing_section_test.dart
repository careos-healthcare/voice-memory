import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryResurfacingCardData _card() {
  return MemoryResurfacingCardData(
    entry: JournalEntry(
      id: 'last-year',
      createdAt: DateTime(2025, 5, 19, 10),
      transcript: 'I want to spend more time traveling abroad',
      durationSeconds: 40,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: 'time traveling abroad',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    ),
    headline: '1 year ago today',
    quoteSnippet: 'time traveling abroad',
    originalDateLabel: 'May 19, 2025',
    beliefRelation: '',
  );
}

void main() {
  testWidgets('empty resurfacing feed contributes no slivers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: memoryResurfacingFeedSlivers(
              title: 'On this day',
              cards: const [],
              onCardTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('On this day'), findsNothing);
  });

  testWidgets('resurfacing feed shows the section title and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: memoryResurfacingFeedSlivers(
              title: 'On this day',
              subtitle: 'From past years on this date',
              cards: [_card()],
              onCardTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('On this day. From past years on this date'),
      findsOneWidget,
    );
  });
}
