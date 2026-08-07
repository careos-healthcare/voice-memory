import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/pro_retention_check.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:voicememory_mobile/config/creator_demo_mode.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/features/referral/referral_invite_after_value.dart';
import 'package:voicememory_mobile/features/review/review_prompt_after_value.dart';
import 'package:voicememory_mobile/features/share/archive_belief_share_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'helpers/test_sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

/// Prefs that fail loudly if the real archive store is ever touched.
class _ThrowingPrefs extends MobilePrefsStore {
  _ThrowingPrefs() : super(file: File('test/tmp/creator_demo/unused.json'));

  @override
  Future<Map<String, dynamic>?> readMap(String key) async =>
      throw StateError('real archive store must not be read in demo mode');

  @override
  Future<Map<String, dynamic>> updateMap(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>? current) transform,
  ) async =>
      throw StateError('real archive store must not be written in demo mode');
}

void main() {
  setUp(() {
    CreatorDemoMode.debugForceEnabledForTest = false;
    ProductAnalytics.demoSuppressedCount = 0;
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((event, properties) {});
    ReferralInviteAfterValue.resetSessionForTest();
    ReviewPromptAfterValue.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
  });

  tearDown(() {
    CreatorDemoMode.debugForceEnabledForTest = false;
    ProductAnalytics.demoSuppressedCount = 0;
    ActivationFunnelAnalytics.resetForTest();
    ReferralInviteAfterValue.resetSessionForTest();
    ReviewPromptAfterValue.resetSessionForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
    ValueMomentPaywallTrigger.resetSessionForTest();
  });

  group('Gating', () {
    test('demo mode is off by default', () {
      expect(CreatorDemoMode.enabled, isFalse);
      expect(CreatorDemoMode.isActive, isFalse);
    });

    test('only the dart define (or the test-only override) enables it', () {
      // `enabled` is a compile-time constant from the dart define with a
      // false default — there is no runtime toggle, setting, or URL.
      expect(CreatorDemoMode.enabled, isFalse);
      CreatorDemoMode.debugForceEnabledForTest = true;
      expect(CreatorDemoMode.isActive, isTrue);
      CreatorDemoMode.debugForceEnabledForTest = false;
      expect(CreatorDemoMode.isActive, isFalse);
    });
  });

  group('Real archive isolation', () {
    test('check-in store is never read or written in demo mode', () async {
      CreatorDemoMode.debugForceEnabledForTest = true;
      final store = PressureCheckInStore.forPrefs(_ThrowingPrefs());

      // Reads come from demo content only.
      final records = await store.loadAll();
      expect(records, isNotEmpty);
      expect(
        records.every((r) => r.entryId.startsWith('creator_demo_')),
        isTrue,
      );

      // Writes never reach the real store (throwing prefs would fail).
      await store.save(CreatorDemoMode.demoCheckIns().first);
      await store.addContextTag(entryId: 'creator_demo_x', contextId: 'work');
    });

    test(
      'check-in store still uses real prefs when demo mode is off',
      () async {
        final store = PressureCheckInStore.forPrefs(_ThrowingPrefs());
        // Off: the real store is read — our throwing prefs prove the path.
        await expectLater(store.loadAll(), throwsStateError);
      },
    );

    test('journal store is never read or written in demo mode', () async {
      CreatorDemoMode.debugForceEnabledForTest = true;
      final dir = Directory.systemTemp.createTempSync('creator_demo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/journal.json')
        ..writeAsStringSync('not valid json — would throw if parsed');
      final store = JournalStore(file: file);

      // Reads come from demo content only — the poisoned file is untouched.
      final entries = store.loadAllSync();
      expect(entries, hasLength(3));
      expect(entries.every((e) => e.id.startsWith('creator_demo_')), isTrue);

      // Writes never touch the real file.
      await store.save(CreatorDemoMode.demoJournalEntries().first);
      await store.delete('creator_demo_j1');
      expect(file.readAsStringSync(), 'not valid json — would throw if parsed');
    });

    test('sync makes no backend call in demo mode', () async {
      CreatorDemoMode.debugForceEnabledForTest = true;
      final dir = Directory.systemTemp.createTempSync('creator_demo_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      // A poisoned journal file proves sync never even reads the queue.
      final journal = JournalStore(
        file: File('${dir.path}/journal.json')..writeAsStringSync('broken'),
      );
      final prefs = MobilePrefsStore(file: File('${dir.path}/prefs.json'));
      final sync = createTestSyncService(
        api: ApiClient(baseUrl: ''),
        journal: journal,
        prefs: prefs,
      );

      final result = await sync.syncNow();
      expect(result.cloudSyncSucceeded, isFalse);
      expect(result.pushed, 0);
      expect(result.pulled, 0);
    });

    test('production analytics are suppressed and demo-marked', () async {
      CreatorDemoMode.debugForceEnabledForTest = true;
      await ProductAnalytics.track('demo_event', parameters: {'k': 'v'});
      await ProductAnalytics.trackStrings('demo_event_two');
      expect(ProductAnalytics.demoSuppressedCount, 2);
    });
  });

  group('Demo value journey', () {
    test('demo records trip every value engine in the journey', () {
      final records = CreatorDemoMode.demoCheckIns();
      expect(
        const ThreadReturnEvidenceEngine().build(records).hasEvidence,
        isTrue,
        reason: 'thread return evidence must exist',
      );
      expect(
        const WeeklyThreadReviewEngine().build(records).hasReview,
        isTrue,
        reason: 'weekly review must exist',
      );
      expect(
        const BeliefDistanceEngine().build(records).hasBelief,
        isTrue,
        reason: 'belief distance must exist',
      );
    });

    testWidgets('safe demo cards render the full value journey', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: CreatorDemoMode.demoCheckIns(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_thread_review_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('belief_distance_card')), findsOneWidget);
      // Privacy-safe share card appears after the passive value moments.
      expect(
        find.byKey(const Key('archive_belief_share_card')),
        findsOneWidget,
      );
      // Paywall bridge for free users below the value evidence.
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsOneWidget);
    });
  });

  group('Safe demo content', () {
    List<String> allDemoText() {
      final records = CreatorDemoMode.demoCheckIns();
      final entries = CreatorDemoMode.demoJournalEntries();
      return [
        CreatorDemoMode.demoLineFirstRecording,
        CreatorDemoMode.demoLineReturnedThought,
        CreatorDemoMode.demoLineWeeklyReview,
        CreatorDemoMode.demoLineShareCard,
        for (final r in records) ...[
          r.entryId,
          r.optionId,
          ...r.contextIds,
          r.fear ?? '',
          r.stopCostNote ?? '',
          r.transcript,
        ],
        for (final e in entries) ...[
          e.id,
          e.transcript,
          e.reflection.mood,
          e.reflection.exactLanguagePattern,
          e.reflection.concreteObservation,
          e.reflection.repeatedSignal,
          ...e.reflection.recurringThemes,
        ],
      ];
    }

    test('expected safe demo lines are exact', () {
      expect(
        CreatorDemoMode.demoLineFirstRecording,
        'I keep coming back to the same work decision.',
      );
      expect(
        CreatorDemoMode.demoLineReturnedThought,
        'I noticed this thought returned again.',
      );
      expect(
        CreatorDemoMode.demoLineWeeklyReview,
        'This week, one thread came back and one felt quieter.',
      );
      expect(
        CreatorDemoMode.demoLineShareCard,
        'My archive noticed something I keep returning to.',
      );
    });

    test('no private content categories and no real user ids', () {
      final text = allDemoText().join(' ').toLowerCase();
      // No health, trauma, relationship names, finances, or private details.
      for (final banned in const [
        'health',
        'doctor',
        'partner',
        'wife',
        'husband',
        'mum',
        'dad',
        'money',
        'salary',
        'bank',
        '@',
        'http',
      ]) {
        expect(
          text,
          isNot(contains(banned)),
          reason: 'demo content must not contain "$banned"',
        );
      }
      // Every demo id is clearly demo-marked — no real user/entry ids.
      final records = CreatorDemoMode.demoCheckIns();
      final entries = CreatorDemoMode.demoJournalEntries();
      expect(
        records.every((r) => r.entryId.startsWith('creator_demo_')),
        isTrue,
      );
      expect(entries.every((e) => e.id.startsWith('creator_demo_')), isTrue);
    });

    test('no VoiceMemory and no banned words in demo content', () {
      final text = allDemoText().join(' ').toLowerCase();
      expect(text, isNot(contains('voicememory')));
      expect(text, isNot(contains('voice memory')));
      for (final banned in const [
        'therapy',
        'treatment',
        'diagnose',
        'definitely',
        'proves',
        'always',
        'never',
        'trauma',
        'abuse',
        'debt',
        'medical',
        'medication',
      ]) {
        expect(
          text,
          isNot(matches(RegExp('\\b$banned'))),
          reason: 'demo content must not contain "$banned"',
        );
      }
    });
  });
}
