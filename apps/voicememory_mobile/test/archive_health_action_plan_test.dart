import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_health_action_plan_card.dart';

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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _distinctEntries(int count) => List.generate(
      count,
      (i) => _voiceEntry(
        id: 'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired moment $i.',
        createdAt: DateTime(2026, 6, 9 + i, 12),
      ),
    );

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('ArchiveHealthActionPlanEngine', () {
    test('0 usable entries hides action plan', () {
      final plan = ArchiveHealthActionPlanEngine.build(entries: const []);
      expect(plan.showCard, isFalse);
      expect(plan.actionItems, isEmpty);
    });

    test('1 usable entry action asks for one more moment', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(1),
      );
      expect(plan.showCard, isTrue);
      expect(
        plan.actionItems.first,
        VisibleArchiveProofCopy.archiveHealthActionOneEntry,
      );
    });

    test('2 usable entries action asks for a third moment', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(2),
      );
      expect(
        plan.actionItems.first,
        VisibleArchiveProofCopy.archiveHealthActionTwoEntries,
      );
    });

    test('duplicate-heavy archive asks for different context', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: List.generate(
          4,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: shared,
            createdAt: DateTime(2026, 6, 9 + i, 12),
          ),
        ),
      );
      expect(
        plan.actionItems,
        contains(VisibleArchiveProofCopy.archiveHealthActionDuplicates),
      );
    });

    test('degraded entries ask for adding text to unclear recordings', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: [
          ..._distinctEntries(2),
          _degradedVoiceEntry(id: 'd1'),
        ],
      );
      expect(plan.actionItems.length, lessThanOrEqualTo(3));
      expect(
        plan.actionItems,
        contains(VisibleArchiveProofCopy.archiveHealthActionExcluded),
      );
    });

    test('correction notes ask for a clarifying moment', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefUpdate',
        'This is more about family than work.',
      );
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(3),
      );
      expect(
        plan.actionItems,
        contains(VisibleArchiveProofCopy.archiveHealthActionCorrection),
      );
    });

    test('5+ entries asks for weekly thread moment', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(5),
      );
      expect(
        plan.actionItems.first,
        VisibleArchiveProofCopy.archiveHealthActionFivePlus,
      );
      expect(plan.secondaryCta, isNotNull);
    });

    test('max 3 action items are shown', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefUpdate',
        'Family context matters more here.',
      );
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: [
          _voiceEntry(id: 'e1', transcript: shared),
          _voiceEntry(
            id: 'e2',
            transcript: shared,
            createdAt: DateTime(2026, 6, 11),
          ),
          _degradedVoiceEntry(id: 'd1'),
        ],
      );
      expect(plan.actionItems.length, lessThanOrEqualTo(3));
    });

    test('degraded entries are not counted as evidence in plan', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: [_degradedVoiceEntry()],
      );
      expect(plan.showCard, isFalse);
    });

    test('copy avoids banned language', () {
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(5),
      );
      _expectNoBannedCopy([
        plan.title,
        plan.subtitle,
        plan.primaryCta,
        if (plan.secondaryCta != null) plan.secondaryCta!,
        ...plan.actionItems,
      ]);
    });
  });

  group('ArchiveHealthActionPlanCard', () {
    testWidgets('hidden plan renders nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveHealthActionPlanCard(
            plan: ArchiveHealthActionPlan.hidden(),
            onPrimary: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_health_action_plan_card')), findsNothing);
    });

    testWidgets('visible plan renders action items', (tester) async {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: _distinctEntries(2),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(
            child: ArchiveHealthActionPlanCard(
              plan: plan,
              onPrimary: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_health_action_plan_card')), findsOneWidget);
      expect(find.text('Improve your archive'), findsOneWidget);
      expect(find.byKey(const Key('archive_health_action_plan_item_0')), findsOneWidget);
      _expectNoBannedCopy(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
      );
    });
  });
}
