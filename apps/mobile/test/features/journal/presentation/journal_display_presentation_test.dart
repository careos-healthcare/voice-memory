import 'package:archiveme_mobile/features/journal/presentation/models/journal_display_presentation.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

void main() {
  group('JournalDisplayPresentation', () {
    test('maps persisted metadata to UI-facing display state', () {
      final entry = JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026),
        transcript: 'hello',
        durationSeconds: 1,
        reflection: _reflection(),
        isPinned: true,
        entryAboutness: 'about_someone_else',
        memorySurfacing: 'reduced',
      );

      final presentation = JournalDisplayPresentation.fromEntry(entry);
      expect(presentation.isPinned, isTrue);
      expect(presentation.showPinBadge, isTrue);
      expect(presentation.isAboutSomeoneElse, isTrue);
      expect(presentation.isReducedMemorySurfacing, isTrue);
      expect(presentation.aboutnessLabel, 'About someone else');
      expect(presentation.memorySurfacingLabel, 'Reduced resurfacing');
    });

    test('fromMetadata preserves persistence fields', () {
      const metadata = JournalDisplayMetadata(
        captureContextTag: 'linked-detail',
        captureSource: 'typed',
      );
      final presentation = JournalDisplayPresentation.fromMetadata(metadata);
      expect(presentation.captureContextTag, 'linked-detail');
      expect(presentation.captureSource, 'typed');
    });
  });
}
