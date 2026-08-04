import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_packs/entry_pack_scope.dart';
import 'package:voicememory_mobile/features/memory/clean_slate_prompt_store.dart';
import 'package:voicememory_mobile/features/memory/entry_memory_mode.dart';
import 'package:voicememory_mobile/features/memory/entry_thread_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_decision.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/topic_shift_decision.dart';
import 'package:voicememory_mobile/features/memory/topic_shift_guard.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/clean_slate_prompt_card.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  String? archiveThreadId,
  String? archivePackId,
  bool treatAsNew = false,
  bool keepSeparate = false,
  bool connectionApproved = false,
  String optionId = 'could_not_stop',
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  archiveThreadId: archiveThreadId,
  archivePackId: archivePackId,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  connectionApproved: connectionApproved,
);

List<PressureCheckInRecord> _crossThreadEvidence() => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    fear: 'I keep circling the same work decision',
    archiveThreadId: 'thread_work',
    contexts: ['work'],
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'The same work decision came back today',
    archiveThreadId: 'thread_home',
    contexts: ['work', 'home'],
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling the same work decision tonight',
    archiveThreadId: 'thread_work',
    contexts: ['work'],
  ),
];

List<PressureCheckInRecord> _lowRelevanceRecords() => [
  _rec(id: 'old1', daysAgo: 90, contexts: ['travel']),
  _rec(id: 'old2', daysAgo: 80, contexts: ['music']),
];

void _seedPastFirstMinute() {
  CleanSlatePromptStore.seedSessionStartForTest(
    DateTime.now().subtract(const Duration(seconds: 61)),
  );
}

void _reset() {
  MemoryScopePolicy.resetForTest();
  TopicShiftGuard.resetForTest();
  MemoryGovernancePolicy.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('TopicShiftGuard prompt rules', () {
    test('no prompt when memory off', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.decisionId, TopicShiftDecisionId.memoryOff);
    });

    test('no prompt on first save', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 1,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
    });

    test('no prompt when entry count is zero', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 0,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
    });

    test('no prompt when Treat as new selected', () {
      _seedPastFirstMinute();
      EntryMemoryModeSession.select(EntryMemoryMode.treatAsNew);
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.reasonId, TopicShiftReasonId.freshMode);
    });

    test('no prompt when Keep separate selected', () {
      _seedPastFirstMinute();
      EntryMemoryModeSession.select(EntryMemoryMode.keepSeparate);
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.reasonId, TopicShiftReasonId.keepSeparate);
    });

    test('no prompt after explicit thread choice when aligned', () {
      _seedPastFirstMinute();
      EntryThreadScopeSession.selectExistingThread(
        'thread_work',
        entryCount: 3,
      );
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.reasonId, TopicShiftReasonId.explicitUserChoice);
    });

    test('no prompt after explicit pack choice when aligned', () {
      _seedPastFirstMinute();
      final records = [
        _rec(id: 'e1', daysAgo: 2, archivePackId: 'pack_a', contexts: ['work']),
        _rec(id: 'e2', daysAgo: 1, archivePackId: 'pack_a', contexts: ['work']),
      ];
      EntryPackScopeSession.selectExistingPack('pack_a');
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: records,
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.reasonId, TopicShiftReasonId.explicitUserChoice);
    });

    test('different explicit thread triggers prompt', () {
      _seedPastFirstMinute();
      EntryThreadScopeSession.selectExistingThread(
        'thread_other',
        entryCount: 3,
      );
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isTrue);
      expect(decision.decisionId, TopicShiftDecisionId.differentThread);
    });

    test('different explicit pack triggers prompt', () {
      _seedPastFirstMinute();
      final records = [
        _rec(id: 'e1', daysAgo: 2, archivePackId: 'pack_a', contexts: ['work']),
        _rec(id: 'e2', daysAgo: 1, archivePackId: 'pack_a', contexts: ['work']),
        _rec(id: 'e3', daysAgo: 0, archivePackId: 'pack_a', contexts: ['work']),
      ];
      EntryPackScopeSession.selectExistingPack('pack_b');
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: records,
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isTrue);
      expect(decision.decisionId, TopicShiftDecisionId.differentPack);
    });

    test('adjacent-but-unconfirmed context triggers prompt', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isTrue);
      expect(decision.decisionId, TopicShiftDecisionId.adjacentButUnconfirmed);
    });

    test('low relevance blocks quietly without prompt', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _lowRelevanceRecords(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
      expect(decision.reasonId, TopicShiftReasonId.lowRelevance);
    });

    test('prompt does not appear in first 60 seconds', () {
      CleanSlatePromptStore.seedSessionStartForTest(DateTime.now());
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isFalse);
    });

    test('Not now dismisses for session', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      CleanSlatePromptStore.dismissForSession(
        entryCount: 3,
        decision: decision,
      );
      final after = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
        trackAnalytics: false,
      );
      expect(after.shouldPrompt, isFalse);
      expect(
        _events.any(
          (e) => e.name == ActivationFunnelAnalytics.topicShiftPromptDismissed,
        ),
        isTrue,
      );
    });
  });

  group('Governance integration', () {
    test('Use archive context action allows governance to continue', () {
      _seedPastFirstMinute();
      final records = _crossThreadEvidence();
      CleanSlatePromptStore.chooseUseArchiveContext(entryCount: 3);
      EntryMemoryModeSession.select(EntryMemoryMode.useArchiveContext);
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        decision.decisionId,
        isNot(MemoryGovernanceDecisionId.blockedLowRelevance),
      );
      expect(
        TopicShiftGuard.blocksMemoryClaims(
          TopicShiftGuard.evaluate(
            entryCount: 3,
            records: records,
            trackAnalytics: false,
          ),
        ),
        isFalse,
      );
    });

    test('Keep separate action sets keepSeparate and blocks claims', () {
      _seedPastFirstMinute();
      CleanSlatePromptStore.chooseKeepSeparate(entryCount: 3);
      EntryMemoryModeSession.select(EntryMemoryMode.keepSeparate);
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _crossThreadEvidence(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        decision.decisionId,
        MemoryGovernanceDecisionId.blockedKeepSeparate,
      );
    });

    test(
      'adjacent-but-unconfirmed memory does not render claim before user choice',
      () {
        _seedPastFirstMinute();
        final decision = MemoryGovernancePolicy.evaluate(
          cardType: MemoryCardType.threadReturn,
          records: _crossThreadEvidence(),
          entryCount: 3,
          trackAnalytics: false,
          source: 'record',
        );
        expect(decision.allowed, isFalse);
        expect(decision.requiresUserConfirmation, isTrue);
      },
    );

    test('Start new thread choice allows thread-bound governance', () {
      _seedPastFirstMinute();
      CleanSlatePromptStore.chooseStartNewThread(entryCount: 3);
      EntryThreadScopeSession.setPendingNewThreadName('New topic');
      expect(
        TopicShiftGuard.blocksMemoryClaims(
          TopicShiftGuard.evaluate(
            entryCount: 3,
            records: _crossThreadEvidence(),
            trackAnalytics: false,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Clean slate prompt card', () {
    testWidgets('Keep separate action sets keepSeparate', (tester) async {
      _seedPastFirstMinute();
      const decision = TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.adjacentButUnconfirmed,
        reasonId: TopicShiftReasonId.samePack,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CleanSlatePromptCard(decision: decision, entryCount: 3),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('clean_slate_keep_separate')));
      await tester.pump();
      expect(EntryMemoryModeSession.selectedMode, EntryMemoryMode.keepSeparate);
    });

    testWidgets('prompt does not block save path', (tester) async {
      _seedPastFirstMinute();
      const decision = TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.adjacentButUnconfirmed,
        reasonId: TopicShiftReasonId.samePack,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                CleanSlatePromptCard(decision: decision, entryCount: 3),
                FilledButton(
                  key: const Key('save_cta'),
                  onPressed: () {},
                  child: const Text('Stop and save'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('save_cta')), findsOneWidget);
    });
  });

  group('Analytics privacy', () {
    test('topic_shift_checked payload contains no private text', () {
      _seedPastFirstMinute();
      TopicShiftGuard.evaluate(entryCount: 3, records: _crossThreadEvidence());
      final checked = _events.firstWhere(
        (e) => e.name == ActivationFunnelAnalytics.topicShiftChecked,
      );
      for (final value in checked.properties.values) {
        expect(value.toString().toLowerCase(), isNot(contains('thread_work')));
        expect(value.toString().toLowerCase(), isNot(contains('thread_home')));
      }
      expect(checked.properties.containsKey('decision_id'), isTrue);
      expect(checked.properties.containsKey('reason_id'), isTrue);
      expect(checked.properties.containsKey('suggested_action'), isTrue);
      expect(checked.properties.containsKey('memory_scope'), isTrue);
      expect(checked.properties.containsKey('entry_count'), isTrue);
    });

    test('analytics events use allowed ids only', () {
      _seedPastFirstMinute();
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: _crossThreadEvidence(),
      );
      CleanSlatePromptStore.notePromptSeen(entryCount: 3, decision: decision);
      CleanSlatePromptStore.chooseUseArchiveContext(
        entryCount: 3,
        decision: decision,
      );
      for (final event in _events) {
        final decisionId = event.properties['decision_id']?.toString();
        if (decisionId != null) {
          expect(
            ActivationFunnelAnalytics.allowedDecisionIdValues.contains(
              decisionId,
            ),
            isTrue,
            reason: decisionId,
          );
        }
        final reasonId = event.properties['reason_id']?.toString();
        if (reasonId != null) {
          expect(
            ActivationFunnelAnalytics.allowedReasonIdValues.contains(reasonId),
            isTrue,
            reason: reasonId,
          );
        }
        final suggested = event.properties['suggested_action']?.toString();
        if (suggested != null) {
          expect(
            ActivationFunnelAnalytics.allowedSuggestedActionValues.contains(
              suggested,
            ),
            isTrue,
          );
        }
      }
    });
  });

  group('Copy guard', () {
    test('consumer copy has no banned words or VoiceMemory', () {
      for (final line in CleanSlatePromptCopy.all) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower.contains(word.toLowerCase()), isFalse, reason: line);
        }
      }
    });
  });

  group('Save integration', () {
    test('resetAfterSave clears clean slate session choice', () {
      CleanSlatePromptStore.chooseKeepSeparate(entryCount: 3);
      CleanSlatePromptStore.resetAfterSave();
      expect(CleanSlatePromptStore.userChoice, isNull);
      expect(CleanSlatePromptStore.dismissedForSession, isFalse);
    });
  });
}
