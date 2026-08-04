import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_home/archive_journal_home.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  required DateTime createdAt,
  String? audioVaultReference,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: audioVaultReference == null ? 0 : 12,
  localAudioVaultRef: audioVaultReference,
  reflection: const Reflection(
    mood: 'steady',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  testWidgets('journal is chronological and source cards open real entries', (
    tester,
  ) async {
    String? opened;
    var searched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveJournalHome(
            entries: [
              _entry(
                id: 'older',
                transcript: 'An older text moment.',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
              _entry(
                id: 'newer',
                transcript: 'A newer voice moment.',
                createdAt: DateTime.utc(2026, 1, 2),
                audioVaultReference: 'vault:newer',
              ),
            ],
            onRefresh: () async {},
            onOpenMoment: (id) => opened = id,
            onSearch: () => searched = true,
            onOpenInsights: () {},
            onRecord: () {},
          ),
        ),
      ),
    );

    final newer = find.text('A newer voice moment.');
    final older = find.text('An older text moment.');
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));
    await tester.tap(newer);
    expect(opened, 'newer');
    await tester.tap(find.byKey(const Key('archive_journal_search')));
    expect(searched, isTrue);
  });

  testWidgets('compact filters preserve entries and support text scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: ArchiveJournalHome(
              entries: [
                _entry(
                  id: 'text',
                  transcript: 'Text only.',
                  createdAt: DateTime.utc(2026, 1, 1),
                ),
                _entry(
                  id: 'voice',
                  transcript: 'Voice only.',
                  createdAt: DateTime.utc(2026, 1, 2),
                  audioVaultReference: 'vault:voice',
                ),
              ],
              onRefresh: () async {},
              onOpenMoment: (_) {},
              onSearch: () {},
              onOpenInsights: () {},
              onRecord: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('archive_journal_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text').last);
    await tester.pumpAndSettle();

    expect(find.text('Text only.'), findsOneWidget);
    expect(find.text('Voice only.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly progress is restrained and non-punitive', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveJournalHome(
            entries: [
              _entry(
                id: 'foundation',
                transcript: 'An older foundation moment.',
                createdAt: now.subtract(const Duration(days: 10)),
              ),
              _entry(
                id: 'this-week',
                transcript: 'A meaningful moment this week.',
                createdAt: now.subtract(const Duration(days: 1)),
              ),
            ],
            onRefresh: () async {},
            onOpenMoment: (_) {},
            onSearch: () {},
            onOpenInsights: () {},
            onRecord: () {},
          ),
        ),
      ),
    );

    expect(find.text('1 meaningful moment this week'), findsOneWidget);
    expect(find.textContaining('streak'), findsNothing);
    expect(find.textContaining('failed'), findsNothing);
  });
}
