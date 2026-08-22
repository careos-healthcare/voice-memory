import 'dart:async';

import 'package:archiveme_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_frame.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_influence_level.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory/memory_authority_framing_sheet.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _framingEngine = MemoryAuthorityFramingEngine();
const _threadEngine = ThreadReturnEvidenceEngine();
const _beliefEngine = BeliefDistanceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();

final DateTime _base = DateTime(2026, 6, 9, 12);

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String optionId = 'could_not_stop',
  String? fear,
  bool treatAsNew = false,
  bool connectionApproved = false,
  int hoursAgo = 1,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: hoursAgo)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
  connectionApproved: connectionApproved,
);

/// Engine-grade evidence: a work thread with repeated language across days.
List<PressureCheckInRecord> _evidenceRecords({
  bool treatAsNew = false,
  bool connectionApproved = false,
}) => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    fear: 'I keep circling one hard work decision',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'One hard work decision came back tonight',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling one hard work decision at my desk',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
];

/// An old work thread plus newer unrelated entries: the archive moved on.
List<PressureCheckInRecord> _supersededRecords() => [
  _rec(id: 'o1', daysAgo: 20, fear: 'One hard work decision'),
  _rec(id: 'o2', daysAgo: 18, fear: 'One hard work decision again'),
  _rec(id: 'o3', daysAgo: 16, fear: 'Circling one hard work decision'),
  _rec(id: 'n1', daysAgo: 1, contexts: const [], optionId: 'guilty_resting'),
  _rec(
    id: 'n2',
    daysAgo: 0,
    contexts: const [],
    optionId: 'had_to_prove_enough',
  ),
];

MemoryAuthorityFrame _frameFor(
  List<PressureCheckInRecord> records, {
  MemoryCardType cardType = MemoryCardType.threadReturn,
}) => _framingEngine.frame(records, now: _base, cardType: cardType).frame;

void main() {
  setUp(() {
    MemoryScopePolicy.resetForTest();
    ArchiveRetrievalPolicy.resetSessionForTest();
    MemoryAuthorityFrameLog.resetForTest();
    MemoryControlStore.resetSessionForTest();
    ActivationFunnelAnalytics.resetForTest();
    _events.clear();
    ActivationFunnelAnalytics.captureForTest(
      (name, properties) => _events.add(_Event(name, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Authority framing — scope rules', () {
    test('memory off creates blocked frame and no memory claim', () {
      MemoryScopePolicy.scope = MemoryScope.off;

      final frame = _frameFor(_evidenceRecords());
      expect(frame.influenceLevel, MemoryInfluenceLevel.blocked);
      expect(frame.reasonId, 'memory_off');
      expect(frame.allowsConnectionClaims, isFalse);
      expect(
        _threadEngine.build(_evidenceRecords(), now: _base).hasEvidence,
        isFalse,
      );
      expect(_beliefEngine.build(_evidenceRecords()).hasBelief, isFalse);
      expect(
        _weeklyEngine.build(_evidenceRecords(), now: _base).hasReview,
        isFalse,
      );
    });

    test('treat-as-new creates fresh/suppress frame', () {
      final frame = _frameFor(_evidenceRecords(treatAsNew: true));
      expect(frame.authorityState, MemoryAuthorityState.fresh);
      expect(frame.influenceLevel, MemoryInfluenceLevel.suppress);
      expect(frame.reasonId, 'fresh_entry');
      expect(frame.allowsConnectionClaims, isFalse);
    });

    test('ask-mode unapproved entry creates suppress/unapproved frame', () {
      MemoryScopePolicy.scope = MemoryScope.ask;

      final frame = _frameFor(_evidenceRecords());
      expect(frame.influenceLevel, MemoryInfluenceLevel.suppress);
      expect(frame.reasonId, 'unapproved');
      expect(frame.allowsConnectionClaims, isFalse);
    });

    test('framing never widens scope decisions', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;

      // No shared explicit marker → scope suppresses; framing agrees.
      final unmarked = [
        _rec(id: 'm1', daysAgo: 3, contexts: const ['home']),
        _rec(id: 'm2', daysAgo: 0, contexts: const ['evening']),
      ];
      final frame = _frameFor(unmarked);
      expect(frame.allowsConnectionClaims, isFalse);
    });
  });

  group('Authority framing — evidence states', () {
    test('stale evidence creates background influence', () {
      // 31+ days old with strong relevance: retrievable, not claimable.
      final old = [
        _rec(id: 'old1', daysAgo: 40, fear: 'One hard work decision'),
        _rec(id: 'old2', daysAgo: 35, fear: 'One hard work decision again'),
      ];
      final frame = _frameFor(old);
      expect(frame.authorityState, MemoryAuthorityState.stale);
      expect(frame.influenceLevel, MemoryInfluenceLevel.background);
      expect(frame.reasonId, 'older_unreinforced');
      expect(frame.requiresCautiousCopy, isTrue);
      expect(_threadEngine.build(old, now: _base).hasEvidence, isFalse);
    });

    test('conflicting evidence creates mixed evidence frame', () {
      ArchiveRetrievalPolicy.markRecordNotQuite('e2');

      final frame = _frameFor(_evidenceRecords());
      expect(frame.authorityState, MemoryAuthorityState.conflicting);
      expect(frame.reasonId, 'mixed_evidence');
      expect(frame.requiresCautiousCopy, isTrue);
      expect(frame.authorityState.label, 'Mixed evidence');
    });

    test('superseded evidence creates changed later frame', () {
      final frame = _frameFor(_supersededRecords());
      expect(frame.authorityState, MemoryAuthorityState.superseded);
      expect(frame.influenceLevel, MemoryInfluenceLevel.background);
      expect(frame.reasonId, 'changed_later');
      expect(frame.authorityState.label, 'Changed later');
      // Old evidence is not presented as current.
      expect(
        _threadEngine.build(_supersededRecords(), now: _base).hasEvidence,
        isFalse,
      );
    });

    test('repeated recent evidence creates compare influence', () {
      final frame = _frameFor(_evidenceRecords());
      expect(frame.authorityState, MemoryAuthorityState.repeated);
      expect(frame.influenceLevel, MemoryInfluenceLevel.compare);
      expect(frame.reasonId, 'repeated_supported');
      expect(frame.allowsConnectionClaims, isTrue);
    });

    test('two recent related entries read as still current', () {
      final frame = _frameFor([
        _rec(id: 'a', daysAgo: 5, fear: 'One hard work decision'),
        _rec(id: 'b', daysAgo: 0, fear: 'One hard work decision again'),
      ]);
      expect(frame.authorityState, MemoryAuthorityState.current);
      expect(frame.reasonId, 'recent_supported');
      expect(frame.influenceLevel, MemoryInfluenceLevel.compare);
    });

    test('confirmed evidence creates highAuthority influence', () {
      final frame = _frameFor(_evidenceRecords(connectionApproved: true));
      expect(frame.authorityState, MemoryAuthorityState.confirmed);
      expect(frame.influenceLevel, MemoryInfluenceLevel.highAuthority);
      expect(frame.reasonId, 'user_confirmed');
      expect(frame.allowsConnectionClaims, isTrue);
    });

    test('retrieval relevance alone cannot create highAuthority', () {
      // The strongest possible unconfirmed evidence stays at compare.
      final frame = _frameFor(_evidenceRecords());
      expect(frame.influenceLevel, isNot(MemoryInfluenceLevel.highAuthority));
      expect(frame.influenceLevel, MemoryInfluenceLevel.compare);
    });

    test('duplicate grouping prevents inflated authority', () {
      // Three same-day near-identical entries: one group, no repetition.
      final duplicates = [
        for (var i = 0; i < 3; i++)
          _rec(
            id: 'd$i',
            daysAgo: 0,
            hoursAgo: i + 1,
            fear: 'One hard work decision',
          ),
      ];
      final frame = _frameFor(duplicates);
      expect(frame.authorityState, MemoryAuthorityState.duplicate);
      expect(frame.influenceLevel, MemoryInfluenceLevel.background);
      expect(frame.reasonId, 'grouped_duplicate');
      expect(frame.authorityState.label, 'Grouped duplicates');
      expect(_threadEngine.build(duplicates, now: _base).hasEvidence, isFalse);
    });
  });

  group('Authority framing — engine integration', () {
    test('thread return suppresses blocked/suppress frames', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      expect(
        _threadEngine.build(_evidenceRecords(), now: _base).hasEvidence,
        isFalse,
      );

      MemoryScopePolicy.scope = MemoryScope.automatic;
      expect(
        _threadEngine
            .build(_evidenceRecords(treatAsNew: true), now: _base)
            .hasEvidence,
        isFalse,
      );
      // Compare-level evidence still renders.
      expect(
        _threadEngine.build(_evidenceRecords(), now: _base).hasEvidence,
        isTrue,
      );
    });

    test('weekly review suppresses blocked/suppress frames', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      expect(
        _weeklyEngine.build(_evidenceRecords(), now: _base).hasReview,
        isFalse,
      );

      MemoryScopePolicy.scope = MemoryScope.automatic;
      final review = _weeklyEngine.build(_evidenceRecords(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.returnedLine, isNotEmpty);

      // Superseded evidence: no returned/faded/changed thread claims.
      final superseded = _weeklyEngine.build(_supersededRecords(), now: _base);
      expect(superseded.returnedLine, isEmpty);
      expect(superseded.fadedLine, isEmpty);
      expect(superseded.changedLine, isEmpty);
    });

    test('belief distance suppresses blocked/suppress frames', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      expect(_beliefEngine.build(_evidenceRecords()).hasBelief, isFalse);

      MemoryScopePolicy.scope = MemoryScope.automatic;
      expect(
        _beliefEngine.build(_evidenceRecords(treatAsNew: true)).hasBelief,
        isFalse,
      );
      expect(_beliefEngine.build(_evidenceRecords()).hasBelief, isTrue);
    });

    testWidgets('every memory card uses an authority frame before rendering', (
      tester,
    ) async {
      final evidence = _threadEngine.build(_evidenceRecords(), now: _base);
      expect(evidence.hasEvidence, isTrue);

      // The engine recorded the frame its evidence carried.
      final frame = MemoryAuthorityFrameLog.frameFor(
        MemoryCardType.threadReturn,
      );
      expect(frame, isNotNull);
      expect(frame!.allowsConnectionClaims, isTrue);

      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadReturnEvidenceCard(evidence: evidence),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('memory_authority_frame_thread_return')),
        findsOneWidget,
      );
      expect(find.text('Repeated evidence'), findsOneWidget);
      expect(find.text('How this memory was used'), findsOneWidget);
    });
  });

  group('Authority framing — explanation sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      MemoryAuthorityFrame frame,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: MemoryAuthorityFramingSheet(frame: frame)),
        ),
      );
      await tester.pump();
    }

    MemoryAuthorityFrame frameWith(MemoryInfluenceLevel level) =>
        MemoryAuthorityFrame(
          authorityState: MemoryAuthorityState.repeated,
          influenceLevel: level,
          reasonId: 'repeated_supported',
          cardType: 'thread_return',
        );

    testWidgets('sheet copy is exact for every influence level', (
      tester,
    ) async {
      const expected = {
        MemoryInfluenceLevel.blocked:
            'Memory is off, so ArchiveMe is not using previous entries here.',
        MemoryInfluenceLevel.suppress:
            'This entry is being kept separate from connection suggestions.',
        MemoryInfluenceLevel.background:
            'ArchiveMe found related evidence, but it is being treated '
            'cautiously.',
        MemoryInfluenceLevel.compare:
            'ArchiveMe found enough eligible evidence to compare this with '
            'your archive.',
        MemoryInfluenceLevel.highAuthority:
            'You previously confirmed this connection, so ArchiveMe gives '
            'it more weight.',
      };
      for (final level in MemoryInfluenceLevel.values) {
        await pumpSheet(tester, frameWith(level));
        expect(find.text('How this memory was used'), findsOneWidget);
        expect(find.text(expected[level]!), findsOneWidget);
        expect(
          find.text(
            'You can mark a connection as not related if it does not fit.',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('sheet contains no raw notes, snippets, dates, or entry ids', (
      tester,
    ) async {
      // A frame produced from real evidence with private note text.
      _threadEngine.build(_evidenceRecords(), now: _base);
      final frame = MemoryAuthorityFrameLog.frameFor(
        MemoryCardType.threadReturn,
      )!;
      await pumpSheet(tester, frame);

      final sheetTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('memory_authority_framing_sheet')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
      expect(sheetTexts, isNotEmpty);
      const allowed = {
        'How this memory was used',
        'Compared with archive',
        'Repeated evidence',
        'ArchiveMe found enough eligible evidence to compare this with '
            'your archive.',
        'You can mark a connection as not related if it does not fit.',
      };
      for (final text in sheetTexts) {
        expect(
          allowed.contains(text),
          isTrue,
          reason: 'unexpected sheet text: $text',
        );
        expect(text.contains('decision'), isFalse);
        expect(text.contains('circling'), isFalse);
        expect(text.contains('e1'), isFalse);
        expect(text.contains('%'), isFalse);
        expect(RegExp(r'\d').hasMatch(text), isFalse);
      }
    });

    testWidgets('opening the sheet fires the framing-opened event', (
      tester,
    ) async {
      await pumpSheet(tester, frameWith(MemoryInfluenceLevel.compare));
      // The returned future completes only when the sheet closes, so it
      // is deliberately not awaited.
      unawaited(
        MemoryAuthorityFramingSheet.show(
          tester.element(find.byType(Scaffold)),
          frameWith(MemoryInfluenceLevel.compare),
        ),
      );
      await tester.pumpAndSettle();
      final opened = _events
          .where((e) => e.name == 'memory_authority_framing_opened')
          .toList();
      expect(opened, hasLength(1));
      expect(opened.first.properties['influence_level'], 'compare');
      expect(opened.first.properties['authority_state'], 'repeated');
      expect(opened.first.properties['reason_id'], 'repeated_supported');
      expect(opened.first.properties['card_type'], 'thread_return');
    });
  });

  group('Authority framing — analytics privacy', () {
    test('frame events carry stable ids and safe counts only', () {
      _frameFor(_evidenceRecords());

      final created = _events
          .where((e) => e.name == 'memory_authority_frame_created')
          .toList();
      final used = _events
          .where((e) => e.name == 'memory_influence_used')
          .toList();
      expect(created, hasLength(1));
      expect(used, hasLength(1));
      expect(created.first.properties['authority_state'], 'repeated');
      expect(created.first.properties['influence_level'], 'compare');
      expect(created.first.properties['reason_id'], 'repeated_supported');
      expect(created.first.properties['card_type'], 'thread_return');
      expect(created.first.properties['memory_scope'], 'automatic');
      expect(created.first.properties['entry_count'], 3);
    });

    test('suppressed frames fire memory_influence_suppressed', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      _frameFor(_evidenceRecords());

      final suppressed = _events
          .where((e) => e.name == 'memory_influence_suppressed')
          .toList();
      expect(suppressed, hasLength(1));
      expect(suppressed.first.properties['influence_level'], 'blocked');
      expect(suppressed.first.properties['reason_id'], 'memory_off');
      expect(suppressed.first.properties['entry_count'], 0);
      expect(_events.where((e) => e.name == 'memory_influence_used'), isEmpty);
    });

    test('analytics payload contains only stable ids and safe counts', () {
      _frameFor(_evidenceRecords());
      ArchiveRetrievalPolicy.markRecordNotQuite('e2');
      _frameFor(_evidenceRecords());
      _frameFor(_supersededRecords());

      expect(_events, isNotEmpty);
      for (final event in _events) {
        for (final key in event.properties.keys) {
          expect(
            ActivationFunnelAnalytics.allowedPropertyKeys,
            contains(key),
            reason: '$key is not a whitelisted property',
          );
        }
        for (final value in event.properties.values) {
          expect(value is int || value is String, isTrue);
          if (value is String) {
            expect(
              RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(value),
              isTrue,
              reason: '"$value" is not a stable id',
            );
            expect(value, isNot(contains('decision')));
            expect(value, isNot(contains('circling')));
          }
        }
      }
    });

    test('repeat framing does not spam events in one session', () {
      _frameFor(_evidenceRecords());
      _frameFor(_evidenceRecords());
      _frameFor(_evidenceRecords());

      expect(
        _events.where((e) => e.name == 'memory_authority_frame_created'),
        hasLength(1),
      );
      expect(
        _events.where((e) => e.name == 'memory_influence_used'),
        hasLength(1),
      );
    });
  });

  group('Authority framing — copy guardrails', () {
    const allCopy = [
      MemoryAuthorityCopy.actionLabel,
      MemoryAuthorityCopy.sheetTitle,
      MemoryAuthorityCopy.blockedBody,
      MemoryAuthorityCopy.suppressBody,
      MemoryAuthorityCopy.backgroundBody,
      MemoryAuthorityCopy.compareBody,
      MemoryAuthorityCopy.highAuthorityBody,
      MemoryAuthorityCopy.sheetFooter,
      'Memory blocked',
      'Background evidence',
      'Compared with archive',
      'User confirmed',
      'Not used for connection',
      'Still current',
      'Repeated evidence',
      'May be stale',
      'Changed later',
      'Mixed evidence',
      'Grouped duplicates',
      'Fresh entry',
    ];

    test('all influence and authority labels match the spec', () {
      expect(MemoryInfluenceLevel.blocked.label, 'Memory blocked');
      expect(MemoryInfluenceLevel.background.label, 'Background evidence');
      expect(MemoryInfluenceLevel.compare.label, 'Compared with archive');
      expect(MemoryInfluenceLevel.highAuthority.label, 'User confirmed');
      expect(MemoryInfluenceLevel.suppress.label, 'Not used for connection');
      expect(MemoryAuthorityState.current.label, 'Still current');
      expect(MemoryAuthorityState.repeated.label, 'Repeated evidence');
      expect(MemoryAuthorityState.confirmed.label, 'User confirmed');
      expect(MemoryAuthorityState.stale.label, 'May be stale');
      expect(MemoryAuthorityState.superseded.label, 'Changed later');
      expect(MemoryAuthorityState.conflicting.label, 'Mixed evidence');
      expect(MemoryAuthorityState.duplicate.label, 'Grouped duplicates');
      expect(MemoryAuthorityState.fresh.label, 'Fresh entry');
    });

    test('no VoiceMemory in consumer-facing copy', () {
      for (final line in allCopy) {
        expect(line.toLowerCase(), isNot(contains('voicememory')));
        expect(line.toLowerCase(), isNot(contains('voice memory')));
      }
    });

    test('no percentages or certainty claims in copy', () {
      for (final line in allCopy) {
        expect(line, isNot(contains('%')));
        expect(line.toLowerCase(), isNot(contains('certain')));
        expect(line.toLowerCase(), isNot(contains('deterministic')));
      }
    });

    test('banned-word sweep', () {
      const banned = [
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
      ];
      for (final line in allCopy) {
        final words = line
            .toLowerCase()
            .split(RegExp('[^a-z]+'))
            .where((w) => w.isNotEmpty)
            .toSet();
        for (final word in banned) {
          expect(
            words,
            isNot(contains(word)),
            reason: '"$word" found in "$line"',
          );
        }
      }
    });
  });
}