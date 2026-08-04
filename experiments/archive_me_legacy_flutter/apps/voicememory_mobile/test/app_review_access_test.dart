import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_access.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/config/archive_me_demo_state.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_session.dart';
import 'package:voicememory_mobile/features/demo/archive_me_demo_archive.dart';
import 'package:voicememory_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;

  setUp(() async {
    ArchiveAppReviewAccessGate.enabledOverride = true;
    ArchiveMeDemoState.resetForTest();
    ArchiveAppReviewSession.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('app_review_access_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
  });

  tearDown(() {
    ArchiveAppReviewAccessGate.resetForTest();
    ArchiveMeDemoState.resetForTest();
    ArchiveAppReviewSession.resetForTest();
  });

  group('ArchiveAppReviewAccess', () {
    test('review code constant matches App Review notes', () {
      expect(ArchiveAppReviewAccessGate.reviewCode, 'ARCHIVEME-REVIEW-2026');
    });

    test('invalid code does not unlock', () async {
      final ok = await ArchiveAppReviewAccess.tryUnlock(
        code: 'wrong-code',
        prefs: prefs,
      );
      expect(ok, isFalse);
      expect(await ArchiveAppReviewAccess.isUnlocked(prefs), isFalse);
      expect(ArchiveMeDemoState.isActive, isFalse);
    });

    test('valid code unlocks review access and demo archive', () async {
      final ok = await ArchiveAppReviewAccess.tryUnlock(
        code: 'ARCHIVEME-REVIEW-2026',
        prefs: prefs,
      );
      expect(ok, isTrue);
      expect(await ArchiveAppReviewAccess.isUnlocked(prefs), isTrue);
      expect(ArchiveMeDemoState.isActive, isTrue);
      expect(ArchiveAppReviewSession.isActive, isTrue);

      final loop = await ArchiveLoopEntitlementStore(prefs).load();
      expect(loop.isPro, isFalse);
      expect(loop.hasCompletedFirstLoop, isTrue);
    });

    test('valid code seeds paywall proof milestones', () async {
      await ArchiveAppReviewAccess.tryUnlock(
        code: ArchiveAppReviewAccessGate.reviewCode,
        prefs: prefs,
      );

      final raw = await prefs.readMap(DelayedPaywallProofStore.prefsKey);
      expect(raw?['hasSeenFirstRepeat'], isTrue);
      expect(raw?['hasOpenedEvidenceTrail'], isTrue);
      expect(await PaywallAccess.canOpenPaywall(), isTrue);
    });

    test('demo content is available after review unlock', () async {
      await ArchiveAppReviewAccess.tryUnlock(
        code: ' archiveme-review-2026 ',
        prefs: prefs,
      );

      final entries = ArchiveMeDemoArchive.journalEntries();
      expect(entries.length, greaterThanOrEqualTo(3));
      expect(ArchiveMeDemoArchive.hasConfirmedRepeat, isTrue);
      expect(ArchiveMeDemoArchive.hasBeliefProof, isTrue);
      expect(ArchiveMeDemoArchive.hasGeneratedComparison, isTrue);
      final comparison = ArchiveMeDemoArchive.reviewerComparison.output;
      expect(comparison?.pastQuote, isNotEmpty);
      expect(comparison?.presentQuote, isNotEmpty);
      final watchTarget = await WatchForStore(prefs).readPending();
      expect(watchTarget, isNotNull);
      expect(watchTarget?.sourceReflectionId, entries.last.id);
      expect(watchTarget?.text, contains('checking capacity'));
      expect(
        entries.every((e) => e.id.startsWith(ArchiveMeDemoState.entryIdPrefix)),
        isTrue,
      );
    });

    test('review unlock is blocked when gate is disabled', () async {
      ArchiveAppReviewAccessGate.enabledOverride = false;
      final ok = await ArchiveAppReviewAccess.tryUnlock(
        code: ArchiveAppReviewAccessGate.reviewCode,
        prefs: prefs,
      );
      expect(ok, isFalse);
    });

    test('demo state hydrates from prefs after restart', () async {
      await ArchiveAppReviewAccess.tryUnlock(
        code: ArchiveAppReviewAccessGate.reviewCode,
        prefs: prefs,
      );
      ArchiveMeDemoState.resetForTest();
      ArchiveAppReviewSession.resetForTest();

      await ArchiveMeDemoState.hydrateFromPrefs(prefs);
      await ArchiveAppReviewSession.hydrateFromPrefs(prefs);
      expect(ArchiveMeDemoState.reviewDemoUnlocked, isTrue);
      expect(ArchiveMeDemoState.isActive, isTrue);
      expect(ArchiveAppReviewSession.isActive, isTrue);
    });

    test('restore succeeds when billing unavailable in review mode', () async {
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        prefsPath: '${tempDir.path}/prefs_restore.json',
        skipRevenueCat: true,
      );
      await ArchiveAppReviewAccess.tryUnlock(
        code: ArchiveAppReviewAccessGate.reviewCode,
        prefs: AppServices.instance.prefs,
      );

      final flow = RestorePurchasesFlow(
        repository: AppServices.instance.subscriptionRepository,
        isBillingConfigured: () => false,
      );
      final result = await flow.restore();

      expect(result.outcome, RestorePurchasesOutcome.restored);
      expect(result.isPro, isTrue);
      expect(result.subscriptionState?.origin, SubscriptionStateOrigin.local);
    });
  });

  group('App Review docs', () {
    test('APP_REVIEW_NOTES documents review code and unlock path', () {
      final notes = File('docs/APP_REVIEW_NOTES.md').readAsStringSync();
      expect(notes, contains('ARCHIVEME-REVIEW-2026'));
      expect(notes, contains('App Review Access'));
      expect(notes, contains('pre-populated sample archive'));
      expect(notes, contains('https://careosapp.co.uk/archiveme-privacy'));
    });
  });
}
