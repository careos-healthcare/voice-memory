import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/daily_return_suggestions_card.dart';

import 'support/memory_pressure_stores.dart';

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

/// Repeated evidence: "deadline" written twice, work x3, evening x2.
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

const _bannedCopy = [
  'need to',
  'must',
  'should',
  'unresolved',
  'problem',
  'failure',
  'lazy',
  'weak',
  'you always',
  'diagnos',
];

/// Sharp titles use curiosity/action frames, not topic labels.
final _edgeTitle = RegExp(
  r'(what you|what .* made you|where .* (felt|made)|afraid'
  r'|talked yourself out|stopped helping|today)',
  caseSensitive: false,
);

String _allCopy(DailyReturnSuggestionSet set) => [
      set.label,
      DailyReturnSuggestionSet.heading,
      DailyReturnSuggestionSet.subLabel,
      for (final s in set.suggestions) ...[s.title, s.prompt, s.reason],
    ].join(' ').toLowerCase();

void main() {
  const engine = DailyReturnSuggestionEngine();

  group('Daily return suggestion engine', () {
    test('no evidence returns a non-personalized empty set', () {
      final set = engine.build(const []);
      expect(set.personalized, isFalse);
      expect(set.suggestions, isEmpty);
      expect(set.hasSuggestions, isFalse);
    });

    test('previous pressure entries generate 2-4 suggestions', () {
      final set = engine.build([
        _record(id: 'a', contextIds: const ['evening']),
      ]);
      expect(set.personalized, isTrue);
      expect(set.hasSuggestions, isTrue);
      expect(set.suggestions.length, inInclusiveRange(2, 4));
      expect(set.label, DailyReturnSuggestionSet.heading);
    });

    test('recent entry option leads the list', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 1, optionId: 'could_not_stop'),
        _record(id: 'b', daysAgo: 0, optionId: 'guilty_resting'),
      ]);
      expect(set.suggestions.first.id, 'recent_option_guilty_resting');
      expect(set.suggestions.first.title, 'The rest you talked yourself out of');
      expect(
        set.suggestions.first.prompt,
        'What rest did you talk yourself out of today?',
      );
      expect(
        set.suggestions.first.reason,
        'This came up in a recent pressure moment.',
      );
    });

    test('repeated terms appear in titles and prompts', () {
      final set = engine.build(_richRecords());
      final titles = set.suggestions.map((s) => s.title).toList();
      expect(titles, contains('What deadline pressure made you do'));
      expect(titles, contains('Where work made you overdo it'));
      expect(
        set.suggestions.map((s) => s.prompt),
        contains('What did deadline pressure make you rush or hide today?'),
      );
      expect(
        set.suggestions.expand((s) => s.sourceTerms),
        contains('deadline'),
      );
      expect(
        set.suggestions.map((s) => s.prompt).join(' '),
        contains('work pressure'),
      );
    });

    test('titles use edge wording, stay short, never "came up again"', () {
      final variants = [
        engine.build([_record(id: 'a', contextIds: const ['evening'])]),
        engine.build([
          _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
          _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
        ]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        for (final suggestion in set.suggestions) {
          expect(suggestion.title, matches(_edgeTitle),
              reason: 'title should pull with a curiosity/action frame: '
                  '"${suggestion.title}"');
          expect(suggestion.title.length, lessThan(60),
              reason: 'title too long: "${suggestion.title}"');
          expect(
            suggestion.title.toLowerCase(),
            isNot(contains('came up again')),
            reason: 'soft topic title where a sharper frame exists: '
                '"${suggestion.title}"',
          );
        }
      }
    });

    test('duplicate ids and prompts are avoided', () {
      // "work" is both an evidence term and the top repeated context — the
      // overlapping overdo prompt must appear only once.
      final set = engine.build(_richRecords());
      final ids = set.suggestions.map((s) => s.id).toList();
      final prompts = set.suggestions.map((s) => s.prompt).toList();
      expect(ids.toSet().length, ids.length);
      expect(prompts.toSet().length, prompts.length);
    });

    test('never more than four suggestions', () {
      final set = engine.build(_richRecords());
      expect(set.suggestions.length, lessThanOrEqualTo(4));
    });

    test('copy avoids homework and overclaiming language', () {
      final variants = [
        engine.build([_record(id: 'a')]),
        engine.build([
          _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
          _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
        ]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        final copy = _allCopy(set);
        for (final banned in _bannedCopy) {
          expect(copy, isNot(contains(banned)),
              reason: 'suggestion copy must not contain "$banned"');
        }
      }
    });
  });

  group('Daily return suggestions card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required DailyReturnSuggestionSet suggestionSet,
      ValueChanged<String>? onSelect,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyReturnSuggestionsCard(
                suggestionSet: suggestionSet,
                onSelectPrompt: onSelect ?? (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders heading, sublabel, and suggestion rows',
        (tester) async {
      final set = engine.build(_richRecords());
      await pumpCard(tester, suggestionSet: set);

      expect(find.text('Worth checking today'), findsOneWidget);
      expect(find.text("Based on what you've recorded"), findsOneWidget);
      for (final suggestion in set.suggestions) {
        expect(find.text(suggestion.title), findsOneWidget);
        expect(find.text(suggestion.prompt), findsOneWidget);
      }
    });

    testWidgets('tapping a suggestion selects its prompt', (tester) async {
      String? selected;
      final set = engine.build(_richRecords());
      await pumpCard(
        tester,
        suggestionSet: set,
        onSelect: (p) => selected = p,
      );

      await tester.tap(find.text(set.suggestions.first.title));
      await tester.pump();
      expect(selected, set.suggestions.first.prompt);
    });

    testWidgets('renders nothing for the empty set', (tester) async {
      await pumpCard(
        tester,
        suggestionSet: DailyReturnSuggestionSet.empty,
      );
      expect(find.text('Worth checking today'), findsNothing);
      expect(
        find.byKey(const Key('daily_return_suggestions_card')),
        findsNothing,
      );
    });

    testWidgets('no VoiceMemory consumer copy', (tester) async {
      await pumpCard(tester, suggestionSet: engine.build(_richRecords()));
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_daily_suggestions_');
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

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      MemoryPressureCheckInStore? store,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(pressureCheckInStore: store),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows suggestions when pressure evidence exists',
        (tester) async {
      await tester.runAsync(() async {
        // A saved reflection puts the screen past first-run so the prompt
        // area (and suggestion card) renders.
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'e1',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      });

      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_richRecords()),
      );

      expect(find.text('Worth checking today'), findsOneWidget);
      expect(find.text("Based on what you've recorded"), findsWidgets);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('shows no suggestion card without pressure evidence',
        (tester) async {
      await pumpRecordScreen(tester);
      expect(find.text('Worth checking today'), findsNothing);
      expect(
        find.byKey(const Key('daily_return_suggestions_card')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
