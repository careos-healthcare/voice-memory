import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_services_test_lifecycle.dart';
import 'support/test_storage_sandbox.dart';

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

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await settleAppServicesForTest();
    await sandbox.dispose();
  });

  Future<void> pumpOnThisDay(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: OnThisDaySection()),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('OnThisDaySection hides when selectByAnniversary is empty', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'other-day',
          createdAt: DateTime(now.year - 1, now.month, now.day == 1 ? 2 : 1),
          transcript: 'I want to spend more time traveling abroad',
        ),
      );
    });

    await pumpOnThisDay(tester);

    expect(find.text('On this day'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(OnThisDaySection), findsOneWidget);
  });

  testWidgets('OnThisDaySection shows cards from selectByAnniversary', (
    tester,
  ) async {
    final now = DateTime.now();
    final lastYear = DateTime(now.year - 1, now.month, now.day, 10);
    await tester.runAsync(() async {
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'last-year',
          createdAt: lastYear,
          transcript: 'I want to spend more time traveling abroad',
        ),
      );
    });

    await pumpOnThisDay(tester);

    expect(find.text('On this day'), findsOneWidget);
    expect(find.text('From past years on this date'), findsOneWidget);
    expect(find.text('1 year ago today'), findsOneWidget);
    expect(find.text('"time traveling abroad"'), findsOneWidget);
  });

  testWidgets(
    'empty beliefRelation does not render empty Text or extra spacing',
    (tester) async {
      final now = DateTime.now();
      final lastYear = DateTime(now.year - 1, now.month, now.day, 10);
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'unrelated-anniversary',
            createdAt: lastYear,
            transcript: 'I want to spend more time traveling abroad',
            themes: const ['travel'],
          ),
        );
      });

      await pumpOnThisDay(tester);

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
