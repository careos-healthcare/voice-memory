import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/journal_sync_api_client.dart';
import 'package:voicememory_mobile/features/pattern_recognition/pattern_recognition_dashboard_provider.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _FakeJournalSyncApiClient extends JournalSyncApiClient {
  _FakeJournalSyncApiClient(this.entries)
    : super(ApiTransport(baseUrl: 'https://example.invalid'));

  final List<JournalEntry> entries;
  var listCalls = 0;

  @override
  Future<List<JournalEntry>> listJournal() async {
    listCalls++;
    return entries;
  }
}

JournalEntry _entry(String id, String mood, int intensity) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 7, 20 + int.parse(id)),
  transcript: 'A journal memory about protecting time.',
  durationSeconds: 30,
  reflection: Reflection(
    mood: mood,
    emotionalIntensity: intensity,
    recurringThemes: const ['boundaries', 'work'],
    exactLanguagePattern: '',
    concreteObservation: 'You protected time before another commitment.',
    repeatedSignal: '',
  ),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pattern_dashboard_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await AppServices.disposeForTest();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('fetches analyzed entries through JournalSyncApiClient', () async {
    final api = _FakeJournalSyncApiClient([
      _entry('1', 'calm', 2),
      _entry('2', 'calm', 3),
      _entry('3', 'tense', 4),
    ]);
    final container = ProviderContainer(
      overrides: [journalSyncApiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final dashboard = await container.read(
      patternRecognitionDashboardProvider.future,
    );

    expect(api.listCalls, 1);
    expect(dashboard.entries, hasLength(3));
    expect(dashboard.recurringTopics.first.label, 'boundaries');
    expect(dashboard.recurringTopics.first.count, 3);
    expect(dashboard.moodTrends.first.mood, 'calm');
    expect(dashboard.moodTrends.first.averageIntensity, 2.5);
    expect(dashboard.loadedFromLocalFallback, isFalse);
  });
}
