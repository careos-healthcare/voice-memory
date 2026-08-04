import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_model.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_parser.dart';

void main() {
  group('parseArchiveSearchQuery', () {
    test('recognises lastSeen', () {
      expect(
        parseArchiveSearchQuery('When did this last show up?').intent,
        ArchiveSearchIntent.lastSeen,
      );
    });

    test('recognises helpedBefore', () {
      expect(
        parseArchiveSearchQuery('What helped before?').intent,
        ArchiveSearchIntent.helpedBefore,
      );
      expect(
        parseArchiveSearchQuery('what helped').intent,
        ArchiveSearchIntent.helpedBefore,
      );
    });

    test('recognises momentsAbout with topic', () {
      final query = parseArchiveSearchQuery('Show moments about work');
      expect(query.intent, ArchiveSearchIntent.momentsAbout);
      expect(query.normalizedTerm, 'work');
    });

    test('recognises feltLighter and feltHeavier', () {
      expect(
        parseArchiveSearchQuery('When did it feel lighter?').intent,
        ArchiveSearchIntent.feltLighter,
      );
      expect(
        parseArchiveSearchQuery('felt heavier').intent,
        ArchiveSearchIntent.feltHeavier,
      );
    });

    test('recognises changed and thisWeek', () {
      expect(
        parseArchiveSearchQuery('What changed this week?').intent,
        ArchiveSearchIntent.changed,
      );
      expect(
        parseArchiveSearchQuery('this week').intent,
        ArchiveSearchIntent.thisWeek,
      );
    });

    test('falls back to freeText', () {
      expect(
        parseArchiveSearchQuery('the meeting').intent,
        ArchiveSearchIntent.freeText,
      );
    });
  });
}
