import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/local_text_comparison_engine.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveMomentRecord _moment({
  required String id,
  required String words,
  required DateTime createdAt,
}) => ArchiveMomentRecord(id: id, createdAt: createdAt, savedWords: words);

void main() {
  group('LocalTextComparisonEngine', () {
    const engine = LocalTextComparisonEngine();

    test('buildFromRawTextHistory returns structured result for grounded text', () {
      final result = engine.buildFromRawTextHistory(
        current: _moment(
          id: 'e2',
          words:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime.utc(2026, 6, 12, 12),
        ),
        history: [
          _moment(
            id: 'e1',
            words:
                'I said yes again even though I was already tired from work today.',
            createdAt: DateTime.utc(2026, 6, 11, 12),
          ),
        ],
      );

      expect(result.matchedPastQuote, isNotEmpty);
      expect(result.matchedCurrentQuote, isNotEmpty);
      expect(result.connectionSummary, startsWith('This may connect to'));
      expect(result.evolutionAnalysis, isNotEmpty);
    });

    test(
      'buildFromRawTextHistory returns notEnoughEvidence for unrelated text',
      () {
        final result = engine.buildFromRawTextHistory(
          current: _moment(
            id: 'b',
            words: 'I reorganized my bookshelf today.',
            createdAt: DateTime.utc(2026, 6, 12, 12),
          ),
          history: [
            _moment(
              id: 'a',
              words: 'A calm afternoon walk helped me slow down.',
              createdAt: DateTime.utc(2026, 6, 11, 12),
            ),
          ],
        );

        expect(result.alignmentState, PatternState.notEnoughEvidence);
        expect(result.connectionSummary, 'A repeating thread may be forming.');
      },
    );
  });
}