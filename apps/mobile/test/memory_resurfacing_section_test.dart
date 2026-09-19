import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  List<String> themes = const [],
  String exactLanguagePattern = 'time traveling abroad',
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: exactLanguagePattern,
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

MemoryResurfacingCardData _card({
  required String id,
  required String headline,
  String quoteSnippet = 'time traveling abroad',
  String originalDateLabel = 'May 19, 2025',
  String beliefRelation = '',
}) {
  return MemoryResurfacingCardData(
    entry: _entry(
      id: id,
      createdAt: DateTime(2025, 5, 19, 10),
      transcript: 'I want to spend more time traveling abroad',
    ),
    headline: headline,
    quoteSnippet: quoteSnippet,
    originalDateLabel: originalDateLabel,
    beliefRelation: beliefRelation,
  );
}

Future<void> pumpOnThisDay(
  WidgetTester tester, {
  required List<MemoryResurfacingCardData> cards,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnThisDaySection(
          cards: cards,
          onCardTap: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('OnThisDaySection hides when selectByAnniversary is empty', (
    tester,
  ) async {
    await pumpOnThisDay(tester, cards: const []);

    expect(find.text('On this day'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(OnThisDaySection), findsOneWidget);
  });

  testWidgets('OnThisDaySection shows cards from selectByAnniversary', (
    tester,
  ) async {
    await pumpOnThisDay(
      tester,
      cards: [
        _card(
          id: 'last-year',
          headline: '1 year ago today',
        ),
      ],
    );

    expect(find.text('On this day'), findsOneWidget);
    expect(find.text('From past years on this date'), findsOneWidget);
    expect(find.text('1 year ago today'), findsOneWidget);
    expect(find.text('"time traveling abroad"'), findsOneWidget);
  });

  testWidgets(
    'empty beliefRelation does not render empty Text or extra spacing',
    (tester) async {
      await pumpOnThisDay(
        tester,
        cards: [
          _card(
            id: 'unrelated-anniversary',
            headline: '1 year ago today',
            beliefRelation: '',
          ),
        ],
      );

      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('1 year ago today'), findsOneWidget);

      final emptyTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.data != null && text.data!.isEmpty);
      expect(emptyTexts, isEmpty);

      final cardColumnFinder = find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Column),
      );
      expect(cardColumnFinder, findsOneWidget);
      final column = tester.widget<Column>(cardColumnFinder);
      expect(column.children, hasLength(5));
      final last = column.children.last;
      expect(last, isA<Text>());
      expect((last as Text).data, isNotEmpty);
    },
  );
}
