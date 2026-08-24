import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/pressure_retention/personal_return_prompt_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/personal_return_prompt_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/consumer_record_prompts_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/test_storage_sandbox.dart';

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
  _record(id: 'd', optionId: 'guilty_resting'),
];

const _certaintyPhrases = [
  'i know',
  'you always',
  'always',
  'definitely',
  'certainly',
  'proven',
  'every time',
  'you are',
  'you must',
];

const _diagnosticWords = [
  'diagnos',
  'anxiety',
  'disorder',
  'symptom',
  'depress',
  'burnout',
  'condition',
];

const _shameWords = [
  'lazy',
  'weak',
  'pathetic',
  'failure',
  'ashamed',
  'no excuse',
  'fault',
];

/// Edge prompts ask about proving, feeling behind, unsafe stopping,
/// continuing past usefulness, avoidance, honesty, or what pressure forced.
final _edgeQuestion = RegExp(
  '(prove|behind|unsafe|stopped helping|avoid admitting'
  '|archive to notice|overdo|rush|talk yourself out|make you)',
  caseSensitive: false,
);

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
      expect(set.prompts, contains('Where did stopping feel unsafe today?'));
      expect(
        set.prompts,
        contains('What did evening pressure make you overdo today?'),
      );
    });

    test('2 entries still use gentle continuation, latest entry wins', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 1),
        _record(id: 'b', optionId: 'guilty_resting'),
      ]);
      expect(set.personalized, isTrue);
      expect(
        set.prompts,
        contains('What rest did you talk yourself out of today?'),
      );
      // The honest-archive closer is reserved for repeated evidence.
      expect(set.prompts.join(' '), isNot(contains('archive to notice')));
    });

    test('3+ entries with repeated evidence return personalized prompts', () {
      final set = engine.build(_richRecords());
      expect(set.personalized, isTrue);
      expect(set.prompts.length, inInclusiveRange(3, 4));
      expect(
        set.prompts,
        contains('What did deadline pressure make you rush or hide today?'),
      );
      expect(
        set.prompts,
        contains('What did work pressure make you overdo today?'),
      );
      expect(
        set.prompts,
        contains('What would you not want your archive to notice about today?'),
      );
      expect(set.sourceTerms, contains('deadline'));
      expect(set.sourceTerms, contains('work'));
    });

    test('every prompt uses an edge frame, never "still showing up"', () {
      final variants = [
        engine.build([
          _record(id: 'a', contextIds: const ['evening']),
        ]),
        engine.build([
          _record(id: 'a', daysAgo: 1),
          _record(id: 'b', optionId: 'guilty_resting'),
        ]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        for (final prompt in set.prompts) {
          expect(
            prompt,
            matches(_edgeQuestion),
            reason:
                'prompt should use a self-recognition edge frame: '
                '"$prompt"',
          );
          expect(
            prompt.toLowerCase(),
            isNot(contains('still showing up')),
            reason: 'no soft "is it still showing up" wording: "$prompt"',
          );
        }
      }
    });

    test('prompts stay under 115 characters', () {
      final variants = [
        engine.build([
          _record(id: 'a', contextIds: const ['evening']),
        ]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        for (final prompt in set.prompts) {
          expect(
            prompt.length,
            lessThan(115),
            reason: 'prompt too long: "$prompt"',
          );
        }
      }
    });

    test('previous terms appear in prompt copy', () {
      final set = engine.build(_richRecords());
      final joined = set.prompts.join(' ');
      expect(joined, contains('deadline'));
      expect(joined, contains('work'));
    });

    test('3+ entries without repetition fall back to gentle continuation', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 2),
        _record(id: 'b', daysAgo: 1, optionId: 'guilty_resting'),
        _record(id: 'c', optionId: 'had_to_prove_enough'),
      ]);
      expect(set.personalized, isTrue);
      // Evidence-only frames stay out of the gentle path.
      expect(set.prompts.join(' '), isNot(contains('rush or hide')));
      expect(set.prompts.join(' '), isNot(contains('archive to notice')));
    });

    test('prompts avoid certainty, diagnostic, and shame language '
        'in every variant', () {
      final variants = [
        engine.build(const []),
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ]),
        engine.build([
          _record(id: 'a', daysAgo: 1),
          _record(id: 'b', optionId: 'guilty_resting'),
        ]),
        engine.build(_richRecords()),
        engine.build([
          ..._richRecords(),
          _record(id: 'e', daysAgo: 4, optionId: 'had_to_prove_enough'),
        ]),
      ];
      for (final set in variants) {
        final copy = [
          ...set.prompts,
          set.emptyStateFallback ?? '',
          PersonalReturnPromptSet.personalizedLabel,
        ].join(' ').toLowerCase();
        for (final phrase in [
          ..._certaintyPhrases,
          ..._diagnosticWords,
          ..._shameWords,
        ]) {
          expect(
            copy,
            isNot(contains(phrase)),
            reason: 'prompt copy must not contain "$phrase"',
          );
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
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsumerRecordPromptsSection(
                personalPrompts: personalPrompts,
                onSelectPrompt: onSelect ?? (_) {},
              ),
            ),
          ),
        )));
      await tester.pump();
    }

    testWidgets('shows "Based on what you\'ve recorded" when personalized', (
      tester,
    ) async {
      final set = engine.build(_richRecords());
      await pumpSection(tester, personalPrompts: set);

      expect(find.text(ConsumerUiCopy.trySayingOneOfThese), findsOneWidget);
      expect(find.byKey(const Key('personal_prompts_label')), findsOneWidget);
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

    testWidgets('falls back to generic prompts without evidence', (
      tester,
    ) async {
      await pumpSection(tester, personalPrompts: engine.build(const []));

      expect(find.byKey(const Key('personal_prompts_label')), findsNothing);
      for (final prompt in ConsumerUiCopy.recordStarterPrompts) {
        expect(find.text(prompt), findsOneWidget);
      }
    });

    testWidgets('falls back to generic prompts when no set is provided', (
      tester,
    ) async {
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
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() => sandbox.dispose());

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('record screen builds cleanly with no evidence and no label', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordScreen()),
        )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('personal_prompts_label')), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}