import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/personal_return_prompt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/personal_return_prompt_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/consumer_record_prompts_section.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 10, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// Four entries with repeated evidence: "deadline" written twice, work x3,
/// evening x2, dominant option `could_not_stop` x3.
List<PressureCheckInRecord> _richRecords() => [
      _record(
        id: 'a',
        daysAgo: 3,
        contextIds: const ['work', 'evening'],
        fear: 'Missing the deadline',
      ),
      _record(
        id: 'b',
        daysAgo: 2,
        contextIds: const ['work'],
        fear: 'The deadline slipping',
      ),
      _record(id: 'c', daysAgo: 1, contextIds: const ['work', 'evening']),
      _record(id: 'd', daysAgo: 0, optionId: 'guilty_resting'),
    ];

const _certaintyPhrases = [
  'i know',
  'you always',
  'always',
  'definitely',
  'certainly',
  'proven',
  'every time',
  'diagnos',
];

void main() {
  const engine = PersonalReturnPromptEngine();

  group('Personal return prompt engine', () {
    test('no evidence returns generic prompts with a fallback line', () {
      final set = engine.build(const []);
      expect(set.personalized, isFalse);
      expect(set.prompts, ConsumerUiCopy.recordStarterPrompts);
      expect(set.sourceTerms, isEmpty);
      expect(set.emptyStateFallback, isNotNull);
    });

    test('1 entry returns gentle continuation prompts', () {
      final set = engine.build([
        _record(id: 'a', contextIds: const ['evening']),
      ]);
      expect(set.personalized, isTrue);
      expect(set.prompts.length, inInclusiveRange(3, 4));
      expect(
        set.prompts,
        contains(
          'Last time, stopping felt difficult. What made it hard today?',
        ),
      );
      expect(
        set.prompts,
        contains(
          'You logged evening pressure before. Did it show up again today?',
        ),
      );
    });

    test('2 entries still use gentle continuation, latest entry wins', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 1, optionId: 'could_not_stop'),
        _record(id: 'b', daysAgo: 0, optionId: 'guilty_resting'),
      ]);
      expect(set.personalized, isTrue);
      expect(
        set.prompts,
        contains(
          'Last time, resting came with guilt. Did it show up again today?',
        ),
      );
      // No evidence-claims with this little data.
      expect(set.prompts.join(' '), isNot(contains('Your archive has seen')));
    });

    test('3+ entries with repeated evidence return personalized prompts', () {
      final set = engine.build(_richRecords());
      expect(set.personalized, isTrue);
      expect(set.prompts.length, inInclusiveRange(3, 4));
      expect(
        set.prompts,
        contains(
          'You mentioned deadline and work before. '
          'Is that still showing up today?',
        ),
      );
      expect(
        set.prompts,
        contains(
          'Your archive has seen deadline repeat. '
          'What happened around that today?',
        ),
      );
      expect(set.sourceTerms, contains('deadline'));
      expect(set.sourceTerms, contains('work'));
    });

    test('previous terms appear in prompt copy', () {
      final set = engine.build(_richRecords());
      final joined = set.prompts.join(' ');
      expect(joined, contains('deadline'));
      expect(joined, contains('work'));
    });

    test('3+ entries without repetition fall back to gentle continuation', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 2, optionId: 'could_not_stop'),
        _record(id: 'b', daysAgo: 1, optionId: 'guilty_resting'),
        _record(id: 'c', daysAgo: 0, optionId: 'had_to_prove_enough'),
      ]);
      expect(set.personalized, isTrue);
      expect(set.prompts.join(' '), isNot(contains('You mentioned')));
      expect(set.prompts.join(' '), isNot(contains('Your archive has seen')));
    });

    test('prompts avoid certainty language in every variant', () {
      final variants = [
        engine.build(const []),
        engine.build([_record(id: 'a', contextIds: const ['work'])]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        final copy = [
          ...set.prompts,
          set.emptyStateFallback ?? '',
          PersonalReturnPromptSet.personalizedLabel,
        ].join(' ').toLowerCase();
        for (final phrase in _certaintyPhrases) {
          expect(copy, isNot(contains(phrase)),
              reason: 'prompt copy must not contain "$phrase"');
        }
      }
    });
  });

  group('Record prompt section', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      PersonalReturnPromptSet? personalPrompts,
      ValueChanged<String>? onSelect,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsumerRecordPromptsSection(
                personalPrompts: personalPrompts,
                onSelectPrompt: onSelect ?? (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows "Based on what you\'ve recorded" when personalized',
        (tester) async {
      final set = engine.build(_richRecords());
      await pumpSection(tester, personalPrompts: set);

      expect(find.text(ConsumerUiCopy.trySayingOneOfThese), findsOneWidget);
      expect(
        find.byKey(const Key('personal_prompts_label')),
        findsOneWidget,
      );
      expect(
        find.text(PersonalReturnPromptSet.personalizedLabel),
        findsOneWidget,
      );
      for (final prompt in set.prompts) {
        expect(find.text(prompt), findsOneWidget);
      }
      // Generic starters are replaced.
      expect(
        find.text(ConsumerUiCopy.recordStarterPrompts.first),
        findsNothing,
      );
    });

    testWidgets('falls back to generic prompts without evidence',
        (tester) async {
      await pumpSection(tester, personalPrompts: engine.build(const []));

      expect(find.byKey(const Key('personal_prompts_label')), findsNothing);
      for (final prompt in ConsumerUiCopy.recordStarterPrompts) {
        expect(find.text(prompt), findsOneWidget);
      }
    });

    testWidgets('falls back to generic prompts when no set is provided',
        (tester) async {
      await pumpSection(tester);
      expect(find.byKey(const Key('personal_prompts_label')), findsNothing);
      for (final prompt in ConsumerUiCopy.recordStarterPrompts) {
        expect(find.text(prompt), findsOneWidget);
      }
    });

    testWidgets('tapping a personalized prompt selects it', (tester) async {
      String? tapped;
      final set = engine.build(_richRecords());
      await pumpSection(
        tester,
        personalPrompts: set,
        onSelect: (p) => tapped = p,
      );

      await tester.tap(find.text(set.prompts.first));
      await tester.pump();
      expect(tapped, set.prompts.first);
    });

    testWidgets('no VoiceMemory consumer copy', (tester) async {
      await pumpSection(tester, personalPrompts: engine.build(_richRecords()));
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_personal_prompts_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('record screen builds cleanly with no evidence and no label',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('personal_prompts_label')), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
