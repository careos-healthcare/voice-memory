import 'package:archiveme_mobile/features/pattern_review_inbox/pattern_review_inbox_copy.dart';
import 'package:archiveme_mobile/features/pattern_review_inbox/pattern_review_inbox_engine.dart';
import 'package:archiveme_mobile/features/pattern_review_inbox/pattern_review_inbox_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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
  group('PatternReviewInboxCopy', () {
    test('stable card and sheet copy', () {
      expect(PatternReviewInboxCopy.cardTitle, 'Review your archive');
      expect(
        PatternReviewInboxCopy.sheetSubtitle,
        'Things ArchiveMe needs your judgement on.',
      );
      expect(
        PatternReviewInboxCopy.emptyTitle,
        'Nothing needs review right now',
      );
    });

    test('does not use banned journal or progress language', () {
      final blob = PatternReviewInboxCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('journal')));
      expect(blob, isNot(contains('progress')));
      expect(blob, isNot(contains('streak')));
    });
  });

  group('PatternReviewInboxEngine', () {
    test('returns empty inbox with no entries', () {
      final result = PatternReviewInboxEngine.build(entries: const []);
      expect(result.isEmpty, isTrue);
      expect(result.entryCount, 0);
      expect(result.previewItems, isEmpty);
    });

    test('returns empty inbox for placeholder-only entries', () {
      final result = PatternReviewInboxEngine.build(
        entries: [_entry(id: 'e1', transcript: _placeholder)],
      );
      expect(result.isEmpty, isTrue);
    });

    test('preview limit caps surfaced items', () {
      expect(PatternReviewInboxEngine.previewLimit, 3);
    });

    test('item types expose stable analytics values', () {
      expect(
        PatternReviewInboxItemType.firstProofTruth.analyticsValue,
        'first_proof_truth',
      );
      expect(
        PatternReviewInboxItemType.quietSignal.analyticsValue,
        'quiet_signal',
      );
    });
  });
}