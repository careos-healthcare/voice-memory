import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/coaching/services/coaching_engine_service.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('coaching_engine_');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('analyzePattern identifies evidence repeated across entries', () async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final store = await _openStore(tempDirectory, const []);
    final service = CoachingEngineService(
      journalStore: store,
      clock: () => now,
    );
    final entries = [
      _entry(
        id: 'one',
        createdAt: now,
        transcript: 'My workload rises when I skip planning.',
        themes: const ['workload'],
      ),
      _entry(
        id: 'two',
        createdAt: now.subtract(const Duration(hours: 2)),
        transcript: 'The workload felt easier after planning.',
        themes: const ['workload'],
      ),
    ];

    final insight = await service.analyzePattern(entries);

    expect(insight, isNotNull);
    expect(insight!.category, 'Recurring Pattern');
    expect(insight.content, contains('Workload'));
    expect(insight.sourceEntryIds, containsAll(['one', 'two']));
    expect(insight.confidenceScore, inInclusiveRange(0, 1));
  });

  test('generateDailyBriefing includes only the last 24 hours', () async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final entries = [
      _entry(
        id: 'recent',
        createdAt: now.subtract(const Duration(hours: 4)),
        transcript: 'Planning made the afternoon calmer.',
        themes: const ['planning'],
      ),
      _entry(
        id: 'old',
        createdAt: now.subtract(const Duration(hours: 30)),
        transcript: 'An older archived thought.',
        themes: const ['history'],
      ),
    ];
    final store = await _openStore(tempDirectory, entries);
    final service = CoachingEngineService(
      journalStore: store,
      clock: () => now,
    );

    final insight = await service.generateDailyBriefing();

    expect(insight, isNotNull);
    expect(insight!.category, 'Daily Summary');
    expect(insight.sourceEntryIds, ['recent']);
    expect(insight.content, contains('1 entry'));
    expect(insight.content, contains('Planning'));
  });
}

Future<JournalStore> _openStore(
  Directory directory,
  List<JournalEntry> entries,
) async {
  final file = File('${directory.path}/journal.json');
  await file.writeAsString(
    jsonEncode(entries.map((entry) => entry.toJson()).toList()),
  );
  return JournalStore.open(
    file.path,
    encryptAtRest: false,
    syncDeviceIdProvider: () async => 'test-device',
  );
}

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 10,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 3,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}
