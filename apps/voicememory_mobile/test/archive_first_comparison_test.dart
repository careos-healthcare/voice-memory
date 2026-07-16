import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_first_comparison_display.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_first_comparison_ui_gates.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

void main() {
  group('ArchiveFirstComparisonUiGates', () {
    test('shows calm card only at two eligible entries', () {
      expect(
        ArchiveFirstComparisonUiGates.showCalmFirstComparisonCard(
          eligibleEntryCount: 1,
        ),
        isFalse,
      );
      expect(
        ArchiveFirstComparisonUiGates.showCalmFirstComparisonCard(
          eligibleEntryCount: 2,
        ),
        isTrue,
      );
      expect(
        ArchiveFirstComparisonUiGates.showCalmFirstComparisonCard(
          eligibleEntryCount: 3,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveFirstComparisonDisplay', () {
    test('ungrounded two entries use compare framing without evidence line', () {
      final display = ArchiveFirstComparisonDisplay.resolve([
        _entry(
          id: 'a',
          transcript: 'A quiet moment about lunch with a friend today.',
        ),
        _entry(
          id: 'b',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ]);

      expect(display.show, isTrue);
      expect(display.title, VisibleArchiveProofCopy.twoEntryCompareTitle);
      expect(display.body, VisibleArchiveProofCopy.twoEntryBodyUngrounded);
      expect(display.evidenceLine, isNull);
      expect(display.primaryIsViewEvidence, isFalse);
    });

    test('grounded two entries use came-back framing with evidence', () {
      final display = ArchiveFirstComparisonDisplay.resolve([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ]);

      expect(display.show, isTrue);
      expect(display.title, VisibleArchiveProofCopy.archiveFirstComparisonTitle);
      expect(display.body, VisibleArchiveProofCopy.archiveFirstComparisonBody);
      expect(display.primaryIsViewEvidence, isTrue);
      expect(display.hasGroundedPattern, isTrue);
      expect(display.evidenceLine, isNotNull);
      expect(display.evidenceLine, isNotEmpty);
    });
  });
}
