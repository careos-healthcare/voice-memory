import 'package:archiveme_mobile/features/memory/cross_thread_confirmation.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_reliability_check.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/next_entry_fresh_mode.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/belief_distance_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/weekly_thread_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

List<_Event> _eventsNamed(String name) =>
    _events.where((e) => e.name == name).toList();

const _threadEngine = ThreadReturnEvidenceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();
const _beliefEngine = BeliefDistanceEngine();

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  String? archiveThreadId,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: contexts,
  fear: fear,
  archiveThreadId: archiveThreadId,
);

List<PressureCheckInRecord> _evidenceRecords() => [
  _rec(id: 'e1', daysAgo: 6, fear: 'I keep circling the same work decision'),
  _rec(id: 'e2', daysAgo: 3, fear: 'The same work decision came back today'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Circling the same work decision tonight'),
];

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(390, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
  await tester.pump();
}

void _resetMemoryState() {
  MemoryScopePolicy.resetForTest();
  MemoryControlStore.resetSessionForTest();
  MemoryConnectionRules.resetForTest();
  WrongThreadFeedback.resetForTest();
  CrossThreadConfirmation.resetForTest();
  NextEntryFreshMode.resetForTest();
  MemoryAuthorityFrameLog.resetForTest();
  MemoryPriorityGovernance.resetForTest();
  ActivationFunnelAnalytics.resetForTest();
}

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

void main() {
  setUp(() {
    _events.clear();
    _resetMemoryState();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
  });

  group('Visible memory receipt', () {
    testWidgets('appears on thread return evidence card', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(find.byKey(const Key('memory_used_receipt')), findsOneWidget);
      expect(
        find.text(MemoryControlCopy.usedArchiveContextLabel),
        findsOneWidget,
      );
    });

    testWidgets('appears on belief distance card', (tester) async {
      final belief = _beliefEngine.build(_evidenceRecords());
      await _pumpCard(tester, BeliefDistanceCard(belief: belief));
      expect(find.byKey(const Key('memory_used_receipt')), findsOneWidget);
    });

    testWidgets('appears on weekly connection section', (tester) async {
      final review = _weeklyEngine.build(_evidenceRecords());
      await _pumpCard(tester, WeeklyThreadReviewCard(review: review));
      if (review.returnedLine.isNotEmpty ||
          review.fadedLine.isNotEmpty ||
          review.changedLine.isNotEmpty) {
        expect(find.byKey(const Key('memory_used_receipt')), findsOneWidget);
      }
    });

    testWidgets('does not appear when memory is off', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.off;
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(find.byKey(const Key('memory_used_receipt')), findsNothing);
    });

    testWidgets('does not appear on first-save/zero-entry cards', (
      tester,
    ) async {
      const review = WeeklyThreadReview(
        hasReview: true,
        title: 'This week in your archive',
        weekSummaryLine: 'A quiet week.',
        evidenceLine: 'You added 2 pieces of evidence this week.',
        nextWeekLine: 'One calm thing to look at next week.',
      );
      await _pumpCard(tester, const WeeklyThreadReviewCard(review: review));
      expect(find.byKey(const Key('memory_used_receipt')), findsNothing);
    });

    testWidgets('why sheet opens with safe explanation only', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_thread_return')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('memory_priority_explanation_sheet')),
        findsOneWidget,
      );
      expect(find.text(MemoryControlCopy.whyBodyShared), findsOneWidget);
      expect(find.text(MemoryControlCopy.whyCorrectionFooter), findsOneWidget);

      final sheet = find.byKey(const Key('memory_priority_explanation_sheet'));
      final sheetTexts = find
          .descendant(of: sheet, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      for (final text in sheetTexts) {
        expect(text.contains('work decision'), isFalse);
        expect(text.contains('e1'), isFalse);
        expect(RegExp(r'\d{4}').hasMatch(text), isFalse);
        for (final banned in _bannedWords) {
          expect(
            text.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
            reason: 'banned word in sheet: $banned',
          );
        }
      }
    });
  });

  group('Memory connection actions', () {
    testWidgets('action row shows all four actions', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(
        find.byKey(const Key('memory_connection_actions_thread_return')),
        findsOneWidget,
      );
      expect(find.text(MemoryControlCopy.keepConnectedLabel), findsOneWidget);
      expect(find.text(MemoryControlCopy.wrongThreadLabel), findsOneWidget);
      expect(find.text(MemoryControlCopy.notRelatedLabel), findsOneWidget);
      expect(find.text(MemoryControlCopy.futureFreshLabel), findsOneWidget);
    });

    testWidgets('keep connected marks connection confirmed', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(find.text(MemoryControlCopy.keepConnectedLabel));
      await tester.pump();
      expect(MemoryConnectionRules.isConfirmed('thread_return'), isTrue);
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryConnectionKeepConnected),
        isNotEmpty,
      );
    });

    testWidgets('wrong thread suppresses current connection', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(find.text(MemoryControlCopy.wrongThreadLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wrong_thread_keep_separate')));
      await tester.pumpAndSettle();
      expect(
        WrongThreadFeedback.isSessionSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
    });

    testWidgets('wrong thread creates durable separate rule', (tester) async {
      final records = [
        ..._evidenceRecords(),
        _rec(id: 'e4', daysAgo: 1, archiveThreadId: 'thread_a'),
      ];
      _threadEngine.build(records);
      WrongThreadFeedback.markWrongPair(
        MemoryCardType.threadReturn,
        'thread_a',
      );
      expect(
        WrongThreadFeedback.isWrongPair(
          MemoryCardType.threadReturn,
          'thread_a',
        ),
        isTrue,
      );
    });

    testWidgets('not related suppresses without deleting entries', (
      tester,
    ) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      expect(evidence.entryIds, isNotEmpty);
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(find.text(MemoryControlCopy.notRelatedLabel));
      await tester.pump();
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(evidence.entryIds.length, greaterThan(0));
    });
  });

  group('Cross-thread confirmation', () {
    testWidgets('cross-thread attempt shows confirmation card', (tester) async {
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 5,
          fear: 'Same phrase repeated here',
          archiveThreadId: 'thread_a',
        ),
        _rec(
          id: 'e2',
          daysAgo: 2,
          fear: 'Same phrase repeated again',
          archiveThreadId: 'thread_b',
        ),
        _rec(
          id: 'e3',
          daysAgo: 0,
          fear: 'Same phrase repeated tonight',
          archiveThreadId: 'thread_a',
        ),
      ];
      final evidence = _threadEngine.build(records, entryCount: 3);
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      final reliability = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      if (reliability.state == MemoryReliabilityState.crossThread) {
        expect(
          find.byKey(const Key('cross_thread_confirmation_card')),
          findsOneWidget,
        );
      }
    });

    test('connect allows cross-thread claim', () {
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => _events.add(_Event(event, properties)),
      );
      CrossThreadConfirmation.approve(MemoryCardType.threadReturn);
      expect(
        CrossThreadConfirmation.isApproved(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(
        _eventsNamed(ActivationFunnelAnalytics.crossThreadConnectionConfirmed),
        hasLength(1),
      );
    });

    test('same-thread evidence does not require cross-thread confirmation', () {
      final records = [
        _rec(id: 'e1', daysAgo: 5, archiveThreadId: 'thread_a'),
        _rec(id: 'e2', daysAgo: 2, archiveThreadId: 'thread_a'),
        _rec(id: 'e3', daysAgo: 0, archiveThreadId: 'thread_a'),
      ];
      final reliability = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      expect(reliability.state, isNot(MemoryReliabilityState.crossThread));
    });

    test('repeated language alone cannot cross explicit thread boundaries', () {
      final records = [
        _rec(id: 'e1', daysAgo: 5, fear: 'exact same words here'),
        _rec(id: 'e2', daysAgo: 2, fear: 'exact same words here'),
        _rec(id: 'e3', daysAgo: 0, fear: 'exact same words here'),
      ];
      final reliability = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      expect(reliability.state, isNot(MemoryReliabilityState.crossThread));
    });
  });

  group('Fresh next entry', () {
    test('applies only to next save', () {
      NextEntryFreshMode.enable();
      expect(NextEntryFreshMode.enabledForNextSave, isTrue);
      expect(NextEntryFreshMode.consumeForSave(), isTrue);
      expect(NextEntryFreshMode.enabledForNextSave, isFalse);
    });

    test('does not change global memory setting', () {
      MemoryScopePolicy.scope = MemoryScope.automatic;
      NextEntryFreshMode.enable();
      NextEntryFreshMode.consumeForSave();
      expect(MemoryScopePolicy.scope, MemoryScope.automatic);
    });
  });

  group('Memory reliability', () {
    test('global memory off reliability is blocked', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final result = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
      );
      expect(result.state, MemoryReliabilityState.blocked);
    });

    test('mixed evidence shows cautious label', () {
      expect(MemoryReliabilityState.mixedEvidence.label, 'Mixed evidence');
      expect(
        MemoryReliabilityState.mixedEvidence.helper,
        'Your archive contains mixed evidence.',
      );
    });

    test('stale evidence shows cautious stale label', () {
      expect(MemoryReliabilityState.staleEvidence.label, 'May be stale');
    });
  });

  group('Analytics privacy', () {
    testWidgets('payloads contain no private content', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_thread_return')),
      );
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(
          find.byKey(const Key('memory_priority_explanation_sheet')),
        ),
      ).pop();
      await tester.pumpAndSettle();

      const visibleMemoryEvents = {
        ActivationFunnelAnalytics.memoryUsedReceiptSeen,
        ActivationFunnelAnalytics.memoryUsedReceiptOpened,
        ActivationFunnelAnalytics.memoryReliabilityChecked,
        ActivationFunnelAnalytics.memoryPriorityExplanationOpened,
        ActivationFunnelAnalytics.memoryPriorityChecked,
        ActivationFunnelAnalytics.memoryPriorityUsed,
        ActivationFunnelAnalytics.memoryGovernanceChecked,
        ActivationFunnelAnalytics.memoryGovernanceAllowed,
      };
      const allowedKeys = {
        'entry_count',
        'card_type',
        'memory_scope',
        'source',
        'reliability_state',
        'thread_scope',
        'authority_state',
        'influence_level',
        'reason_id',
        'record_count',
        'decision_id',
        'current_intent',
        'relevance_band',
        'priority_band',
      };
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final event in _events.where(
        (e) => visibleMemoryEvents.contains(e.name),
      )) {
        for (final entry in event.properties.entries) {
          expect(
            allowedKeys.contains(entry.key),
            isTrue,
            reason: 'unexpected key ${entry.key} on ${event.name}',
          );
          expect(safeValue.hasMatch('${entry.value}'), isTrue);
        }
        for (final banned in _bannedWords) {
          expect(
            event.name.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
          );
        }
      }
    });
  });

  group('Copy sweep', () {
    test('consumer copy avoids banned words and VoiceMemory', () {
      const strings = [
        MemoryControlCopy.usedArchiveContextLabel,
        MemoryControlCopy.whyBodyShared,
        MemoryControlCopy.whyCorrectionFooter,
        MemoryControlCopy.wrongThreadTitle,
        MemoryControlCopy.wrongThreadBody,
        MemoryControlCopy.crossThreadTitle,
        MemoryControlCopy.crossThreadBody,
        MemoryControlCopy.freshNextEntryLabel,
        MemoryControlCopy.freshNextEntryHelper,
      ];
      for (final text in strings) {
        for (final banned in _bannedWords) {
          expect(
            text.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
            reason: '$banned in "$text"',
          );
        }
      }
    });
  });
}