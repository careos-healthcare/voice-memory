import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/pro_retention_check.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:voicememory_mobile/features/memory/memory_relevance_gate.dart';
import 'package:voicememory_mobile/features/memory/memory_relevance_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/features/referral/referral_invite_after_value.dart';
import 'package:voicememory_mobile/features/review/review_prompt_after_value.dart';
import 'package:voicememory_mobile/features/share/archive_belief_share_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/memory/fresh_entry_choice.dart';
import 'package:voicememory_mobile/widgets/memory/memory_relevance_chip.dart';

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  String optionId = 'could_not_stop',
  List<String> contexts = const [],
  String? fear,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
);

/// No overlap at all: different options, no contexts, no text, far apart.
List<PressureCheckInRecord> _freshRecords() => [
  _rec(id: 'f1', daysAgo: 40, optionId: 'could_not_stop'),
  _rec(id: 'f2', daysAgo: 20, optionId: 'guilty_resting'),
];

/// One loose signal only: a repeated raw option id the evidence engine
/// does not map to a theme — nothing it can build a thread from.
List<PressureCheckInRecord> _weakRecords() => [
  _rec(id: 'w1', daysAgo: 40, optionId: 'context_tag'),
  _rec(id: 'w2', daysAgo: 20, optionId: 'context_tag'),
];

/// Two loose signals (repeated raw option id + recent density) but still
/// nothing the evidence engine supports.
List<PressureCheckInRecord> _possibleRecords() => [
  _rec(id: 'p1', daysAgo: 9, optionId: 'context_tag'),
  _rec(id: 'p2', daysAgo: 5, optionId: 'context_tag'),
  _rec(id: 'p3', daysAgo: 1, optionId: 'context_tag'),
];

/// Engine-backed: a work thread that repeats with shared contexts and
/// repeated language, plus an older evening thread that went quieter.
List<PressureCheckInRecord> _strongRecords() => [
  _rec(
    id: 's1',
    daysAgo: 13,
    contexts: const ['evening'],
    fear: 'Evening wind-down kept slipping late',
  ),
  _rec(
    id: 's2',
    daysAgo: 9,
    contexts: const ['evening'],
    fear: 'Evening wind-down slipping late again',
  ),
  _rec(
    id: 's3',
    daysAgo: 6,
    contexts: const ['work'],
    fear: 'I keep circling the same work decision',
  ),
  _rec(
    id: 's4',
    daysAgo: 3,
    contexts: const ['work'],
    fear: 'The same work decision came back today',
  ),
  _rec(
    id: 's5',
    daysAgo: 0,
    contexts: const ['work'],
    fear: 'Circling the same work decision tonight',
  ),
];

const _gate = MemoryRelevanceGate();
const _threadEngine = ThreadReturnEvidenceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();
const _beliefEngine = BeliefDistanceEngine();

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

List<_Event> _eventsNamed(String name) =>
    _events.where((e) => e.name == name).toList();

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 8000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: false),
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoMemoryCards() {
  expect(find.byKey(const Key('thread_return_evidence_card')), findsNothing);
  expect(find.byKey(const Key('belief_distance_card')), findsNothing);
  expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
}

void main() {
  setUp(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    MemoryRelevanceGate.resetSessionForTest();
    ReferralInviteAfterValue.resetSessionForTest();
    ReviewPromptAfterValue.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
  });

  tearDown(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    MemoryRelevanceGate.resetSessionForTest();
    ReferralInviteAfterValue.resetSessionForTest();
    ReviewPromptAfterValue.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
  });

  group('Relevance rules', () {
    test('no records or a single record is fresh', () {
      expect(_gate.assess(const []).relevance, MemoryRelevance.fresh);
      expect(
        _gate.assess([_rec(id: 'only', daysAgo: 1)]).relevance,
        MemoryRelevance.fresh,
      );
    });

    test('unconnected records are fresh', () {
      final assessment = _gate.assess(_freshRecords());
      expect(assessment.relevance, MemoryRelevance.fresh);
      expect(assessment.signalCount, 0);
    });

    test('one loose signal is weak', () {
      final assessment = _gate.assess(_weakRecords());
      expect(assessment.relevance, MemoryRelevance.weak);
      expect(assessment.signalCount, 1);
    });

    test('two safe signals without engine support is possible', () {
      final assessment = _gate.assess(_possibleRecords());
      expect(assessment.relevance, MemoryRelevance.possible);
      expect(assessment.signalCount, greaterThanOrEqualTo(2));
    });

    test('strong only when the evidence engine already supports it', () {
      // Strong fixture: the existing engine holds the evidence.
      expect(_threadEngine.build(_strongRecords()).hasEvidence, isTrue);
      expect(_gate.assess(_strongRecords()).relevance, MemoryRelevance.strong);

      // Anything the engine does not support can never be strong.
      for (final records in [
        _freshRecords(),
        _weakRecords(),
        _possibleRecords(),
      ]) {
        expect(_threadEngine.build(records).hasEvidence, isFalse);
        expect(_gate.assess(records).relevance, isNot(MemoryRelevance.strong));
      }
    });

    test('memory cards are allowed only for strong relevance', () {
      expect(
        MemoryRelevanceGate.allowMemoryCards(_gate.assess(_strongRecords())),
        isTrue,
      );
      for (final records in [
        _freshRecords(),
        _weakRecords(),
        _possibleRecords(),
      ]) {
        expect(
          MemoryRelevanceGate.allowMemoryCards(_gate.assess(records)),
          isFalse,
        );
      }
    });

    test('existing thread return / weekly review / belief distance still '
        'work when strong evidence exists', () {
      final records = _strongRecords();
      expect(_threadEngine.build(records).hasEvidence, isTrue);
      expect(_weeklyEngine.build(records).hasReview, isTrue);
      expect(_beliefEngine.build(records).hasBelief, isTrue);
    });
  });

  group('Insights screen gating', () {
    testWidgets('fresh entries do not trigger memory cards', (tester) async {
      await _pumpInsights(tester, records: _freshRecords());
      _expectNoMemoryCards();
      expect(find.byKey(const Key('memory_relevance_chip')), findsNothing);
    });

    testWidgets('weak relevance does not trigger major interpretation', (
      tester,
    ) async {
      await _pumpInsights(tester, records: _weakRecords());
      _expectNoMemoryCards();
      expect(find.byKey(const Key('memory_relevance_chip')), findsNothing);
    });

    testWidgets('possible relevance uses cautious may-relate copy only', (
      tester,
    ) async {
      await _pumpInsights(tester, records: _possibleRecords());
      expect(find.byKey(const Key('memory_relevance_chip')), findsOneWidget);
      expect(find.text(MemoryRelevanceChip.possibleTitle), findsOneWidget);
      expect(find.text(MemoryRelevanceChip.possibleBody), findsOneWidget);
      expect(find.text(MemoryRelevanceChip.strongTitle), findsNothing);
      _expectNoMemoryCards();

      final seen = _eventsNamed(ActivationFunnelAnalytics.memoryRelevanceSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties['relevance'], 'possible');
    });

    testWidgets('strong relevance shows the evidence cards and strong copy', (
      tester,
    ) async {
      await _pumpInsights(tester, records: _strongRecords());
      expect(find.text(MemoryRelevanceChip.strongTitle), findsOneWidget);
      expect(find.text(MemoryRelevanceChip.strongBody), findsOneWidget);
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('belief_distance_card')), findsOneWidget);
      expect(
        find.byKey(const Key('weekly_thread_review_card')),
        findsOneWidget,
      );

      final seen = _eventsNamed(ActivationFunnelAnalytics.memoryRelevanceSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties['relevance'], 'strong');
    });

    testWidgets('user can mark the connection not related', (tester) async {
      await _pumpInsights(tester, records: _strongRecords());
      await tester.ensureVisible(
        find.byKey(const Key('memory_relevance_not_related')),
      );
      await tester.tap(find.byKey(const Key('memory_relevance_not_related')));
      await tester.pumpAndSettle();

      expect(
        find.text(MemoryRelevanceChip.notRelatedConfirmation),
        findsOneWidget,
      );
      _expectNoMemoryCards();

      final marked = _eventsNamed(
        ActivationFunnelAnalytics.memoryMarkedNotRelated,
      );
      expect(marked, hasLength(1));
      expect(marked.single.properties['relevance'], 'strong');
      expect(marked.single.properties['card_type'], 'memory_relevance');
    });

    testWidgets('not-related suppresses that connection for the session', (
      tester,
    ) async {
      MemoryRelevanceGate.markNotRelated(
        MemoryRelevanceGate.insightsConnectionId,
      );
      await _pumpInsights(tester, records: _strongRecords());
      _expectNoMemoryCards();
      expect(find.byKey(const Key('memory_relevance_chip')), findsNothing);
      // Suppression is session state only — the archive itself is intact.
      expect(_threadEngine.build(_strongRecords()).hasEvidence, isTrue);
    });

    testWidgets('save without connecting bypasses memory interpretation', (
      tester,
    ) async {
      MemoryRelevanceGate.saveWithoutConnectingThisSession = true;
      await _pumpInsights(tester, records: _strongRecords());
      _expectNoMemoryCards();
      expect(find.byKey(const Key('memory_relevance_chip')), findsNothing);
    });

    testWidgets('treat as new bypasses memory interpretation', (tester) async {
      MemoryRelevanceGate.treatAsNewThisSession = true;
      await _pumpInsights(tester, records: _strongRecords());
      _expectNoMemoryCards();
      expect(find.byKey(const Key('memory_relevance_chip')), findsNothing);
    });
  });

  group('Fresh entry choice', () {
    testWidgets('treat this as new sets the session flag and tracks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FreshEntryChoice())),
      );
      expect(find.text(FreshEntryChoice.title), findsOneWidget);
      expect(find.text(FreshEntryChoice.body), findsOneWidget);

      await tester.tap(find.byKey(const Key('fresh_entry_treat_as_new')));
      await tester.pumpAndSettle();

      expect(MemoryRelevanceGate.treatAsNewThisSession, isTrue);
      final selected = _eventsNamed(
        ActivationFunnelAnalytics.freshEntrySelected,
      );
      expect(selected, hasLength(1));
      expect(selected.single.properties['relevance'], 'fresh');
    });

    testWidgets('save without connecting runs the stripped save and tracks', (
      tester,
    ) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshEntryChoice(
              onSaveWithoutConnecting: () async => saves++,
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const Key('fresh_entry_save_without_connecting')),
      );
      await tester.pumpAndSettle();

      expect(saves, 1);
      expect(MemoryRelevanceGate.saveWithoutConnectingThisSession, isTrue);
      final selected = _eventsNamed(
        ActivationFunnelAnalytics.saveWithoutConnectingSelected,
      );
      expect(selected, hasLength(1));
      expect(selected.single.properties['relevance'], 'fresh');
    });
  });

  group('Analytics privacy', () {
    testWidgets('no raw notes, snippets, or belief phrases in payloads', (
      tester,
    ) async {
      // Full flow: strong seen, marked not related, then both opt-outs.
      await _pumpInsights(tester, records: _strongRecords());
      await tester.ensureVisible(
        find.byKey(const Key('memory_relevance_not_related')),
      );
      await tester.tap(find.byKey(const Key('memory_relevance_not_related')));
      await tester.pumpAndSettle();
      MemoryRelevanceGate.resetSessionForTest();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshEntryChoice(onSaveWithoutConnecting: () async {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('fresh_entry_treat_as_new')));
      await tester.tap(
        find.byKey(const Key('fresh_entry_save_without_connecting')),
      );
      await tester.pumpAndSettle();

      final relevanceEvents = _events
          .where(
            (e) => const {
              'memory_relevance_seen',
              'memory_marked_not_related',
              'fresh_entry_selected',
              'save_without_connecting_selected',
            }.contains(e.name),
          )
          .toList();
      expect(relevanceEvents, isNotEmpty);

      final stableId = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final event in relevanceEvents) {
        for (final entry in event.properties.entries) {
          expect(
            const {'relevance', 'card_type', 'entry_count'}.contains(entry.key),
            isTrue,
            reason: 'unexpected property ${entry.key} on ${event.name}',
          );
          final value = entry.value;
          if (value is String) {
            expect(
              stableId.hasMatch(value),
              isTrue,
              reason: '$value must look like a stable id',
            );
            // Never any fixture note text or fragments of it.
            expect(value.contains('decision'), isFalse);
            expect(value.contains('evening'), isFalse);
            expect(value.contains('circling'), isFalse);
          } else {
            expect(value, isA<int>());
          }
          if (entry.key == 'relevance') {
            expect(
              ActivationFunnelAnalytics.allowedRelevanceValues.contains(value),
              isTrue,
            );
          }
        }
      }
    });
  });

  group('Copy guardrails', () {
    const allCopy = [
      MemoryRelevanceChip.possibleTitle,
      MemoryRelevanceChip.possibleBody,
      MemoryRelevanceChip.strongTitle,
      MemoryRelevanceChip.strongBody,
      MemoryRelevanceChip.notRelatedLabel,
      MemoryRelevanceChip.notRelatedConfirmation,
      FreshEntryChoice.title,
      FreshEntryChoice.body,
      FreshEntryChoice.treatAsNewLabel,
      FreshEntryChoice.saveWithoutConnectingLabel,
    ];

    test('expected exact copy', () {
      expect(FreshEntryChoice.title, 'Not everything needs to connect.');
      expect(FreshEntryChoice.body, 'Save this as a fresh entry.');
      expect(MemoryRelevanceChip.possibleTitle, 'Possible connection');
      expect(
        MemoryRelevanceChip.possibleBody,
        'This may relate to something already in your archive.',
      );
      expect(MemoryRelevanceChip.strongTitle, 'Strong connection');
      expect(
        MemoryRelevanceChip.strongBody,
        'This has enough evidence to compare with earlier entries.',
      );
      expect(MemoryRelevanceChip.notRelatedLabel, 'Not related');
      expect(
        MemoryRelevanceChip.notRelatedConfirmation,
        'Thanks — ArchiveMe will treat this as separate.',
      );
    });

    test('no VoiceMemory in consumer copy', () {
      final flat = allCopy.join(' ').toLowerCase();
      expect(flat, isNot(contains('voicememory')));
      expect(flat, isNot(contains('voice memory')));
    });

    test('banned-word sweep', () {
      final flat = allCopy.join(' ').toLowerCase();
      for (final banned in const [
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
      ]) {
        expect(
          RegExp('\\b$banned\\b').hasMatch(flat),
          isFalse,
          reason: 'copy must not contain "$banned"',
        );
      }
    });

    test('no percentages anywhere in relevance copy', () {
      expect(allCopy.join(' ').contains('%'), isFalse);
    });
  });
}
