import 'dart:io';

import 'package:archiveme_mobile/features/memory/archive_evidence_policy.dart';
import 'package:archiveme_mobile/features/memory/archive_evidence_record.dart';
import 'package:archiveme_mobile/features/memory/archive_evidence_type.dart';
import 'package:archiveme_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:archiveme_mobile/features/memory/keep_exact_details.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_frame.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_influence_level.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/treat_as_new.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory/keep_exact_details_control.dart';
import 'package:archiveme_mobile/widgets/memory/memory_authority_frame_card.dart';
import 'package:archiveme_mobile/widgets/memory/memory_evidence_inspect_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _framingEngine = MemoryAuthorityFramingEngine();

final DateTime _base = DateTime(2026, 6, 9, 12);

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const String _privateNote = 'I keep circling one hard work decision';

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String optionId = 'could_not_stop',
  String? fear,
  bool treatAsNew = false,
  bool connectionApproved = false,
  bool keepExactDetails = false,
  int hoursAgo = 1,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: hoursAgo)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
  connectionApproved: connectionApproved,
  keepExactDetails: keepExactDetails,
);

/// Engine-grade evidence: a work thread with repeated language across days.
List<PressureCheckInRecord> _evidenceRecords() => [
  _rec(id: 'e1', daysAgo: 6, fear: _privateNote),
  _rec(id: 'e2', daysAgo: 3, fear: 'One hard work decision came back'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Circling one hard work decision'),
];

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 4,
  recurringThemes: ['work'],
  exactLanguagePattern: 'I need quiet',
  concreteObservation: 'You asked for quiet time.',
  repeatedSignal: 'Quiet mentioned twice.',
);

JournalEntry _entry({
  required String id,
  String transcript = 'Exact project context: ship build 42 by Friday',
  bool keepExactDetails = false,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 6, 9),
  transcript: transcript,
  durationSeconds: 10,
  reflection: _reflection(),
  keepExactDetails: keepExactDetails,
);

ArchiveEvidenceRecord _evidence(
  ArchiveEvidenceType type, {
  String id = 'x1',
  int daysAgo = 1,
}) => ArchiveEvidenceRecord(
  entryId: id,
  type: type,
  createdAt: _base.subtract(Duration(days: daysAgo)),
);

/// Every user-facing copy constant introduced or touched by the memory
/// surfaces, so the sweeps below cover all of it.
List<String> _memoryConsumerCopy() => [
  KeepExactDetails.controlLabel,
  KeepExactDetails.helper,
  KeepExactDetails.savedReceipt,
  MemoryEvidenceInspectCopy.actionLabel,
  MemoryEvidenceInspectCopy.sheetTitle,
  MemoryEvidenceInspectCopy.confirmedMarker,
  MemoryEvidenceInspectCopy.keepConnectedLabel,
  MemoryEvidenceInspectCopy.keepConnectedDone,
  MemoryEvidenceInspectCopy.notRelatedLabel,
  MemoryEvidenceInspectCopy.notRelatedDone,
  MemoryEvidenceInspectCopy.futureFreshLabel,
  MemoryEvidenceInspectCopy.futureFreshDone,
  MemoryEvidenceInspectCopy.emptyLine,
  MemoryEvidenceInspectCopy.footer,
  TreatAsNew.controlLabel,
  TreatAsNew.helper,
  TreatAsNew.expandedHelper,
  TreatAsNew.postSaveTitle,
  TreatAsNew.postSaveBody,
  MemoryControlCopy.notRelatedLabel,
  MemoryControlCopy.notRelatedThanks,
  MemoryControlCopy.whyBodyThreadReturn,
  MemoryControlCopy.whyBodyWeeklyReview,
  MemoryControlCopy.whyBodyBeliefDistance,
  MemoryControlCopy.whyFooter,
  MemoryAuthorityCopy.blockedBody,
  MemoryAuthorityCopy.suppressBody,
  MemoryAuthorityCopy.backgroundBody,
  MemoryAuthorityCopy.compareBody,
  MemoryAuthorityCopy.highAuthorityBody,
  MemoryAuthorityCopy.sheetFooter,
  for (final type in ArchiveEvidenceType.values) type.label,
  for (final state in MemoryAuthorityState.values) state.label,
];

void main() {
  setUp(() {
    MemoryScopePolicy.resetForTest();
    ArchiveRetrievalPolicy.resetSessionForTest();
    MemoryAuthorityFrameLog.resetForTest();
    MemoryControlStore.resetSessionForTest();
    MemoryConnectionRules.resetForTest();
    TreatAsNew.resetSessionForTest();
    KeepExactDetails.resetSessionForTest();
    ActivationFunnelAnalytics.resetForTest();
    _events.clear();
    ActivationFunnelAnalytics.captureForTest(
      (name, properties) => _events.add(_Event(name, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('A. Vague summary protection', () {
    test('raw entries are never replaced by summaries', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_regression_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final store = await JournalStore.open('${tempDir.path}/entries.json');

      const exactText =
          'Exact project context: ship build 42 by Friday, ping Dana first';
      await store.save(_entry(id: 'raw1', transcript: exactText));

      // Run the full memory pipeline over related records — derived
      // layers may produce frames, patterns, and evidence views.
      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      ArchiveEvidencePolicy.buildPattern(
        ArchiveEvidencePolicy.describe(_evidenceRecords()),
      );

      // The raw entry on disk is byte-identical: no summary replaced it.
      final reloaded = await store.getById('raw1');
      expect(reloaded, isNotNull);
      expect(reloaded!.transcript, exactText);
      expect(
        reloaded.reflection.concreteObservation,
        'You asked for quiet time.',
      );
    });

    test('evidence records separate fact, pattern, and interpretation', () {
      final described = ArchiveEvidencePolicy.describe([
        _rec(id: 'f1', daysAgo: 1, fear: _privateNote),
        _rec(id: 'm1', daysAgo: 2, keepExactDetails: true),
        _rec(id: 'n1', daysAgo: 3, treatAsNew: true),
      ]);
      expect(described[0].type, ArchiveEvidenceType.fact);
      expect(described[1].type, ArchiveEvidenceType.userMarkedDetail);
      expect(described[2].type, ArchiveEvidenceType.fresh);

      // Typed ids are stable and analytics-safe.
      expect(ArchiveEvidenceType.fact.id, 'fact');
      expect(ArchiveEvidenceType.pattern.id, 'pattern');
      expect(ArchiveEvidenceType.interpretation.id, 'interpretation');
      expect(ArchiveEvidenceType.userMarkedDetail.id, 'user_marked_detail');
      expect(ArchiveEvidenceType.thread.id, 'thread');
      expect(ArchiveEvidenceType.fresh.id, 'fresh');
    });

    test('evidence records carry references only — never raw text', () {
      final described = ArchiveEvidencePolicy.describe(_evidenceRecords());
      for (final record in described) {
        expect(record.entryId, isNotEmpty);
        // The only strings on an evidence record are the entry-id
        // reference and supporting ids — note text has no field to
        // live in.
        expect(record.entryId.contains(' '), isFalse);
        for (final id in record.supportingEntryIds) {
          expect(id.contains(' '), isFalse);
        }
      }
    });

    test('generated interpretation cannot become evidence source', () {
      final interpretation = _evidence(
        ArchiveEvidenceType.interpretation,
        id: 'i1',
      );
      expect(interpretation.canSupportClaims, isFalse);
      expect(ArchiveEvidencePolicy.asSourceEvidence(interpretation), isNull);

      final sources = ArchiveEvidencePolicy.sourceEvidence([
        interpretation,
        _evidence(ArchiveEvidenceType.fact, id: 'f1'),
        _evidence(ArchiveEvidenceType.fresh, id: 'n1'),
      ]);
      expect(sources.length, 1);
      expect(sources.single.type, ArchiveEvidenceType.fact);

      // A pattern propped up by interpretation is rejected outright.
      expect(
        ArchiveEvidencePolicy.buildPattern([
          _evidence(ArchiveEvidenceType.fact, id: 'f1'),
          _evidence(ArchiveEvidenceType.fact, id: 'f2', daysAgo: 2),
          interpretation,
        ]),
        isNull,
      );
    });

    test('pattern references supporting evidence ids internally', () {
      final pattern = ArchiveEvidencePolicy.buildPattern([
        _evidence(ArchiveEvidenceType.fact, id: 'f1'),
        _evidence(ArchiveEvidenceType.fact, id: 'f2', daysAgo: 2),
        _evidence(ArchiveEvidenceType.fact, id: 'f3', daysAgo: 3),
      ]);
      expect(pattern, isNotNull);
      expect(pattern!.type, ArchiveEvidenceType.pattern);
      expect(pattern.supportingEvidenceCount, 3);
      expect(pattern.supportingEntryIds, containsAll(['f1', 'f2', 'f3']));
    });
  });

  group('B. Keep exact details', () {
    test('exact-detail flag persists across json round trips', () {
      final entry = _entry(id: 'k1', keepExactDetails: true);
      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored.keepExactDetails, isTrue);
      expect(restored.transcript, entry.transcript);

      final record = _rec(id: 'k1', daysAgo: 0, keepExactDetails: true);
      final restoredRecord = PressureCheckInRecord.fromJson(record.toJson());
      expect(restoredRecord.keepExactDetails, isTrue);

      // Unflagged stays unflagged.
      expect(
        JournalEntry.fromJson(_entry(id: 'k2').toJson()).keepExactDetails,
        isFalse,
      );
    });

    test('flag is applied at save time and persists on disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_regression_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final store = await JournalStore.open(
        '${tempDir.path}/entries.json',
        encryptAtRest: false,
      );

      KeepExactDetails.selectedForNextSave = true;
      await store.save(_entry(id: 'k1'));

      // Selection is consumed (per-entry only) and the receipt signal set.
      expect(KeepExactDetails.selectedForNextSave, isFalse);
      expect(KeepExactDetails.lastSaveKeptExact, isTrue);

      final reopened = await JournalStore.open(
        '${tempDir.path}/entries.json',
        encryptAtRest: false,
      );
      final reloaded = await reopened.getById('k1');
      expect(reloaded!.keepExactDetails, isTrue);
      // Stored normally: text untouched, still loadable/searchable.
      expect(reloaded.transcript, _entry(id: 'k1').transcript);

      // The next save does not inherit the flag.
      await store.save(_entry(id: 'k2'));
      expect((await store.getById('k2'))!.keepExactDetails, isFalse);
    });

    test('exact-detail entries are not folded into generic patterns', () {
      // Policy level: user-marked details never join a pattern fold.
      final pattern = ArchiveEvidencePolicy.buildPattern([
        _evidence(ArchiveEvidenceType.fact, id: 'f1'),
        _evidence(ArchiveEvidenceType.fact, id: 'f2', daysAgo: 2),
        _evidence(ArchiveEvidenceType.userMarkedDetail, id: 'exact1'),
      ]);
      expect(pattern, isNotNull);
      expect(pattern!.supportingEntryIds, isNot(contains('exact1')));

      // Engine level: a near-identical exact-detail record is not
      // merged into a duplicate group — it stays an individual exact
      // evidence item among the claim candidates.
      final base = _evidenceRecords();
      final dup = _rec(
        id: 'e3_dup',
        daysAgo: 0,
        hoursAgo: 2,
        fear: 'Circling one hard work decision',
      );
      final folded = _framingEngine.frame(
        [...base, dup],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      final exactDup = _rec(
        id: 'e3_exact',
        daysAgo: 0,
        hoursAgo: 2,
        fear: 'Circling one hard work decision',
        keepExactDetails: true,
      );
      MemoryAuthorityFrameLog.resetForTest();
      final kept = _framingEngine.frame(
        [...base, exactDup],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(kept.candidates.length, greaterThan(folded.candidates.length));
      expect(kept.candidates.any((r) => r.entryId == 'e3_exact'), isTrue);
    });

    testWidgets('control uses the exact agreed copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: KeepExactDetailsControl()),
        ),
      );
      expect(find.text('Keep exact details'), findsOneWidget);
      expect(
        find.text(
          'ArchiveMe will keep this as evidence, not fold it into a '
          'general pattern.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('keep_exact_details_control')));
      await tester.pump();
      expect(KeepExactDetails.selectedForNextSave, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ExactDetailsSavedReceipt()),
        ),
      );
      expect(find.text('Saved as exact evidence'), findsOneWidget);
    });
  });

  group('C. Inspect/edit memory connections', () {
    Future<void> pumpSheet(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: MemoryEvidenceInspectSheet(
              cardType: MemoryCardType.threadReturn,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('memory card shows Show evidence action', (tester) async {
      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: MemoryAuthorityFrameCard(
              cardType: MemoryCardType.threadReturn,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('memory_show_evidence_action_thread_return')),
        findsOneWidget,
      );
      expect(find.text('Show evidence'), findsOneWidget);
    });

    testWidgets('evidence list shows safe metadata only', (tester) async {
      _framingEngine.frame(
        [
          ..._evidenceRecords(),
          _rec(
            id: 'c1',
            daysAgo: 2,
            fear: 'One hard work decision again',
            connectionApproved: true,
          ),
        ],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      await pumpSheet(tester);

      expect(find.text('Evidence behind this card'), findsOneWidget);
      expect(find.byKey(const Key('memory_evidence_item_0')), findsOneWidget);
      // Confirmed evidence is marked.
      expect(find.textContaining('You confirmed this'), findsOneWidget);

      // Privacy: relative buckets, types, and authority labels only —
      // no note text, dates, or entry ids anywhere on the sheet.
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('memory_evidence_inspect_sheet')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts.contains('work decision'), isFalse);
      expect(texts.contains('e1'), isFalse);
      expect(texts.contains('c1'), isFalse);
      expect(RegExp(r'\d{4}').hasMatch(texts), isFalse);
    });

    testWidgets('Keep connected confirms connection', (tester) async {
      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('memory_keep_connected_action')));
      await tester.pump();

      expect(MemoryConnectionRules.isConfirmed('thread_return'), isTrue);
      expect(
        find.byKey(const Key('memory_evidence_done_line')),
        findsOneWidget,
      );

      // The next framing pass treats the connection as user-confirmed —
      // the only path to high authority.
      MemoryAuthorityFrameLog.resetForTest();
      final framing = _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(framing.frame.authorityState, MemoryAuthorityState.confirmed);
      expect(framing.frame.influenceLevel, MemoryInfluenceLevel.highAuthority);
    });

    testWidgets('Not related suppresses the connection', (tester) async {
      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      await pumpSheet(tester);
      await tester.tap(
        find.byKey(const Key('memory_inspect_not_related_action')),
      );
      await tester.pump();

      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
    });

    testWidgets('Treat future entries as new creates a future-fresh rule', (
      tester,
    ) async {
      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('memory_future_fresh_action')));
      await tester.pump();

      expect(MemoryConnectionRules.isFutureFresh('thread_return'), isTrue);

      // Future framing passes on this card no longer auto-connect.
      MemoryAuthorityFrameLog.resetForTest();
      final framing = _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(framing.allowsConnectionClaims, isFalse);
      expect(framing.frame.influenceLevel, MemoryInfluenceLevel.suppress);
      expect(framing.candidates, isEmpty);

      // Other cards are untouched.
      expect(MemoryConnectionRules.isFutureFresh('weekly_review'), isFalse);
    });

    test('connection rules persist via prefs as card-type ids only', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_regression_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = MemoryConnectionRuleStore.forPrefs(prefs);

      MemoryConnectionRules.keepConnected(MemoryCardType.threadReturn);
      MemoryConnectionRules.treatFutureAsNew(MemoryCardType.beliefDistance);
      await store.saveCurrent();

      MemoryConnectionRules.resetForTest();
      expect(MemoryConnectionRules.isConfirmed('thread_return'), isFalse);

      await store.ensureLoaded();
      expect(MemoryConnectionRules.isConfirmed('thread_return'), isTrue);
      expect(MemoryConnectionRules.isFutureFresh('belief_distance'), isTrue);

      // The stored payload is stable ids only — never text or entry ids.
      final raw = await prefs.readMap('memoryConnectionRules');
      expect(raw, isNotNull);
      for (final list in raw!.values) {
        for (final value in list as List<dynamic>) {
          expect(RegExp(r'^[a-z0-9_]+$').hasMatch(value as String), isTrue);
        }
      }
    });
  });

  group('D. Identity-summary protection', () {
    test('identity-style claims are not present in memory copy', () {
      for (final copy in _memoryConsumerCopy()) {
        expect(
          ArchiveEvidencePolicy.violatesIdentityFraming(copy),
          isFalse,
          reason: 'Identity-style claim in consumer copy: "$copy"',
        );
      }
    });

    test('guard catches the banned identity claim shapes', () {
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming('You are anxious.'),
        isTrue,
      );
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming('You always avoid.'),
        isTrue,
      );
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming(
          'Your archive believes you are stuck.',
        ),
        isTrue,
      );
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming('This proves it.'),
        isTrue,
      );
      // Evidence framing passes.
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming(
          'Your archive has repeated evidence around this.',
        ),
        isFalse,
      );
      expect(
        ArchiveEvidencePolicy.violatesIdentityFraming('This may be stale.'),
        isFalse,
      );
    });

    test('no VoiceMemory in consumer-facing memory copy', () {
      for (final copy in _memoryConsumerCopy()) {
        expect(
          copy.contains('VoiceMemory'),
          isFalse,
          reason: 'VoiceMemory leaked into: "$copy"',
        );
      }
    });
  });

  group('Privacy — analytics', () {
    testWidgets('no private content in analytics from any new surface', (
      tester,
    ) async {
      // Exercise every new code path that emits analytics. The save-time
      // path runs through applyToNewEntry directly (synchronous) — real
      // file IO does not resolve inside the widget-test zone.
      KeepExactDetails.selectedForNextSave = true;
      KeepExactDetails.applyToNewEntry(
        _entry(id: 'p1', transcript: _privateNote),
        entryCount: 1,
      );

      _framingEngine.frame(
        _evidenceRecords(),
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: MemoryEvidenceInspectSheet(
              cardType: MemoryCardType.threadReturn,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory_keep_connected_action')));
      await tester.pump();

      MemoryConnectionRules.treatFutureAsNew(MemoryCardType.weeklyReview);

      expect(_events, isNotEmpty);
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final event in _events) {
        expect(
          safeValue.hasMatch(event.name),
          isTrue,
          reason: 'unsafe event name: ${event.name}',
        );
        for (final entry in event.properties.entries) {
          expect(
            ActivationFunnelAnalytics.allowedPropertyKeys.contains(entry.key),
            isTrue,
            reason: 'unexpected property key: ${entry.key}',
          );
          final value = entry.value;
          if (value is String) {
            expect(
              safeValue.hasMatch(value),
              isTrue,
              reason: 'unsafe value for ${entry.key}: $value',
            );
            expect(value.contains('decision'), isFalse);
          }
        }
      }
      final payload = _events.map((e) => '${e.name} ${e.properties}').join(' ');
      expect(payload.contains('work decision'), isFalse);
      expect(payload.contains('ship build'), isFalse);
      expect(payload.contains('VoiceMemory'), isFalse);
    });
  });
}