import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_analytics.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_model.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_analytics.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_analytics.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_engine.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_model.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_analytics.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_event.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/archive_backup_bridge_card.dart';
import 'package:voicememory_mobile/widgets/pro/monthly_private_report_preview_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_card.dart';

const _userTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
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

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        id: 'e1',
        transcript: _userTranscript,
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  setUp(RevenueFunnelAnalytics.resetForTest);

  tearDown(RevenueFunnelAnalytics.resetForTest);

  group('RevenueFunnelAnalytics integration', () {
    test('emits event on Pro Lock seen/tap', () {
      ProLockMomentAnalytics.seen(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasFirstProof: true,
        hasConfirmedRepeat: true,
      );
      ProLockMomentAnalytics.ctaTapped(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasFirstProof: true,
        hasConfirmedRepeat: true,
        actionType: 'open_sheet',
      );

      final events = RevenueFunnelAnalytics.eventsForTest;
      expect(events.length, 2);
      expect(events[0].event, RevenueFunnelEvent.proLockSeen);
      expect(events[1].event, RevenueFunnelEvent.proLockCtaTapped);
      expect(events[0].metadata['entry_count'], 3);
      expect(events[0].metadata['source'], 'record_post_save_first_proof');
      expect(events[0].metadata['surface'], 'record');
      expect(events[0].metadata['has_confirmed_repeat'], 1);
    });

    test('emits event on monthly report seen/tap', () {
      MonthlyPrivateReportAnalytics.seen(
        source: MonthlyPrivateReportSurface.archivePatterns.analyticsValue,
        entryCount: 4,
        hasConfirmedRepeat: true,
        hasChangeSignal: true,
        hasHelpedSignal: false,
        hasQuietSignal: false,
      );
      MonthlyPrivateReportAnalytics.ctaTapped(
        source: MonthlyPrivateReportSurface.archivePatterns.analyticsValue,
        entryCount: 4,
        hasConfirmedRepeat: true,
        hasChangeSignal: true,
        hasHelpedSignal: false,
        hasQuietSignal: false,
        actionType: 'open_sheet',
      );

      final events = RevenueFunnelAnalytics.eventsForTest;
      expect(events.length, 2);
      expect(events[0].event, RevenueFunnelEvent.monthlyReportPreviewSeen);
      expect(events[1].event, RevenueFunnelEvent.monthlyReportPreviewCtaTapped);
      expect(events[0].metadata['surface'], 'archive_patterns');
    });

    test('emits event on backup bridge seen/tap', () {
      ArchiveBackupBridgeAnalytics.seen(
        source: ArchiveBackupBridgeSurface.settings.analyticsValue,
        entryCount: 5,
        hasConfirmedRepeat: true,
        hasReportPreview: true,
      );
      ArchiveBackupBridgeAnalytics.ctaTapped(
        source: ArchiveBackupBridgeSurface.settings.analyticsValue,
        entryCount: 5,
        hasConfirmedRepeat: true,
        hasReportPreview: true,
        actionType: 'open_sheet',
      );

      final events = RevenueFunnelAnalytics.eventsForTest;
      expect(events.length, 2);
      expect(events[0].event, RevenueFunnelEvent.backupBridgeSeen);
      expect(events[1].event, RevenueFunnelEvent.backupBridgeCtaTapped);
      expect(events[0].metadata['has_report_preview'], 1);
    });

    test('emits first proof seen through payoff analytics', () {
      FirstProofPayoffAnalytics.seen(
        entryCount: 2,
        hasSnippets: true,
        hasPatternDetailCta: false,
      );

      final events = RevenueFunnelAnalytics.eventsForTest;
      expect(events.single.event, RevenueFunnelEvent.firstProofSeen);
      expect(events.single.metadata['entry_count'], 2);
      expect(events.single.metadata['surface'], 'record');
    });

    testWidgets('emits paywall seen when paywall is reachable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => PaywallScreen(
                  triggerArgs: const PaywallRouteArgs(
                    source: PaywallSource.generalPro,
                  ),
                  billingReadyOverride: () => false,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final seen = RevenueFunnelAnalytics.eventsForTest.where(
        (e) => e.event == RevenueFunnelEvent.paywallSeen,
      );
      expect(seen, isNotEmpty);
      expect(seen.first.metadata['source'], 'general_pro');
      expect(seen.first.metadata['surface'], 'paywall_screen');
      expect(seen.first.metadata['is_pro'], 0);
    });

    test('emits paywall CTA events with safe metadata', () {
      RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );
      RevenueFunnelAnalytics.paywallRestoreTapped(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );
      RevenueFunnelAnalytics.paywallDismissed(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );

      final events = RevenueFunnelAnalytics.eventsForTest;
      expect(events.length, 3);
      expect(events[0].event, RevenueFunnelEvent.paywallPurchaseCtaTapped);
      expect(events[1].event, RevenueFunnelEvent.paywallRestoreTapped);
      expect(events[2].event, RevenueFunnelEvent.paywallDismissed);
      for (final record in events) {
        expect(record.metadata['source'], 'general_pro');
        expect(record.metadata['surface'], 'paywall_screen');
        expect(record.metadata['is_pro'], 0);
      }
    });

    test('metadata contains no transcript/body/user text', () {
      ProLockMomentAnalytics.seen(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasFirstProof: true,
        hasConfirmedRepeat: true,
      );
      ArchiveBackupBridgeAnalytics.seen(
        source: ArchiveBackupBridgeSurface.settings.analyticsValue,
        entryCount: 5,
        hasConfirmedRepeat: true,
        hasReportPreview: true,
      );
      RevenueFunnelAnalytics.paywallSeen(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );

      final snapshot = RevenueFunnelAnalytics.debugSummary();
      expect(snapshot.noContentCaptured, isTrue);

      const allowedKeys = {
        'entry_count',
        'source',
        'has_confirmed_repeat',
        'has_report_preview',
        'is_pro',
        'surface',
      };
      for (final record in RevenueFunnelAnalytics.eventsForTest) {
        expect(record.metadata.keys.every(allowedKeys.contains), isTrue);
        for (final value in record.metadata.values) {
          expect(value.toString().toLowerCase(), isNot(contains('transcript')));
          expect(value.toString(), isNot(contains(_userTranscript)));
        }
      }
    });

    test('reset hook clears events for tests', () {
      RevenueFunnelAnalytics.proLockSeen(
        source: 'record_post_save_first_proof',
        entryCount: 2,
        hasConfirmedRepeat: true,
      );
      expect(RevenueFunnelAnalytics.eventsForTest, isNotEmpty);

      RevenueFunnelAnalytics.resetForTest();
      expect(RevenueFunnelAnalytics.eventsForTest, isEmpty);
    });
  });

  group('RevenueFunnelSnapshot', () {
    test('summarizes value events, CTA events, and surfaces', () {
      RevenueFunnelAnalytics.proLockSeen(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasConfirmedRepeat: true,
      );
      RevenueFunnelAnalytics.proLockCtaTapped(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasConfirmedRepeat: true,
      );
      RevenueFunnelAnalytics.monthlyReportPreviewSeen(
        source: 'archive_patterns',
        entryCount: 4,
        hasConfirmedRepeat: true,
      );

      final snapshot = RevenueFunnelAnalytics.debugSummary();
      expect(snapshot.totalValueEvents, 2);
      expect(snapshot.totalCtaEvents, 1);
      expect(snapshot.conversionSurfacesSeen, ['archive_patterns', 'record']);
      expect(snapshot.noContentCaptured, isTrue);
    });
  });

  group('Revenue funnel card wiring', () {
    testWidgets('Pro Lock card emits revenue funnel seen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProLockMomentCard(
              entryCount: 3,
              hasFirstProof: true,
              hasConfirmedRepeat: true,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(
        RevenueFunnelAnalytics.eventsForTest.any(
          (e) => e.event == RevenueFunnelEvent.proLockSeen,
        ),
        isTrue,
      );
    });

    testWidgets('monthly report card emits revenue funnel seen', (tester) async {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewCard(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 4,
              preview: preview,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(
        RevenueFunnelAnalytics.eventsForTest.any(
          (e) => e.event == RevenueFunnelEvent.monthlyReportPreviewSeen,
        ),
        isTrue,
      );
    });

    testWidgets('backup bridge card emits revenue funnel seen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBackupBridgeCard(
              contextData: ArchiveBackupBridgeContext(
                surface: ArchiveBackupBridgeSurface.settings,
                entryCount: 5,
                isPro: false,
                dismissed: false,
                hasConfirmedRepeat: true,
                hasReportPreview: true,
                hasSeenProof: true,
                isZeroEntryState: false,
                isFirstRecordingState: false,
                isDegradedTranscriptState: false,
                isPostSaveDegradedState: false,
                firstProofTruthQuestionActive: false,
                whatChangedQuestionActive: false,
                patternReviewInboxHasActiveItems: false,
              ),
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(
        RevenueFunnelAnalytics.eventsForTest.any(
          (e) => e.event == RevenueFunnelEvent.backupBridgeSeen,
        ),
        isTrue,
      );
    });
  });
}
