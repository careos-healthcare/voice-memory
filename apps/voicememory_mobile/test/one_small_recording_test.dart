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
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/consumer_record_prompts_section.dart';
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
  OneSmallRecording.restCanWaitLine,
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
        entryCount: 3,
      );
      expect(plan.hasPlan, isTrue);

      final recording = engine.build(
        _workThread3(),
        now: _base,
        entryCount: 3,
      );
      expect(recording.hasRecording, isTrue);
      expect(recording.prompt, plan.nextPrompt);
      expect(recording.prompt, 'What happened with the work thread today?');
      expect(recording.entryIds, plan.entryIds);
    });

    test('falls back to the daily suggestion primary when no plan exists', () {
      final records = _singleRecord();
      final plan = const GuidedThreadPlanEngine().build(
        records,
        now: _base,
        entryCount: 1,
      );
      expect(plan.hasPlan, isFalse);

      final suggestions = const DailyReturnSuggestionEngine().build(records);
      expect(suggestions.hasSuggestions, isTrue);

      final recording = engine.build(
        records,
        now: _base,
        entryCount: 1,
      );
      expect(recording.hasRecording, isTrue);
      expect(recording.prompt, suggestions.recommendedSuggestion!.prompt);
    });

    test('does not fabricate evidence — terms and ids map to real records', () {
      final records = _workThread3();
      final recording = engine.build(records, now: _base, entryCount: 3);
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
      final recording = engine.build(_workThread3(), now: _base, entryCount: 3);
      expect(recording.title, 'One small recording');
      expect(recording.basedOnLine, 'Based on your thread plan');
      expect(
        recording.supportingLine,
        'Just capture what happened. You do not need to solve it.',
      );
    });

    test('no banned wording in any variant', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base, entryCount: 3),
        engine.build(_singleRecord(), now: _base, entryCount: 1),
      ];
      for (final recording in scenarios) {
        final copy = _allCopy(recording).toLowerCase();
        for (final banned in const [
          'task',
          'homework',
          'must',
          'should',
          'streak',
          'unfinished',
          'unresolved',
          'fix',
          'problem',
          'failure',
          'lazy',
          'weak',
          'diagnos',
          'definitely',
          'healed',
          'processed',
          'regulated',
          'anxious',
          'trauma',
          'cure',
          'resolved',
        ]) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in consumer copy', () {
      for (final records in [_workThread3(), _singleRecord()]) {
        final count = records.length >= 3 ? 3 : 1;
        expect(
          _allCopy(engine.build(records, now: _base, entryCount: count)),
          isNot(contains('VoiceMemory')),
        );
      }
    });
  });

  group('One small recording card', () {
    testWidgets('renders title, based-on line, prompt, and supporting line', (
      tester,
    ) async {
      final recording = engine.build(_workThread3(), now: _base, entryCount: 3);
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

      expect(find.text('One small recording'), findsOneWidget);
      expect(find.text('Based on your thread plan'), findsOneWidget);
      expect(find.text(recording.prompt), findsOneWidget);
      expect(
        find.text('Just capture what happened. You do not need to solve it.'),
        findsOneWidget,
      );
      expect(find.text('Record this'), findsOneWidget);
      // The primary-action line lives inside the card — one clear start.
      expect(find.text('Start here. The rest can wait.'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('tapping Record this hands off the prompt', (tester) async {
      final recording = engine.build(_workThread3(), now: _base, entryCount: 3);
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

      await tester.tap(find.byKey(const Key('one_small_recording_record_cta')));
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

    Future<void> seedArchiveEntries(
      WidgetTester tester, {
      int count = 3,
    }) async {
      await tester.runAsync(() async {
        for (var i = 0; i < count; i++) {
          await AppServices.instance.journalStore.save(
            JournalEntry(
              id: 'e$i',
              createdAt: DateTime(2026, 6, 1 + i, 12),
              transcript:
                  'Saved moment $i with enough words to count as evidence '
                  'for archive context on the record screen.',
              durationSeconds: 30,
              reflection: Reflection(
                mood: 'neutral',
                emotionalIntensity: 2,
                recurringThemes: const ['work'],
                exactLanguagePattern: '',
                concreteObservation: 'You mentioned pressure in this moment.',
                repeatedSignal: '',
              ),
            ),
          );
        }
      });
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      MemoryPressureCheckInStore? store,
      bool waitForOneSmallRecordingCard = false,
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
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (waitForOneSmallRecordingCard &&
            find
                .byKey(const Key('one_small_recording_card'))
                .evaluate()
                .isNotEmpty) {
          return;
        }
      }
    }

    testWidgets('capture-first record suppresses one small recording card', (
      tester,
    ) async {
      await seedArchiveEntries(tester);
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(find.text('Worth checking today'), findsNothing);
      expect(find.byType(ConsumerRecordPromptsSection), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('capture-first record keeps single record CTA without duplicate card CTA', (
      tester,
    ) async {
      await seedArchiveEntries(tester);
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(find.byKey(const Key('one_small_recording_record_cta')), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('no card without plan or suggestion evidence', (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(find.byType(ConsumerRecordPromptsSection), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
