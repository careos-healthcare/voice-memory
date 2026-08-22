import 'dart:io';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_store.dart';
import 'package:archiveme_mobile/features/memory/treat_as_new.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/features/referral/referral_invite_after_value.dart';
import 'package:archiveme_mobile/features/share/archive_belief_share_card.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory/memory_scope_control.dart';
import 'package:archiveme_mobile/widgets/memory/memory_scope_settings_section.dart';
import 'package:archiveme_mobile/widgets/memory/why_memory_appeared_sheet.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

const _threadEngine = ThreadReturnEvidenceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();
const _beliefEngine = BeliefDistanceEngine();
const _bridgeTrigger = ValueMomentPaywallTrigger();

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

List<_Event> _eventsNamed(String name) =>
    _events.where((e) => e.name == name).toList();

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 11, 9),
  transcript:
      transcript ?? 'A long enough transcript to count as a saved reflection.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: 'signal',
  ),
);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  bool treatAsNew = false,
  bool connectionApproved = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
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
    fear: 'I keep circling the same work decision',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'The same work decision came back today',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling the same work decision tonight',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
];

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('vm_memory_scope_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

MobilePrefsStore _filePrefs(Directory dir) {
  final file = File('${dir.path}/prefs.json');
  if (!file.existsSync()) file.writeAsStringSync('{}');
  return MobilePrefsStore(file: file);
}

MemoryScopeStore _fileBackedScopeStore(Directory dir) =>
    MemoryScopeStore.forPrefs(_filePrefs(dir));

/// In-memory scope store for widget tests — no file IO inside the
/// fake-async test zone.
class _InMemoryScopeStore extends MemoryScopeStore {
  _InMemoryScopeStore()
    : super(MobilePrefsStore(file: File('test/tmp/unused_scope.json')));

  MemoryScope? stored;

  @override
  Future<MemoryScope> load() async => stored ?? MemoryScope.automatic;

  @override
  Future<void> save(MemoryScope scope) async {
    stored = scope;
    MemoryScopePolicy.scope = scope;
  }

  @override
  Future<MemoryScope> ensureLoaded() async {
    final scope = await load();
    MemoryScopePolicy.scope = scope;
    return scope;
  }
}

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 8000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: false),
        records: records,
        microExperimentStore: MemoryExperimentStore(),
        returnTriggerStore: MemoryReturnTriggerStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    TreatAsNew.resetSessionForTest();
    MemoryControlStore.resetSessionForTest();
    MemoryScopePolicy.resetForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ReferralInviteAfterValue.resetSessionForTest();
  });

  tearDown(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    TreatAsNew.resetSessionForTest();
    MemoryControlStore.resetSessionForTest();
    MemoryScopePolicy.resetForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ReferralInviteAfterValue.resetSessionForTest();
  });

  group('Persistent setting', () {
    test('default memory scope is automatic', () async {
      final store = _fileBackedScopeStore(_tempDir());
      expect(await store.load(), MemoryScope.automatic);
      expect(await store.ensureLoaded(), MemoryScope.automatic);
      expect(MemoryScopePolicy.scope, MemoryScope.automatic);
    });

    test('selecting memory off persists across store reload', () async {
      final dir = _tempDir();
      await _fileBackedScopeStore(dir).save(MemoryScope.off);
      expect(MemoryScopePolicy.scope, MemoryScope.off);

      // Simulated app restart: fresh policy + fresh store on the same file.
      MemoryScopePolicy.resetForTest();
      final reloaded = _fileBackedScopeStore(dir);
      expect(await reloaded.load(), MemoryScope.off);
      expect(await reloaded.ensureLoaded(), MemoryScope.off);
      expect(MemoryScopePolicy.scope, MemoryScope.off);
    });

    test('memory off does not auto-re-enable across repeated loads', () async {
      final dir = _tempDir();
      await _fileBackedScopeStore(dir).save(MemoryScope.off);

      for (var restart = 0; restart < 3; restart++) {
        MemoryScopePolicy.resetForTest();
        expect(
          await _fileBackedScopeStore(dir).ensureLoaded(),
          MemoryScope.off,
        );
        expect(MemoryScopePolicy.scope, MemoryScope.off);
      }
    });

    test('ask and threadOnly persist and are respected', () async {
      final dir = _tempDir();
      await _fileBackedScopeStore(dir).save(MemoryScope.ask);
      expect(await _fileBackedScopeStore(dir).load(), MemoryScope.ask);

      await _fileBackedScopeStore(dir).save(MemoryScope.threadOnly);
      expect(await _fileBackedScopeStore(dir).load(), MemoryScope.threadOnly);
    });
  });

  group('Memory off saves as fresh', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
    });

    tearDown(() => sandbox.dispose());

    test('journal entries saved while off carry fresh metadata', () async {
      MemoryScopePolicy.scope = MemoryScope.off;
      final store = AppServices.instance.journalStore;
      await store.save(_entry('off1', transcript: 'Untouched words.'));

      final saved = (await store.loadAll()).singleWhere((e) => e.id == 'off1');
      expect(saved.treatAsNew, isTrue);
      expect(saved.transcript, 'Untouched words.');
    });

    test('fresh entries still appear in the archive', () async {
      MemoryScopePolicy.scope = MemoryScope.off;
      final store = AppServices.instance.journalStore;
      await store.save(_entry('off2'));
      await store.save(_entry('off3'));

      final all = await store.loadAll();
      expect(all.map((e) => e.id), containsAll(['off2', 'off3']));
    });

    test('new check-in records saved while off are fresh', () async {
      MemoryScopePolicy.scope = MemoryScope.off;
      final store = PressureCheckInStore.forPrefs(_filePrefs(_tempDir()));
      await store.save(_rec(id: 'c1', daysAgo: 0, fear: 'a moment'));

      final all = await store.loadAll();
      expect(all.single.treatAsNew, isTrue);
      expect(all.single.fear, 'a moment');
    });
  });

  group('Memory off suppression', () {
    test('suppresses thread return evidence', () {
      final records = _evidenceRecords();
      expect(_threadEngine.build(records).hasEvidence, isTrue);

      MemoryScopePolicy.scope = MemoryScope.off;
      expect(_threadEngine.build(records).hasEvidence, isFalse);
    });

    test('suppresses belief distance', () {
      final records = _evidenceRecords();
      expect(_beliefEngine.build(records).hasBelief, isTrue);

      MemoryScopePolicy.scope = MemoryScope.off;
      expect(_beliefEngine.build(records).hasBelief, isFalse);
    });

    test('suppresses weekly returned/faded/changed claims', () {
      final records = _evidenceRecords();
      final before = _weeklyEngine.build(records);
      expect(before.hasReview, isTrue);

      MemoryScopePolicy.scope = MemoryScope.off;
      final after = _weeklyEngine.build(records);
      expect(after.hasReview, isFalse);
      expect(after.returnedLine, isEmpty);
      expect(after.fadedLine, isEmpty);
      expect(after.changedLine, isEmpty);
    });

    test('suppresses the memory-based Pro continuity bridge', () {
      final records = _evidenceRecords();
      expect(_bridgeTrigger.build(records, isPro: false).show, isTrue);

      MemoryScopePolicy.scope = MemoryScope.off;
      expect(_bridgeTrigger.build(records, isPro: false).show, isFalse);
    });

    test('suppresses the archive belief share prompt', () {
      ArchiveBeliefShareCard.recordValueFeedback(
        cardType: 'thread_return_evidence',
        useful: true,
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: true,
        ),
        isTrue,
      );

      MemoryScopePolicy.scope = MemoryScope.off;
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: true,
        ),
        isFalse,
      );
    });

    test('suppresses the referral proof moment', () {
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          hasConnectedProofCounter: true,
        ),
        isTrue,
      );

      MemoryScopePolicy.scope = MemoryScope.off;
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          hasConnectedProofCounter: true,
        ),
        isFalse,
      );
    });

    testWidgets('shows the calm notice on the insights screen', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.off;
      await _pumpInsights(tester, records: _evidenceRecords());

      expect(find.byKey(const Key('memory_off_notice')), findsOneWidget);
      expect(find.text(MemoryScopeCopy.offNoticeTitle), findsOneWidget);
      expect(find.text(MemoryScopeCopy.offNoticeBody), findsOneWidget);
      expect(find.text(MemoryScopeCopy.offNoticeCta), findsOneWidget);
      // No connection claims anywhere on the screen.
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('belief_distance_card')), findsNothing);
      expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsNothing);
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryOffNoticeSeen),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('record screen shows the off notice for the next entry', (
      tester,
    ) async {
      MemoryScopePolicy.scope = MemoryScope.off;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MemoryScopeControl()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('memory_scope_off_entry_notice')),
        findsOneWidget,
      );
      expect(find.text(MemoryScopeCopy.offEntryTitle), findsOneWidget);
      expect(find.text(MemoryScopeCopy.offEntryBody), findsOneWidget);
      // Nothing here can turn memory back on.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });
  });

  group('Ask mode', () {
    testWidgets('shows the connect prompt before save', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.ask;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MemoryScopeControl(entryCount: 3)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('memory_connect_prompt')), findsOneWidget);
      expect(find.text(MemoryScopeCopy.connectPromptTitle), findsOneWidget);
      expect(find.text(MemoryScopeCopy.connectPromptBody), findsOneWidget);
      expect(find.text(MemoryScopeCopy.connectLabel), findsOneWidget);
      expect(find.text(MemoryScopeCopy.treatAsNewLabel), findsOneWidget);
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryConnectPromptSeen),
        hasLength(1),
      );
    });

    testWidgets('Connect approves the next save', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.ask;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MemoryScopeControl(entryCount: 3)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('memory_connect_button')));
      await tester.pump();
      expect(MemoryScopePolicy.connectApprovedForNextSave, isTrue);
      expect(TreatAsNew.selectedForNextSave, isFalse);
      expect(
        find.byKey(const Key('memory_connect_confirmed_line')),
        findsOneWidget,
      );
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryConnectConfirmed),
        hasLength(1),
      );
    });

    testWidgets('Treat as new marks the next save fresh', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.ask;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MemoryScopeControl(entryCount: 3)),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('memory_prompt_treat_as_new_button')),
      );
      await tester.pump();
      expect(TreatAsNew.selectedForNextSave, isTrue);
      expect(MemoryScopePolicy.connectApprovedForNextSave, isFalse);
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryTreatAsNewSelected),
        hasLength(1),
      );
    });

    test('unapproved entries are treated as fresh by engines', () {
      MemoryScopePolicy.scope = MemoryScope.ask;
      final records = _evidenceRecords();
      expect(_threadEngine.build(records).hasEvidence, isFalse);
      expect(_beliefEngine.build(records).hasBelief, isFalse);
      expect(_weeklyEngine.build(records).hasReview, isFalse);
    });

    test('entries are used after Connect', () {
      MemoryScopePolicy.scope = MemoryScope.ask;
      final approved = _evidenceRecords(connectionApproved: true);
      expect(_threadEngine.build(approved).hasEvidence, isTrue);
    });

    test('Connect stamps the saved journal entry', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_scope_ask_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      MemoryScopePolicy.scope = MemoryScope.ask;
      MemoryScopePolicy.connectApprovedForNextSave = true;

      final store = AppServices.instance.journalStore;
      await store.save(_entry('ask1'));
      final saved = (await store.loadAll()).singleWhere((e) => e.id == 'ask1');
      expect(saved.connectionApproved, isTrue);
      expect(saved.treatAsNew, isFalse);
      // Approval is per-save: the next entry is unapproved again.
      expect(MemoryScopePolicy.connectApprovedForNextSave, isFalse);
    });
  });

  group('Thread-only mode', () {
    test('connects only entries with an explicit shared context', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;
      // Same explicit 'work' context across entries: still connectable.
      expect(_threadEngine.build(_evidenceRecords()).hasEvidence, isTrue);
    });

    test('does not connect from generic similarity alone', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;
      // Same repeated language but each entry carries a different explicit
      // context marker — no shared thread, so no connection claim.
      final records = [
        _rec(
          id: 't1',
          daysAgo: 6,
          contexts: const ['ctx_a'],
          fear: 'I keep circling the same work decision',
        ),
        _rec(
          id: 't2',
          daysAgo: 3,
          contexts: const ['ctx_b'],
          fear: 'The same work decision came back today',
        ),
        _rec(
          id: 't3',
          daysAgo: 0,
          contexts: const ['ctx_c'],
          fear: 'Circling the same work decision tonight',
        ),
      ];
      expect(_threadEngine.build(records).hasEvidence, isFalse);
      expect(_beliefEngine.build(records).hasBelief, isFalse);
      expect(_weeklyEngine.build(records).hasReview, isFalse);
    });

    test('entries without any explicit context stay fresh', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;
      final records = [
        _rec(
          id: 'n1',
          daysAgo: 4,
          contexts: const [],
          fear: 'I keep circling the same work decision',
        ),
        _rec(
          id: 'n2',
          daysAgo: 0,
          contexts: const [],
          fear: 'The same work decision came back today',
        ),
      ];
      expect(MemoryScopePolicy.connectionEligible(records), isEmpty);
    });
  });

  group('Automatic mode', () {
    test('existing connected evidence still works', () {
      final records = _evidenceRecords();
      expect(_threadEngine.build(records).hasEvidence, isTrue);
      expect(_beliefEngine.build(records).hasBelief, isTrue);
      expect(_weeklyEngine.build(records).hasReview, isTrue);
    });

    test('fresh entries are ignored for connection claims', () {
      final records = _evidenceRecords(treatAsNew: true);
      expect(_threadEngine.build(records).hasEvidence, isFalse);
      expect(_beliefEngine.build(records).hasBelief, isFalse);
      expect(_weeklyEngine.build(records).hasReview, isFalse);
    });

    test('Treat this as new writes safe metadata only', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_scope_auto_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      TreatAsNew.selectedForNextSave = true;

      final store = AppServices.instance.journalStore;
      await store.save(_entry('auto1', transcript: 'My exact words.'));
      final saved = (await store.loadAll()).singleWhere((e) => e.id == 'auto1');
      expect(saved.treatAsNew, isTrue);
      expect(saved.transcript, 'My exact words.');
      expect(saved.connectionApproved, isFalse);
    });

    testWidgets('record control shows current mode and the fresh toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: MemoryScopeControl()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('memory_scope_control')), findsOneWidget);
      expect(
        find.text(
          '${MemoryScopeCopy.entryControlTitle}: '
          '${MemoryScope.automatic.label} · '
          '${MemoryScopeCopy.useCurrentSettingLabel}',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('treat_as_new_control')), findsOneWidget);
    });
  });

  group('Session memory controls', () {
    test('Not related suppresses only the specific card for the session', () {
      MemoryControlStore.markNotRelated(MemoryCardType.threadReturn);
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.beliefDistance),
        isFalse,
      );
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.weeklyReview),
        isFalse,
      );

      MemoryControlStore.resetSessionForTest();
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isFalse,
      );
    });

    testWidgets('Why this appeared sheet is high-level only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: WhyMemoryAppearedSheet(cardType: MemoryCardType.threadReturn),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(MemoryControlCopy.whyTitle), findsOneWidget);
      expect(find.text(MemoryControlCopy.whyBodyShared), findsOneWidget);
      expect(find.text(MemoryControlCopy.whyCorrectionFooter), findsOneWidget);
      // No raw notes, snippets, belief phrases, dates, or entry ids.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts, isNot(contains('work decision')));
      expect(texts, isNot(contains('e1')));
      expect(texts, isNot(contains('2026')));
    });
  });

  group('Settings section', () {
    testWidgets('shows all four modes and persists a change', (tester) async {
      final store = _InMemoryScopeStore();
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemoryScopeSettingsSection(store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('memory_scope_settings_section')),
        findsOneWidget,
      );
      expect(find.text(MemoryScopeCopy.settingsTitle), findsOneWidget);
      expect(find.text(MemoryScopeCopy.settingsBody), findsOneWidget);
      for (final scope in MemoryScope.values) {
        expect(find.text(scope.label), findsOneWidget);
        expect(find.text(scope.helper), findsOneWidget);
      }
      expect(
        _eventsNamed(ActivationFunnelAnalytics.memoryScopeSeen),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('memory_scope_option_off')));
      await tester.pumpAndSettle();

      expect(store.stored, MemoryScope.off);
      expect(MemoryScopePolicy.scope, MemoryScope.off);
      final changed = _eventsNamed(
        ActivationFunnelAnalytics.memoryScopeChanged,
      );
      expect(changed, hasLength(1));
      expect(changed.single.properties['memory_scope'], 'off');
    });
  });

  group('Analytics privacy', () {
    testWidgets('payloads carry stable ids and counts only', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.ask;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MemoryScopeControl(entryCount: 4)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory_connect_button')));
      await tester.pump();

      expect(_events, isNotEmpty);
      for (final event in _events) {
        for (final entry in event.properties.entries) {
          expect(
            ActivationFunnelAnalytics.allowedPropertyKeys,
            contains(entry.key),
          );
          final value = entry.value;
          if (entry.key == 'memory_scope') {
            expect(
              ActivationFunnelAnalytics.allowedMemoryScopeValues,
              contains(value),
            );
          }
          if (value is String) {
            expect(RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(value), isTrue);
          }
        }
      }
    });

    test('memory scope ids are fixed and lowercase', () {
      expect(MemoryScope.automatic.id, 'automatic');
      expect(MemoryScope.ask.id, 'ask');
      expect(MemoryScope.threadOnly.id, 'thread_only');
      expect(MemoryScope.off.id, 'off');
    });
  });

  group('Copy guardrails', () {
    const allCopy = <String>[
      MemoryScopeCopy.automaticLabel,
      MemoryScopeCopy.automaticHelper,
      MemoryScopeCopy.askLabel,
      MemoryScopeCopy.askHelper,
      MemoryScopeCopy.threadOnlyLabel,
      MemoryScopeCopy.threadOnlyHelper,
      MemoryScopeCopy.offLabel,
      MemoryScopeCopy.offHelper,
      MemoryScopeCopy.settingsTitle,
      MemoryScopeCopy.settingsBody,
      MemoryScopeCopy.entryControlTitle,
      MemoryScopeCopy.useCurrentSettingLabel,
      MemoryScopeCopy.offEntryTitle,
      MemoryScopeCopy.offEntryBody,
      MemoryScopeCopy.connectPromptTitle,
      MemoryScopeCopy.connectPromptBody,
      MemoryScopeCopy.connectLabel,
      MemoryScopeCopy.treatAsNewLabel,
      MemoryScopeCopy.connectConfirmed,
      MemoryScopeCopy.offNoticeTitle,
      MemoryScopeCopy.offNoticeBody,
      MemoryScopeCopy.offNoticeCta,
    ];

    test('exact spec copy', () {
      expect(MemoryScopeCopy.automaticLabel, 'Automatic when useful');
      expect(
        MemoryScopeCopy.automaticHelper,
        'ArchiveMe can connect entries when there is enough evidence.',
      );
      expect(MemoryScopeCopy.askLabel, 'Ask before connecting');
      expect(
        MemoryScopeCopy.askHelper,
        'ArchiveMe will ask before using a new entry to suggest a '
        'connection.',
      );
      expect(MemoryScopeCopy.threadOnlyLabel, 'Only within chosen threads');
      expect(
        MemoryScopeCopy.threadOnlyHelper,
        'ArchiveMe will not connect unrelated entries automatically.',
      );
      expect(MemoryScopeCopy.offLabel, 'Memory off');
      expect(
        MemoryScopeCopy.offHelper,
        'ArchiveMe will save entries without using them to suggest '
        'connections.',
      );
      expect(
        MemoryScopeCopy.settingsBody,
        'Choose when ArchiveMe connects entries.',
      );
      expect(MemoryScopeCopy.offNoticeTitle, 'Memory is off.');
      expect(
        MemoryScopeCopy.offNoticeBody,
        'Your entries are saved, but ArchiveMe is not connecting them '
        'right now.',
      );
      expect(MemoryScopeCopy.offNoticeCta, 'Change memory setting');
    });

    test('no VoiceMemory in consumer copy', () {
      final flat = allCopy.join(' ').toLowerCase();
      expect(flat, isNot(contains('voicememory')));
      expect(flat, isNot(contains('voice memory')));
    });

    test('banned-word sweep including fear-based terms', () {
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
        'surveillance',
        'spying',
        'tracking',
      ]) {
        expect(
          RegExp('\\b$banned\\b').hasMatch(flat),
          isFalse,
          reason: 'copy may not contain "$banned"',
        );
      }
    });
  });
}