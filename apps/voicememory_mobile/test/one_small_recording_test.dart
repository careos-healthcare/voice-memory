import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/guided_thread_plan_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/one_small_recording_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/one_small_recording_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/one_small_recording_card.dart';

import 'support/memory_pressure_stores.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

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
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
  );
}

/// Three work-context entries → a guided thread plan exists.
List<PressureCheckInRecord> _workThread3() => [
      _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
      _record(
        id: 'b',
        daysAgo: 3,
        contextIds: const ['work'],
        fear: 'The deadline slipping',
      ),
      _record(
        id: 'c',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: 'I kept checking messages after I wanted to stop.',
      ),
    ];

/// One single entry → daily suggestions exist, but no thread plan.
List<PressureCheckInRecord> _singleRecord() => [
      _record(id: 'solo', daysAgo: 0, fear: 'Falling behind on everything'),
    ];

String _allCopy(OneSmallRecording recording) => [
      recording.title,
      recording.basedOnLine,
      recording.prompt,
      recording.supportingLine,
      ...recording.sourceTerms,
      OneSmallRecording.recordCtaLabel,
    ].join(' ');

void main() {
  const engine = OneSmallRecordingEngine();

  group('One small recording engine', () {
    test('no card without enough evidence', () {
      expect(engine.build(const [], now: _base).hasRecording, isFalse);
      expect(engine.build(const [], now: _base).prompt, isEmpty);
    });

    test('uses the guided thread plan nextPrompt when available', () {
      final plan = const GuidedThreadPlanEngine().build(
        _workThread3(),
        now: _base,
      );
      expect(plan.hasPlan, isTrue);

      final recording = engine.build(_workThread3(), now: _base);
      expect(recording.hasRecording, isTrue);
      expect(recording.prompt, plan.nextPrompt);
      expect(recording.prompt, 'What happened with the work thread today?');
      expect(recording.entryIds, plan.entryIds);
    });

    test('falls back to the daily suggestion primary when no plan exists', () {
      final records = _singleRecord();
      final plan = const GuidedThreadPlanEngine().build(records, now: _base);
      expect(plan.hasPlan, isFalse);

      final suggestions = const DailyReturnSuggestionEngine().build(records);
      expect(suggestions.hasSuggestions, isTrue);

      final recording = engine.build(records, now: _base);
      expect(recording.hasRecording, isTrue);
      expect(recording.prompt, suggestions.recommendedSuggestion!.prompt);
    });

    test('does not fabricate evidence — terms and ids map to real records',
        () {
      final records = _workThread3();
      final recording = engine.build(records, now: _base);
      final realIds = records.map((r) => r.entryId).toSet();
      for (final id in recording.entryIds) {
        expect(realIds, contains(id));
      }
      expect(
        recording.sourceTerms.length,
        lessThanOrEqualTo(OneSmallRecording.maxTerms),
      );
      // The thread term comes from the user's own repeated context.
      expect(recording.sourceTerms, contains('work'));
    });

    test('default copy is the calm product language', () {
      final recording = engine.build(_workThread3(), now: _base);
      expect(recording.title, 'Today\u2019s one small recording');
      expect(recording.basedOnLine, 'Based on your thread plan');
      expect(
        recording.supportingLine,
        'You do not need to solve everything today.',
      );
    });

    test('no banned wording in any variant', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build(_singleRecord(), now: _base),
      ];
      for (final recording in scenarios) {
        final copy = _allCopy(recording).toLowerCase();
        for (final banned in const [
          'task',
          'homework',
          'must',
          'should',
          'unresolved problem',
          'failure',
          'lazy',
          'weak',
          'diagnos',
          'definitely',
          'fix yourself',
        ]) {
          expect(copy, isNot(contains(banned)),
              reason: 'copy must not contain "$banned"');
        }
      }
    });

    test('no VoiceMemory in consumer copy', () {
      for (final records in [_workThread3(), _singleRecord()]) {
        expect(
          _allCopy(engine.build(records, now: _base)),
          isNot(contains('VoiceMemory')),
        );
      }
    });
  });

  group('One small recording card', () {
    testWidgets('renders title, based-on line, prompt, and supporting line',
        (tester) async {
      final recording = engine.build(_workThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OneSmallRecordingCard(
                recording: recording,
                onRecordThis: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Today\u2019s one small recording'), findsOneWidget);
      expect(find.text('Based on your thread plan'), findsOneWidget);
      expect(find.text(recording.prompt), findsOneWidget);
      expect(
        find.text('You do not need to solve everything today.'),
        findsOneWidget,
      );
      expect(find.text('Record this'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('tapping Record this hands off the prompt', (tester) async {
      final recording = engine.build(_workThread3(), now: _base);
      String? handedOff;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OneSmallRecordingCard(
                recording: recording,
                onRecordThis: (p) => handedOff = p,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('one_small_recording_record_cta')),
      );
      await tester.pump();
      expect(handedOff, 'What happened with the work thread today?');
    });

    testWidgets('renders nothing without a recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OneSmallRecordingCard(
              recording: OneSmallRecording.none(),
              onRecordThis: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_one_small_recording_');
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
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: store,
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> seedReflection(WidgetTester tester) async {
      await tester.runAsync(() async {
        // A saved reflection puts the screen past first-run so the prompt
        // area (and the one-small-recording card) renders.
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
    }

    testWidgets('shows the card above daily suggestions and prompt chips',
        (tester) async {
      await seedReflection(tester);
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      final cardFinder = find.byKey(const Key('one_small_recording_card'));
      expect(cardFinder, findsOneWidget);
      expect(find.text('Today\u2019s one small recording'), findsOneWidget);

      // Daily suggestions stay present, below the one-small-recording card.
      final suggestionsHeading = find.text('Worth checking today');
      expect(suggestionsHeading, findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder).dy,
        lessThan(tester.getTopLeft(suggestionsHeading).dy),
      );
    });

    testWidgets('tapping Record this selects the prompt on the screen',
        (tester) async {
      await seedReflection(tester);
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      // The screen builds with the real clock, so derive the expected prompt
      // the same way instead of assuming a thread status.
      final prompt = engine.build(_workThread3()).prompt;
      expect(prompt, isNotEmpty);
      // Before the tap the prompt only exists inside the card.
      expect(find.text(prompt), findsOneWidget);

      final cta = find.byKey(const Key('one_small_recording_record_cta'));
      await tester.ensureVisible(cta);
      await tester.pump();
      await tester.tap(cta);
      await tester.pump();

      // Selected prompt now also renders in the "Try saying" area.
      expect(find.text(prompt), findsNWidgets(2));
    });

    testWidgets('no card without plan or suggestion evidence',
        (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
