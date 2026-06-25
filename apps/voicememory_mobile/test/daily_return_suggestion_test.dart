import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/suggestion_attribution_event.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/daily_return_suggestions_card.dart';

import 'support/memory_pressure_stores.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String? stopCostNote,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 10, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
  );
}

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

JournalEntry _journalEntry(String id) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 1, 12).add(Duration(days: id.hashCode % 3)),
      transcript:
          'A long enough transcript to count as a saved reflection for $id.',
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: 'pattern',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: 'signal',
      ),
    );

Future<void> _seedJournalForSuggestions(int count) async {
  for (var i = 0; i < count; i++) {
    await AppServices.instance.journalStore.save(_journalEntry('e$i'));
  }
}

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
  set.recommendationReason,
  DailyReturnSuggestionSet.heading,
  DailyReturnSuggestionSet.subLabel,
  DailyReturnSuggestionSet.evidenceLabel,
  DailyReturnSuggestionSet.primaryHeading,
  DailyReturnSuggestionSet.whyLabel,
  DailyReturnSuggestionSet.othersHeading,
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
      expect(
        set.suggestions.first.title,
        'The rest you talked yourself out of',
      );
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
        engine.build([
          _record(id: 'a', contextIds: const ['evening']),
        ]),
        engine.build([
          _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
          _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
        ]),
        engine.build(_richRecords()),
      ];
      for (final set in variants) {
        for (final suggestion in set.suggestions) {
          expect(
            suggestion.title,
            matches(_edgeTitle),
            reason:
                'title should pull with a curiosity/action frame: '
                '"${suggestion.title}"',
          );
          expect(
            suggestion.title.length,
            lessThan(60),
            reason: 'title too long: "${suggestion.title}"',
          );
          expect(
            suggestion.title.toLowerCase(),
            isNot(contains('came up again')),
            reason:
                'soft topic title where a sharper frame exists: '
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

    test('recommendation picks the latest option suggestion first', () {
      final set = engine.build(_richRecords());
      expect(set.recommendedSuggestion!.id, 'recent_option_guilty_resting');
      expect(set.recommendationReason, 'This showed up most recently.');
      expect(set.otherSuggestions.length, set.suggestions.length - 1);
      expect(
        set.otherSuggestions.map((s) => s.id),
        isNot(contains('recent_option_guilty_resting')),
      );
    });

    test('snippet-backed suggestion wins when no latest option exists', () {
      // Unknown option ids mean no recent-option candidate exists.
      final set = engine.build([
        _record(
          id: 'a',
          daysAgo: 2,
          optionId: 'mystery',
          contextIds: const ['work'],
          fear: 'Missing the deadline',
        ),
        _record(
          id: 'b',
          daysAgo: 1,
          optionId: 'mystery',
          contextIds: const ['work'],
          fear: 'The deadline slipping',
        ),
        _record(
          id: 'c',
          daysAgo: 0,
          optionId: 'mystery',
          contextIds: const ['work'],
        ),
      ]);
      final recommended = set.recommendedSuggestion!;
      expect(recommended.evidenceSnippet, isNotNull);
      expect(
        set.recommendationReason,
        'This uses your own words from a recent entry.',
      );
    });

    test('repeated context wins when no option or snippet exists', () {
      final set = engine.build([
        _record(
          id: 'a',
          daysAgo: 1,
          optionId: 'mystery',
          contextIds: const ['work'],
        ),
        _record(
          id: 'b',
          daysAgo: 0,
          optionId: 'mystery',
          contextIds: const ['work'],
        ),
      ]);
      expect(set.recommendedSuggestion!.id, 'context_work');
      expect(
        set.recommendationReason,
        'This has repeated across recent entries.',
      );
    });

    test('filler is never recommended over real evidence', () {
      final sparse = engine.build([_record(id: 'a')]);
      expect(sparse.recommendedSuggestion!.id, isNot('todays_pressure'));

      // Filler leads only when it is genuinely all there is.
      final fillerOnly = engine.build([_record(id: 'a', optionId: 'mystery')]);
      expect(fillerOnly.suggestions.map((s) => s.id).toList(), [
        'todays_pressure',
      ]);
      expect(fillerOnly.recommendedSuggestion!.id, 'todays_pressure');
      expect(fillerOnly.recommendationReason, 'One honest sentence is enough.');
      expect(fillerOnly.otherSuggestions, isEmpty);
    });

    test('suggestions carry the user\'s own words as evidence snippets', () {
      final set = engine.build(_richRecords());
      final deadlineRow = set.suggestions.firstWhere(
        (s) => s.id == 'term_deadline',
      );
      // The newest note that actually mentions the term.
      expect(deadlineRow.evidenceSnippet, 'The deadline slipping');
      // The latest entry has no written note — no snippet, never fabricated.
      final recentRow = set.suggestions.firstWhere(
        (s) => s.id == 'recent_option_guilty_resting',
      );
      expect(recentRow.evidenceSnippet, isNull);
    });

    test('snippets are capped at 80 characters and trimmed', () {
      final longNote =
          '  I kept checking messages and rereading every '
          'reply long after I told myself I would stop for the evening.  ';
      final set = engine.build([_record(id: 'a', fear: longNote)]);
      final snippet = set.suggestions.first.evidenceSnippet;
      expect(snippet, isNotNull);
      expect(snippet!.length, lessThanOrEqualTo(80));
      expect(snippet, endsWith('\u2026'));
      expect(snippet, startsWith('I kept checking messages'));
    });

    test('no snippet appears when no safe text exists', () {
      final set = engine.build([
        _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
        _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
      ]);
      for (final suggestion in set.suggestions) {
        expect(
          suggestion.evidenceSnippet,
          isNull,
          reason:
              'no user-written note exists, so "$suggestion.id" '
              'must not carry a snippet',
        );
      }
    });

    test('snippets are never fabricated and never repeated', () {
      final records = _richRecords();
      final set = engine.build(records);
      final notes = [
        for (final r in records) ...[r.fear, r.stopCostNote],
      ].whereType<String>().toList();
      final seen = <String>{};
      for (final suggestion in set.suggestions) {
        final snippet = suggestion.evidenceSnippet;
        if (snippet == null) continue;
        final raw = snippet.endsWith('\u2026')
            ? snippet.substring(0, snippet.length - 1)
            : snippet;
        expect(
          notes.any((note) => note.contains(raw)),
          isTrue,
          reason: 'snippet must come from the user\'s own notes: "$snippet"',
        );
        expect(
          seen.add(snippet),
          isTrue,
          reason: 'each note shows at most once across the card',
        );
      }
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
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'suggestion copy must not contain "$banned"',
          );
        }
      }
    });
  });

  group('Daily return suggestions card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required DailyReturnSuggestionSet suggestionSet,
      ValueChanged<String>? onSelect,
      void Function(DailyReturnSuggestion, bool)? onSuggestionTap,
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
                onSuggestionTap: onSuggestionTap,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders heading, sublabel, and suggestion rows', (
      tester,
    ) async {
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
      await pumpCard(tester, suggestionSet: set, onSelect: (p) => selected = p);

      await tester.tap(find.text(set.suggestions.first.title));
      await tester.pump();
      expect(selected, set.suggestions.first.prompt);
    });

    testWidgets('renders primary recommendation and other suggestions', (
      tester,
    ) async {
      final set = engine.build(_richRecords());
      await pumpCard(tester, suggestionSet: set);

      expect(find.text('Start here today'), findsOneWidget);
      expect(find.textContaining('Why this one:'), findsOneWidget);
      expect(find.text('Other things worth checking'), findsOneWidget);
      expect(
        find.byKey(const Key('daily_return_primary_recommendation')),
        findsOneWidget,
      );
    });

    testWidgets('single suggestion shows only the primary block', (
      tester,
    ) async {
      final fillerOnly = engine.build([_record(id: 'a', optionId: 'mystery')]);
      await pumpCard(tester, suggestionSet: fillerOnly);

      expect(find.text('Start here today'), findsOneWidget);
      expect(find.text('Other things worth checking'), findsNothing);
    });

    testWidgets('tapping the primary recommendation selects its prompt', (
      tester,
    ) async {
      String? selected;
      final set = engine.build(_richRecords());
      await pumpCard(tester, suggestionSet: set, onSelect: (p) => selected = p);

      await tester.tap(
        find.byKey(const Key('daily_return_primary_recommendation')),
      );
      await tester.pump();
      expect(selected, set.recommendedSuggestion!.prompt);
    });

    testWidgets('tapping a secondary suggestion selects its prompt', (
      tester,
    ) async {
      String? selected;
      final set = engine.build(_richRecords());
      await pumpCard(tester, suggestionSet: set, onSelect: (p) => selected = p);

      final secondary = set.otherSuggestions.first;
      await tester.tap(find.text(secondary.title));
      await tester.pump();
      expect(selected, secondary.prompt);
    });

    testWidgets('primary tap reports the suggestion as Start here today', (
      tester,
    ) async {
      DailyReturnSuggestion? tapped;
      bool? primary;
      final set = engine.build(_richRecords());
      await pumpCard(
        tester,
        suggestionSet: set,
        onSuggestionTap: (s, isPrimary) {
          tapped = s;
          primary = isPrimary;
        },
      );

      await tester.tap(
        find.byKey(const Key('daily_return_primary_recommendation')),
      );
      await tester.pump();
      expect(tapped!.id, set.recommendedSuggestion!.id);
      expect(primary, isTrue);
    });

    testWidgets('secondary tap reports the suggestion as not primary', (
      tester,
    ) async {
      DailyReturnSuggestion? tapped;
      bool? primary;
      final set = engine.build(_richRecords());
      await pumpCard(
        tester,
        suggestionSet: set,
        onSuggestionTap: (s, isPrimary) {
          tapped = s;
          primary = isPrimary;
        },
      );

      final secondary = set.otherSuggestions.first;
      await tester.tap(find.text(secondary.title));
      await tester.pump();
      expect(tapped!.id, secondary.id);
      expect(primary, isFalse);
    });

    testWidgets('renders "From your archive:" when a snippet exists', (
      tester,
    ) async {
      await pumpCard(tester, suggestionSet: engine.build(_richRecords()));
      expect(find.textContaining('From your archive:'), findsWidgets);
      expect(find.textContaining('The deadline slipping'), findsOneWidget);
    });

    testWidgets('renders no evidence line without snippets', (tester) async {
      final set = engine.build([
        _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
        _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
      ]);
      await pumpCard(tester, suggestionSet: set);
      expect(find.textContaining('From your archive:'), findsNothing);
    });

    testWidgets('renders nothing for the empty set', (tester) async {
      await pumpCard(tester, suggestionSet: DailyReturnSuggestionSet.empty);
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
      final journalPath = '${tempDir.path}/journal.json';
      for (final path in [
        journalPath,
        JournalStore.encryptedPathFor(journalPath),
      ]) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
      await AppServices.resetForTest(
        journalPath: journalPath,
        prefsPath: '${tempDir.path}/prefs.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
      AhaMomentStore.resetForTest();
    });

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      MemoryPressureCheckInStore? store,
      MemorySuggestionAttributionStore? suggestionStore,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: RecordScreen(
                pressureCheckInStore: store,
                suggestionAttributionStore:
                    suggestionStore ?? MemorySuggestionAttributionStore(),
                entitlementReader: FakeArchiveEntitlementReader(pro: false),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('shows suggestions when pressure evidence exists', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Suggestions load only after three saved reflections.
        await _seedJournalForSuggestions(3);
      });

      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_richRecords()),
      );

      expect(find.text('Worth checking today'), findsOneWidget);
      expect(find.text("Based on what you've recorded"), findsWidgets);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('shows no suggestion card without pressure evidence', (
      tester,
    ) async {
      await pumpRecordScreen(tester);
      expect(find.text('Worth checking today'), findsNothing);
      expect(
        find.byKey(const Key('daily_return_suggestions_card')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('records seen and tap attribution events', (tester) async {
      await tester.runAsync(() async {
        await _seedJournalForSuggestions(3);
      });

      final suggestionStore = MemorySuggestionAttributionStore();
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_richRecords()),
        suggestionStore: suggestionStore,
      );

      expect(find.text('Worth checking today'), findsOneWidget);

      expect(
        suggestionStore.recorded.map((e) => e.type),
        contains(SuggestionAttributionEventType.dailySuggestionsSeen),
      );

      // Tap the primary "Start here today" recommendation.
      final primary = find.byKey(
        const Key('daily_return_primary_recommendation'),
      );
      await tester.ensureVisible(primary);
      await tester.tap(primary);
      await tester.pump();

      final tapped = suggestionStore.recorded
          .where(
            (e) => e.type == SuggestionAttributionEventType.startHereTapped,
          )
          .toList();
      expect(tapped, hasLength(1));
      expect(tapped.single.suggestionId, isNotNull);

      // Tap a secondary suggestion as well.
      final card = tester.widget<DailyReturnSuggestionsCard>(
        find.byType(DailyReturnSuggestionsCard),
      );
      final secondary = card.suggestionSet.otherSuggestions.first;
      final secondaryRow = find.text(secondary.title);
      await tester.ensureVisible(secondaryRow);
      await tester.tap(secondaryRow);
      await tester.pump();

      expect(
        suggestionStore.recorded.map((e) => e.type),
        contains(SuggestionAttributionEventType.dailySuggestionTapped),
      );
    });
  });
}
