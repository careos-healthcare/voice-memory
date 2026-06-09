import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/empty_states/search_empty_state.dart';

void main() {
  test('search empty copy matches spec', () {
    expect(SearchEmptyCopy.title, 'Nothing to search yet');
    expect(
      SearchEmptyCopy.body,
      'As you record thoughts, your archive becomes searchable.',
    );
    expect(SearchEmptyCopy.searchableBullets, hasLength(4));
    expect(SearchEmptyCopy.exampleSearchTerms, hasLength(4));
    expect(SearchEmptyCopy.closing, contains('searchable archive'));
    expect(SearchEmptyState.semanticsLabel, contains('confidence'));
  });

  test('searchHasNoRecordings true only for zero entries', () {
    expect(searchHasNoRecordings([]), isTrue);
    expect(
      searchHasNoRecordings([
        JournalEntry(
          id: 'e1',
          createdAt: DateTime(2026, 1, 1),
          transcript: 'Hello world from a reflection.',
          durationSeconds: 10,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 1,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      ]),
      isFalse,
    );
  });
}
