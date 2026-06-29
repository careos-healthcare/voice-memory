import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/record/record_empty_archive_gates.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/record/early_first_signal_card.dart';

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

const _bannedStrongBelief = [
  'your archive believes',
  'pattern found',
  'confirmed belief',
  'working hypothesis',
];

void main() {
  group('RecordEmptyArchiveGates.showEarlyFirstSignalCard', () {
    test('hidden at zero entries', () {
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 0,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('shown at one and two entries when not post-save', () {
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 1,
          isPostSave: false,
        ),
        isTrue,
      );
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 2,
          isPostSave: false,
        ),
        isTrue,
      );
    });

    test('hidden during post-save and after two entries', () {
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 1,
          isPostSave: true,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 3,
          isPostSave: false,
        ),
        isFalse,
      );
    });
  });

  group('EarlyFirstSignalEngine', () {
    test('returns null at zero entries — no fake pattern', () {
      expect(EarlyFirstSignalEngine.build(entries: const []), isNull);
    });

    test('one entry is a heard receipt without pattern language', () {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(model, isNotNull);
      expect(model!.kind, EarlyFirstSignalKind.oneEntryReceipt);
      expect(model.title, EarlyFirstSignalCopy.oneEntryTitle);
      expect(model.lines, contains(EarlyFirstSignalCopy.notEnoughEvidence));
      expect(model.showsPatternLanguage, isFalse);
      for (final banned in _bannedStrongBelief) {
        expect(
          '${model.title} ${model.lines.join(' ')}'.toLowerCase(),
          isNot(contains(banned)),
        );
      }
    });

    test('two unrelated entries do not force a pattern', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isFalse,
      );

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryNoPattern);
      expect(model.title, EarlyFirstSignalCopy.twoEntryNoPatternTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.twoEntryNoPatternBody);
      expect(model.showsPatternLanguage, isFalse);
      expect(
        '${model.title} ${model.lines.join(' ')}',
        isNot(contains('start of a pattern')),
      );
    });

    test('two related entries show cautious first-signal copy', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isTrue,
      );

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryFirstSignal);
      expect(model.title, EarlyFirstSignalCopy.twoEntryPatternStartTitle);
      expect(model.lines, contains(EarlyFirstSignalCopy.twoEntryNoticedAgain));
      expect(model.lines, contains(EarlyFirstSignalCopy.notEnoughEvidence));
      expect(
        model.lines,
        contains(EarlyFirstSignalCopy.twoEntryConfirmRepeat),
      );
    });
  });

  group('EarlyFirstSignalCard', () {
    testWidgets('renders first-signal lines for grounded two entries', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I said yes again even though I was already tired from work today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _entry(
            id: 'e2',
            transcript:
                'I took responsibility again before asking anyone for help today.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyFirstSignalCard(
              signal: model!,
              onPrimary: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('early_first_signal_card')), findsOneWidget);
      expect(
        find.text(EarlyFirstSignalCopy.twoEntryPatternStartTitle),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.twoEntryNoticedAgain),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.notEnoughEvidence),
        findsOneWidget,
      );
    });
  });
}
