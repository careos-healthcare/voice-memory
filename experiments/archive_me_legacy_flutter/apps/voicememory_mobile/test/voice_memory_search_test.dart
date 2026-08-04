import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/discover/discover_local.dart';
import 'package:voicememory_mobile/features/search/voice_memory_search.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 5, 1),
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
      discoverFeed: DiscoverLocalFeed(
        hasBaseline: true,
        totalChanges: 1,
        strengthened: [
          DiscoverChangeItem(
            title: 'boundaries',
            detail: 'Showing up more often',
            kind: 'strengthened',
          ),
        ],
        weakened: const [],
        newItems: const [],
        evidenceMovements: const [],
      ),
    );

    final results = searchArchiveMe(index, 'boundaries');
    expect(results.single.type, SearchResultType.discovery);
    expect(results.single.route, '/archive-belief');
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
