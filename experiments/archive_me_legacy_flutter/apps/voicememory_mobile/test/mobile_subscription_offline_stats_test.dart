import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/mobile_subscription_screen.dart';

JournalEntry _entry(int index) => JournalEntry(
  id: 'entry-$index',
  createdAt: DateTime.utc(2026, 7, index + 1),
  transcript: 'A useful local reflection about work and priorities.',
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work has appeared repeatedly.',
    repeatedSignal: '',
  ),
);

void main() {
  testWidgets(
    'personalized local stats survive advanced failure while offline',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MobileSubscriptionScreen(
            subscriptionsAvailableOverride: false,
            journalLoader: () async => List.generate(6, _entry),
            archiveViewBuilder: (_) async =>
                throw StateError('advanced builder unavailable'),
            growthLoader: () async => throw StateError('growth unavailable'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('6 recordings'), findsWidgets);
      expect(find.text('Yearly'), findsNothing);
      expect(find.text('Monthly'), findsNothing);
    },
  );
}
