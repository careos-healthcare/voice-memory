import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentences a user reads as prose. Button and field labels are excluded:
/// "Cancel" and "Their name" are one-clause fragments, and averaging them in
/// would drag the grade level down without anyone reading more easily.
final List<String> _prose = CaregiverGrantCopy.all
    .where((line) => line.contains('.'))
    .toList();

final RegExp _sentenceSplit = RegExp('[.!?]+');
final RegExp _wordSplit = RegExp("[^A-Za-z’'-]+");
final RegExp _vowelGroup = RegExp('[aeiouy]+');

List<String> _sentences(String text) => text
    .split(_sentenceSplit)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

List<String> _words(String text) => text
    .split(_wordSplit)
    .map((w) => w.trim())
    .where((w) => w.isNotEmpty)
    .toList();

/// Vowel-group syllable estimate with the usual silent-e correction.
///
/// Crude, and knowingly so: it over-counts words like "moments" and
/// under-counts "area". Over a corpus the error is small and consistent, which
/// is why the assertion below is on the corpus rather than on any one line.
int syllablesIn(String word) {
  final lower = word.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (lower.isEmpty) return 0;
  var count = _vowelGroup.allMatches(lower).length;
  if (lower.endsWith('e') && !lower.endsWith('le') && count > 1) count -= 1;
  return count < 1 ? 1 : count;
}

/// Flesch-Kincaid grade level for [text].
double fleschKincaidGrade(String text) {
  final sentences = _sentences(text);
  final words = _words(text);
  if (sentences.isEmpty || words.isEmpty) return 0;
  final syllables = words.fold<int>(0, (sum, w) => sum + syllablesIn(w));
  return 0.39 * (words.length / sentences.length) +
      11.8 * (syllables / words.length) -
      15.59;
}

void main() {
  group('caregiver grant copy reading level', () {
    test('the corpus sits around a sixth-grade reading level', () {
      final grade = fleschKincaidGrade(_prose.join(' '));

      // Ceiling rather than a band: copy that got *easier* to read is not a
      // regression worth a red build. 6.5 is the 6th-grade target itself
      // rather than a padded version of it — the corpus measures about 3.7,
      // so there is room for a longer sentence before this trips, and it
      // still fails on prose that drifts toward the legalese control below.
      expect(
        grade,
        lessThan(6.5),
        reason: 'Flesch-Kincaid grade ${grade.toStringAsFixed(2)}',
      );
    });

    test('no sentence runs long enough to lose a reader', () {
      final offenders = <String, int>{};
      for (final line in _prose) {
        for (final sentence in _sentences(line)) {
          final length = _words(sentence).length;
          if (length > 25) offenders[sentence] = length;
        }
      }

      expect(offenders, isEmpty);
    });

    test('the grade calculation itself is not vacuous', () {
      // A control: dense clause-stacked prose has to score above the ceiling,
      // otherwise the assertion above could pass on anything.
      const dense =
          'Notwithstanding the aforementioned contractual provisions, the '
          'authorization heretofore granted constitutes an irrevocable '
          'delegation of interpretive authority, the ramifications of which '
          'encompass substantially all derivative representations.';

      expect(fleschKincaidGrade(dense), greaterThan(14));
      expect(fleschKincaidGrade(_prose.join(' ')), lessThan(6.5));
    });
  });
}
