import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/features/search/voice_memory_search.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 5),
    transcript: transcript,
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: 'I notice a pattern at work',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('searchArchiveMe finds recordings by transcript and tags', () {
    final index = VoiceMemorySearchIndex(
      entries: [
        _entry(id: '1', transcript: 'Meeting stress today', themes: ['work']),
      ],
      discoverFeed: const DiscoverLocalFeed(
        hasBaseline: false,
        totalChanges: 0,
        strengthened: [],
        weakened: [],
        newItems: [],
        evidenceMovements: [],
      ),
    );

    final results = searchArchiveMe(index, 'stress');
    expect(results, isNotEmpty);
    expect(results.first.type, SearchResultType.recording);
    expect(results.first.route, '/entry/1');
  });

  test('searchArchiveMe finds discovery titles', () {
    final index = VoiceMemorySearchIndex(
      entries: const [],
      discoverFeed: const DiscoverLocalFeed(
        hasBaseline: true,
        totalChanges: 1,
        strengthened: [
          DiscoverChangeItem(
            title: 'boundaries',
            detail: 'Showing up more often',
            kind: 'strengthened',
          ),
        ],
        weakened: [],
        newItems: [],
        evidenceMovements: [],
      ),
    );

    final results = searchArchiveMe(index, 'boundaries');
    expect(results.single.type, SearchResultType.discovery);
    expect(results.single.route, '/discover-yourself');
  });

  test('searchArchiveMe returns empty for blank query', () {
    final index = VoiceMemorySearchIndex(
      entries: [_entry(id: '1', transcript: 'hello')],
      discoverFeed: const DiscoverLocalFeed(
        hasBaseline: false,
        totalChanges: 0,
        strengthened: [],
        weakened: [],
        newItems: [],
        evidenceMovements: [],
      ),
    );
    expect(searchArchiveMe(index, '   '), isEmpty);
  });
}