import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';

JournalEntry _entry({String id = 'e1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          'I felt pressure to keep going even when I wanted to stop for the day.',
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

PressureCheckInRecord _pressureRecord({String id = 'e1'}) =>
    PressureCheckInRecord(
      entryId: id,
      createdAt: DateTime(2026, 6, 12, 12),
      optionId: 'could_not_stop',
      contextIds: const ['work'],
      transcript: 'pressure moment',
    );

const _bannedOneEntryWords = [
  'repeating',
  'repeat',
  'loop',
  'pressure loop',
  'pattern found',
  'working hypothesis',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedOneEntryCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final banned in _bannedOneEntryWords) {
      expect(
        lower,
        isNot(contains(banned)),
        reason: 'one-entry UI must not contain "$banned" in "$text"',
      );
    }
  }
}

void main() {
  group('one-entry post-save copy', () {
    test('done-for-today receipt uses neutral one-entry lines', () {
      const engine = DoneForTodayReceiptEngine();
      final receipt = engine.build(saved: true, entryCount: 1);
      expect(receipt.archiveLine, VisibleArchiveProofCopy.oneEntryAddedTodayLine);
      expect(receipt.tomorrowLine, VisibleArchiveProofCopy.oneEntryTomorrowLine);
      _expectNoBannedOneEntryCopy([receipt.archiveLine, receipt.tomorrowLine]);
    });

    test('shareable proof stays hidden before three entries', () {
      const engine = ShareableArchiveProofEngine();
      final proof = engine.build(
        [_pressureRecord()],
        savedToday: true,
        entryCount: 1,
      );
      expect(proof.hasProof, isFalse);
    });

    test('first-save evidence copy avoids premature pattern claims', () {
      expect(
        RecordReturnProCopy.evidenceBody,
        isNot(contains('what repeats')),
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        contains('second moment'),
      );
      _expectNoBannedOneEntryCopy([
        RecordReturnProCopy.evidenceBody,
        RecordReturnProCopy.evidenceSecondLine,
        RecordReturnProCopy.evidenceThirdLine,
      ]);
    });

    test('two-entry comparison copy remains available', () {
      final comparison = const SecondSessionSignalEngine().build([
        _entry(id: '1'),
        JournalEntry(
          id: '2',
          createdAt: DateTime(2026, 6, 13, 12),
          transcript:
              'I took responsibility again before asking anyone for help today.',
          durationSeconds: 30,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Work pressure showed up again today.',
            repeatedSignal: '',
          ),
        ),
      ]);
      expect(comparison.hasEnoughData, isTrue);
      expect(comparison.title, isNotEmpty);
    });

    testWidgets('one-entry cards render neutral copy without share proof', (
      tester,
    ) async {
      const doneEngine = DoneForTodayReceiptEngine();
      final doneReceipt = doneEngine.build(saved: true, entryCount: 1);
      const shareEngine = ShareableArchiveProofEngine();
      final shareProof = shareEngine.build(
        [_pressureRecord()],
        savedToday: true,
        entryCount: 1,
      );
      expect(shareProof.hasProof, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  FirstSaveEvidenceCard(
                    onViewArchive: () {},
                    onRecordAnother: () {},
                  ),
                  DoneForTodayReceiptCard(receipt: doneReceipt),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(RecordReturnProCopy.evidenceTitle), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.oneEntryAddedTodayLine),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shareable_archive_proof_card')), findsNothing);
      _expectNoBannedOneEntryCopy(_visibleText(tester));
    });
  });
}
