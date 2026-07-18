import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/activation/day_two_return_loop_payoff.dart';
import 'package:voicememory_mobile/features/first_session/day_two_reminder.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/day_two_return_loop_card.dart';

JournalEntry _voiceEntry({
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

const _bannedOneEntryWords = [
  'loop',
  'repeat',
  'repeating',
  'pattern found',
  'pressure loop',
];

const _bannedPressureWords = [
  'streak',
  'guilt',
  'you must',
  'must come back',
  'daily habit',
  'diagnosis',
  'therapy',
  'we found your pattern',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedCopy(Iterable<String> visible, List<String> banned) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in banned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('DayTwoReturnLoopPayoffEngine', () {
    test('one entry uses calm return copy and optional reminder', () {
      final payoff = DayTwoReturnLoopPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
        reminderAvailable: true,
      );

      expect(payoff, isNotNull);
      expect(payoff!.body, DayTwoReturnLoopPayoffCopy.oneEntryBody);
      expect(payoff.primaryCta, 'Record if it happens again');
      expect(payoff.offerReminder, isTrue);
      _expectNoBannedCopy([payoff.body], _bannedOneEntryWords);
    });

    test('two entries uses thread clearer copy and view archive', () {
      final payoff = DayTwoReturnLoopPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'A quiet moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Another unrelated note about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(payoff, isNotNull);
      expect(
        payoff!.body,
        'ArchiveMe needs one more moment before it can compare clearly.',
      );
      expect(payoff.secondaryCta, 'View archive');
    });

    test('three entries defer to belief payoff card', () {
      expect(
        DayTwoReturnLoopPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I felt pressure before saying yes again even when I was tired.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Work kept pulling me back after I wanted to stop for the day.',
            ),
            _voiceEntry(
              id: 'e3',
              transcript:
                  'I noticed the same hurry showing up before I answered anyone.',
            ),
          ],
        ),
        isNull,
      );
    });
  });

  group('DayTwoReturnLoopCard', () {
    testWidgets('shows calm reminder offer when enabled', (tester) async {
      const payoff = DayTwoReturnLoopPayoff(
        body: DayTwoReturnLoopPayoffCopy.oneEntryBody,
        primaryCta: DayTwoReturnLoopPayoffCopy.primaryCta,
        eligibleEntryCount: 1,
        offerReminder: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DayTwoReturnLoopCard(
              payoff: payoff,
              onAddAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('day_two_return_loop_card')), findsOneWidget);
      expect(find.text('Record if it happens again'), findsOneWidget);
      expect(find.text(DayTwoReminder.acceptLabel), findsOneWidget);
      expect(find.text(DayTwoReminder.declineLabel), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester), _bannedPressureWords);
    });
  });

  group('RecordScreen return loop', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_return_loop_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpDoneState(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool offerReminder = false,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          lastCaptureAnalysisSucceeded: true,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
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
      }
    }

    testWidgets('first save shows return loop without competing preview card', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(find.byKey(const Key('day_two_return_loop_card')), findsOneWidget);
      expect(find.textContaining('Come back when this shows up again'), findsOneWidget);
      expect(find.text('Record if it happens again'), findsWidgets);
      expect(find.byKey(const Key('day_two_return_preview_card')), findsNothing);
      expect(find.byKey(const Key('day_two_reminder_card')), findsNothing);
      _expectNoBannedCopy(_visibleText(tester), _bannedOneEntryWords);
      _expectNoBannedCopy(_visibleText(tester), _bannedPressureWords);
    });

    testWidgets('second save shows thread clearer return loop', (tester) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'A quiet moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Another unrelated note about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(find.byKey(const Key('day_two_return_loop_card')), findsOneWidget);
      expect(
        find.textContaining(
          'ArchiveMe needs one more moment before it can compare clearly',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('day_two_return_preview_card')), findsNothing);
    });

    testWidgets('third save uses belief payoff without duplicate return loop', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure before saying yes again even when I was tired.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'I noticed the same hurry showing up before I answered anyone.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(find.byKey(const Key('post_save_archive_home_nudge_card')), findsNothing);
      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsNothing);
      expect(find.byKey(const Key('post_save_focused_actions_bar')), findsOneWidget);
      expect(find.byKey(const Key('day_two_return_loop_card')), findsNothing);
      expect(find.text('Record if it happens again'), findsOneWidget);
      expect(find.text(PostSaveFocusedActionsCopy.viewPatterns), findsOneWidget);
    });
  });
}
