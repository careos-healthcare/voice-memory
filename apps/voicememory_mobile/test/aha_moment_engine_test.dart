import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_candidate.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_engine.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_store.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_frame.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_connection_rules.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_control_store.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/not_important_feedback.dart';
import 'package:voicememory_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/aha/aha_moment_feedback_row.dart';
import 'package:voicememory_mobile/widgets/aha/first_aha_moment_card.dart';
import 'package:voicememory_mobile/widgets/memory/memory_evidence_inspect_sheet.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';

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

final DateTime _now = DateTime(2026, 6, 12, 12);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  bool treatAsNew = false,
  bool keepSeparate = false,
  bool connectionApproved = false,
  String optionId = 'could_not_stop',
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: _now.subtract(Duration(days: daysAgo, hours: 1)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  connectionApproved: connectionApproved,
);

List<PressureCheckInRecord> _relatedRecords() => [
  _rec(id: 'e1', daysAgo: 6, fear: 'I keep circling the same work decision'),
  _rec(id: 'e2', daysAgo: 3, fear: 'The same work decision came back today'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Circling the same work decision tonight'),
];

List<PressureCheckInRecord> _stalePair() => [
  _rec(id: 's1', daysAgo: 45, fear: 'Old work worry'),
  _rec(id: 's2', daysAgo: 40, fear: 'Same work worry again'),
];

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryScopePolicy.scope = MemoryScope.automatic;
  MemoryAuthorityFrameLog.resetForTest();
  MemoryConnectionRules.resetForTest();
  MemoryControlStore.resetSessionForTest();
  WrongThreadFeedback.resetForTest();
  NotImportantFeedback.resetForTest();
  AhaMomentStore.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

AhaMomentCandidate _candidate({
  bool useCautiousCopy = false,
  int entryCount = 3,
}) => AhaMomentCandidate(
  entryCount: entryCount,
  eligibleEntryCount: 2,
  memoryScope: MemoryScope.automatic.id,
  priorityBand: 'normal',
  authorityState: useCautiousCopy
      ? MemoryAuthorityState.stale
      : MemoryAuthorityState.current,
  useCautiousCopy: useCautiousCopy,
);

void main() {
  const engine = AhaMomentEngine();

  setUp(_reset);

  group('Eligibility', () {
    test('no aha moment with one entry', () {
      final candidate = engine.evaluate(
        records: _relatedRecords(),
        entryCount: 1,
        trackAnalytics: false,
      );
      expect(candidate, isNull);
    });

    test('no aha moment when memory off', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final candidate = engine.evaluate(
        records: _relatedRecords(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(candidate, isNull);
    });

    test('no aha moment for treat-as-new', () {
      final records = [
        _rec(id: 'e1', daysAgo: 2, treatAsNew: true),
        _rec(id: 'e2', daysAgo: 1),
        _rec(id: 'e3', daysAgo: 0),
      ];
      expect(
        engine.evaluate(records: records, entryCount: 3, trackAnalytics: false),
        isNull,
      );
    });

    test('no aha moment for keep-separate', () {
      final records = [
        _rec(id: 'e1', daysAgo: 2, keepSeparate: true),
        _rec(id: 'e2', daysAgo: 1),
        _rec(id: 'e3', daysAgo: 0),
      ];
      expect(
        engine.evaluate(records: records, entryCount: 3, trackAnalytics: false),
        isNull,
      );
    });

    test('aha candidate appears with two eligible related entries', () {
      final records = _relatedRecords().take(2).toList();
      final candidate = engine.evaluate(
        records: records,
        entryCount: 2,
        now: _now,
        trackAnalytics: false,
      );
      expect(candidate, isNotNull);
      expect(candidate!.eligibleEntryCount, greaterThanOrEqualTo(2));
      expect(candidate.title, AhaMomentCopy.title);
    });

    test('user-confirmed connection can create candidate', () {
      MemoryConnectionRules.keepConnected(MemoryCardType.threadReturn);
      final records = [
        _rec(id: 'e1', daysAgo: 2, connectionApproved: true),
        _rec(id: 'e2', daysAgo: 0),
      ];
      final candidate = engine.evaluate(
        records: records,
        entryCount: 2,
        now: _now,
        trackAnalytics: false,
      );
      expect(candidate, isNotNull);
    });

    test('stale/mixed evidence uses cautious copy', () {
      final candidate = engine.evaluate(
        records: _stalePair(),
        entryCount: 2,
        now: _now,
        trackAnalytics: false,
      );
      if (candidate != null) {
        expect(candidate.useCautiousCopy, isTrue);
        expect(candidate.title, AhaMomentCopy.cautiousTitle);
        expect(candidate.body, AhaMomentCopy.cautiousBody);
      }
    });

    test('no duplicate aha when stronger memory card exists', () {
      final records = _relatedRecords();
      final stronger = AhaMomentEngine.hasStrongerMemoryCard(
        records: records,
        entryCount: 3,
        now: _now,
      );
      expect(stronger, isTrue);
      expect(
        engine.evaluate(
          records: records,
          entryCount: 3,
          hasStrongerMemoryCardVisible: true,
          trackAnalytics: false,
        ),
        isNull,
      );
    });

    test('not related suppresses candidate', () {
      MemoryControlStore.markNotRelated(MemoryCardType.threadReturn);
      expect(
        engine.evaluate(
          records: _relatedRecords(),
          entryCount: 3,
          trackAnalytics: false,
        ),
        isNull,
      );
    });
  });

  group('Copy guardrails', () {
    test('first aha card copy is exact', () {
      expect(AhaMomentCopy.title, 'This came back again');
      expect(
        AhaMomentCopy.body,
        'ArchiveMe noticed this returned in your archive.',
      );
      expect(
        AhaMomentCopy.helperLine,
        'You can check the evidence or mark it as not related.',
      );
      expect(AhaMomentCopy.cautiousTitle, 'This may be returning');
      expect(
        AhaMomentCopy.cautiousBody,
        'ArchiveMe found related evidence, but it is being treated cautiously.',
      );
    });

    test('no VoiceMemory in consumer copy', () {
      for (final line in AhaMomentCopy.all) {
        expect(line.contains('VoiceMemory'), isFalse);
      }
    });

    test('banned-word sweep', () {
      final corpus = AhaMomentCopy.all.join('\n').toLowerCase();
      for (final word in _bannedWords) {
        expect(
          RegExp('\\b${word.toLowerCase()}\\b').hasMatch(corpus),
          isFalse,
          reason: 'banned word: $word',
        );
      }
    });
  });

  group('Card widgets', () {
    testWidgets('first aha card renders standard copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstAhaMomentCard(candidate: _candidate(), onChanged: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AhaMomentCopy.title), findsOneWidget);
      expect(find.text(AhaMomentCopy.body), findsOneWidget);
      expect(find.text(AhaMomentCopy.helperLine), findsOneWidget);
    });

    testWidgets('Show evidence opens safe evidence sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const framingEngine = MemoryAuthorityFramingEngine();
      framingEngine.frame(
        _relatedRecords(),
        now: _now,
        cardType: MemoryCardType.threadReturn,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstAhaMomentCard(
                candidate: _candidate(),
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aha_moment_show_evidence')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(MemoryEvidenceInspectCopy.sheetTitle), findsOneWidget);
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.ahaMomentShowEvidenceTapped),
      );
    });

    testWidgets('Useful increases connection weight safely', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AhaMomentFeedbackRow(
              candidate: _candidate(),
              onFeedback: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aha_moment_useful')));
      await tester.pump();

      expect(
        MemoryConnectionRules.isConfirmed(MemoryCardType.threadReturn.id),
        isTrue,
      );
      expect(find.text(AhaMomentCopy.usefulThanks), findsOneWidget);
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.ahaMomentUseful),
      );
    });

    testWidgets('Not quite demotes cautiously', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AhaMomentFeedbackRow(
              candidate: _candidate(),
              onFeedback: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aha_moment_not_quite')));
      await tester.pump();

      expect(
        NotImportantFeedback.isDemoted(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(find.text(AhaMomentCopy.notQuiteThanks), findsOneWidget);
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.ahaMomentNotQuite),
      );
    });

    testWidgets('Not important demotes priority', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstAhaMomentCard(candidate: _candidate(), onChanged: () {}),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aha_moment_not_important')));
      await tester.pump();

      expect(
        NotImportantFeedback.isDemoted(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(AhaMomentStore.firstAhaCompleted, isTrue);
    });

    testWidgets('Not related suppresses card', (tester) async {
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstAhaMomentCard(
              candidate: _candidate(),
              onChanged: () => changed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aha_moment_not_related')));
      await tester.pump();

      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(changed, isTrue);
      expect(AhaMomentStore.firstAhaCompleted, isTrue);
    });
  });

  group('Session spam guard', () {
    test('card state avoids session spam', () {
      AhaMomentSession.markShown();
      expect(
        AhaMomentGates.shouldShow(candidate: _candidate(), entryCount: 3),
        isFalse,
      );
    });
  });

  group('Analytics privacy', () {
    test('analytics payload contains no private content', () {
      const privatePhrase = 'Call dentist about crown follow-up';
      engine.evaluate(
        records: [
          _rec(id: 'e1', daysAgo: 2, fear: privatePhrase),
          _rec(id: 'e2', daysAgo: 0, fear: privatePhrase),
        ],
        entryCount: 2,
        trackAnalytics: true,
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.ahaMomentSeen,
        cardType: AhaMomentCardType.id,
        entryCount: 2,
        memoryScope: MemoryScope.automatic.id,
        priorityBand: 'normal',
        authorityState: 'current',
        source: 'test',
      );

      final payloads = _events
          .map((e) => '${e.name} ${e.properties}')
          .join('\n');
      expect(payloads.contains(privatePhrase), isFalse);
      for (final event in _events) {
        expect(
          event.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
      }
    });
  });

  group('Stronger card detection', () {
    test('thread return evidence counts as stronger card', () {
      final records = _relatedRecords();
      expect(
        const ThreadReturnEvidenceEngine()
            .build(records, now: _now, entryCount: 3)
            .hasEvidence,
        isTrue,
      );
      expect(
        AhaMomentEngine.hasStrongerMemoryCard(
          records: records,
          entryCount: 3,
          now: _now,
        ),
        isTrue,
      );
    });

    testWidgets('no aha card when thread return card would render', (
      tester,
    ) async {
      final evidence = const ThreadReturnEvidenceEngine().build(
        _relatedRecords(),
        now: _now,
        entryCount: 3,
      );
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
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
      expect(
        engine.evaluate(
          records: _relatedRecords(),
          entryCount: 3,
          hasStrongerMemoryCardVisible: true,
          trackAnalytics: false,
        ),
        isNull,
      );
    });
  });
}
