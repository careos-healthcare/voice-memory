import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_insights_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_loop_visibility_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_weekly_recap_model.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_loop_visibility_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_weekly_recap_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PressureCheckInRecord _record({required String id}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12),
    optionId: 'did_more_to_not_feel_behind',
    contextIds: const ['work'],
    transcript: 'I did more so I would not feel behind.',
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: false),
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PressureInsightsCopy', () {
    test('strong loop language requires two or more entries', () {
      expect(PressureInsightsCopy.hasStrongLoopEvidence(0), isFalse);
      expect(PressureInsightsCopy.hasStrongLoopEvidence(1), isFalse);
      expect(PressureInsightsCopy.hasStrongLoopEvidence(2), isTrue);
    });

    test('early copy for one entry', () {
      expect(PressureInsightsCopy.screenTitle(1), 'Early pressure signal');
      expect(PressureInsightsCopy.pageTitle(1), 'What may be repeating');
      expect(
        PressureInsightsCopy.visibilityCardTitle(1),
        'What you noticed this week',
      );
      expect(PressureInsightsCopy.weeklyRecapTitle(1), 'This week so far');
    });

    test('strong copy for two or more entries', () {
      expect(PressureInsightsCopy.screenTitle(2), 'Your pressure loop');
      expect(
        PressureInsightsCopy.pageTitle(2),
        'What your pressure loop looks like',
      );
      expect(
        PressureInsightsCopy.visibilityCardTitle(2),
        'Your pressure loop, this week',
      );
      expect(PressureInsightsCopy.weeklyRecapTitle(2), 'Weekly pressure recap');
    });
  });

  group('Pressure insights screen — one entry', () {
    testWidgets('uses early-signal copy and add-moment CTA', (tester) async {
      await _pumpScreen(tester, records: [_record(id: 'a')]);

      expect(find.text('Early pressure signal'), findsOneWidget);
      expect(find.text('What may be repeating'), findsOneWidget);
      expect(find.text('What you noticed this week'), findsOneWidget);
      expect(find.text('This week so far'), findsOneWidget);
      expect(find.text(PressureInsightsCopy.addMomentCtaEarly), findsOneWidget);

      expect(find.text('Your pressure loop'), findsNothing);
      expect(find.text('What your pressure loop looks like'), findsNothing);
      expect(find.text('Your pressure loop, this week'), findsNothing);
      expect(find.text('Weekly pressure recap'), findsNothing);
      expect(find.text('Log pressure moment'), findsNothing);
    });
  });

  group('Pressure insights screen — two entries', () {
    testWidgets('uses stronger pressure-loop copy', (tester) async {
      await _pumpScreen(
        tester,
        records: [
          _record(id: 'a'),
          _record(id: 'b'),
        ],
      );

      expect(find.text('Your pressure loop'), findsOneWidget);
      expect(find.text('What your pressure loop looks like'), findsOneWidget);
      expect(find.text('Your pressure loop, this week'), findsOneWidget);
      expect(find.text('Weekly pressure recap'), findsOneWidget);

      expect(find.text('Early pressure signal'), findsNothing);
      expect(find.text('What may be repeating'), findsNothing);
      expect(find.text('What you noticed this week'), findsNothing);
      expect(find.text('This week so far'), findsNothing);
      expect(find.text(PressureInsightsCopy.addMomentCtaEarly), findsNothing);
    });
  });

  group('Pressure cards', () {
    testWidgets('visibility card title follows entry count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PressureLoopVisibilityCard(
              visibility: PressureLoopVisibility(
                noticedThisWeek: 1,
                choseToStopCount: 0,
                strongestPhrase: null,
                streakDays: 0,
              ),
              entryCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('What you noticed this week'), findsOneWidget);
      expect(find.text('Your pressure loop, this week'), findsNothing);
    });

    testWidgets('weekly recap card title follows entry count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PressureWeeklyRecapCard(
              recap: PressureWeeklyRecap(
                count: 1,
                mostCommonOptionLabel: null,
                mostCommonContextLabel: null,
                choseToStopCount: 0,
                sentence: 'One pressure moment this week.',
              ),
              entryCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This week so far'), findsOneWidget);
      expect(find.text('Weekly pressure recap'), findsNothing);
    });
  });
}