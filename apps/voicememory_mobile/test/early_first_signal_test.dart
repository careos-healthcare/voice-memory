import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_record_routes.dart';
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

    test('shown at one through three entries when not post-save', () {
      for (final count in [1, 2, 3]) {
        expect(
          RecordEmptyArchiveGates.showEarlyFirstSignalCard(
            loaded: true,
            entryCount: count,
            isPostSave: false,
          ),
          isTrue,
        );
      }
    });

    test('hidden during post-save and after three entries', () {
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
          entryCount: 4,
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
      expect(model.showsConfirmedRepeat, isFalse);
    });

    test('three related entries show confirmed repeat with evidence', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(entries), isTrue);

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.threeEntryConfirmedRepeat);
      expect(model.title, EarlyFirstSignalCopy.threeEntryConfirmedTitle);
      expect(
        model.lines,
        contains(EarlyFirstSignalCopy.threeEntrySeenThreeTimes),
      );
      expect(model.lines, contains(EarlyFirstSignalCopy.evidenceHeading));
      expect(model.evidenceRows.length, 3);
      expect(model.primaryCta, EarlyFirstSignalCopy.recordWhatHappensNextCta);
      expect(model.secondaryCta, EarlyFirstSignalCopy.viewEvidenceCta);
      expect(model.showsConfirmedRepeat, isTrue);
      expect(model.returnPrompt, isNotNull);
      expect(model.returnPrompt!.title, EarlyFirstSignalCopy.returnPromptTitle);
      expect(model.returnPrompt!.body, EarlyFirstSignalCopy.returnPromptBody);
      expect(model.returnPrompt!.cta, EarlyFirstSignalCopy.recordTriggerNextTimeCta);
      expect(
        model.returnPrompt!.guidedRecordPrompt,
        EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
      );
    });

    test('three unrelated entries do not show confirmed repeat', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript: 'Weather was nice on my walk through the park today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(EarlyFirstSignalEngine.build(entries: entries), isNull);
      expect(
        '${entries.map((e) => e.transcript).join(' ')}',
        isNot(contains('confirmed repeat')),
      );
    });

    test('one and two entry models omit return prompt', () {
      final one = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );
      expect(one!.returnPrompt, isNull);

      final two = EarlyFirstSignalEngine.build(
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
      expect(two!.returnPrompt, isNull);
    });

    test('two related entries stay first signal not confirmed repeat', () {
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

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryFirstSignal);
      expect(model.showsConfirmedRepeat, isFalse);
      expect(model.title, isNot(EarlyFirstSignalCopy.threeEntryConfirmedTitle));
      expect(model.returnPrompt, isNull);
    });

    test('return prompt record route prefills guided trigger capture', () {
      final route = EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt();
      expect(
        route,
        contains(
          Uri.encodeComponent(EarlyFirstSignalCopy.recordTriggerGuidedPrompt),
        ),
      );
      expect(route, startsWith('/record?prompt='));
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

      expect(
        find.byKey(
          const Key('early_first_signal_card_twoEntryFirstSignal'),
        ),
        findsOneWidget,
      );
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

    testWidgets('renders confirmed repeat with evidence and view CTA', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _entry(
            id: 'e2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _entry(
            id: 'e3',
            transcript:
                'I said yes again even though I had no capacity for one more ask.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: () {},
                onViewEvidence: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const Key('early_first_signal_card_threeEntryConfirmedRepeat'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.threeEntryConfirmedTitle),
        findsOneWidget,
      );
      expect(find.text('Jun 10'), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.viewEvidenceCta), findsOneWidget);
      expect(find.byKey(const Key('confirmed_repeat_return_prompt')), findsNothing);
    });

    testWidgets('renders return prompt for confirmed repeat and fires CTA', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _entry(
            id: 'e2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _entry(
            id: 'e3',
            transcript:
                'I said yes again even though I had no capacity for one more ask.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      var returnPromptTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: () {},
                onViewEvidence: () {},
                onReturnPrompt: () => returnPromptTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('confirmed_repeat_return_prompt')), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.returnPromptTitle), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.returnPromptBody), findsOneWidget);
      expect(
        find.text(EarlyFirstSignalCopy.recordTriggerNextTimeCta),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('confirmed_repeat_return_prompt_cta')),
      );
      await tester.tap(find.byKey(const Key('confirmed_repeat_return_prompt_cta')));
      await tester.pump();

      expect(returnPromptTapped, isTrue);
    });
  });
}
