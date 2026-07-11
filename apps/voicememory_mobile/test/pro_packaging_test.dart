import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/features/belief_change/belief_change_moment_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_gates.dart';
import 'package:voicememory_mobile/features/pro_memory/pro_memory_boundary_engine.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/purchase_confidence/purchase_confidence_copy.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_copy.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/account/archive_me_pro_value_section.dart';
import 'package:voicememory_mobile/widgets/patterns/belief_change_moment_card.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_payoff_card.dart';

JournalEntry _entry(String id, String transcript) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: 'pattern',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: 'signal',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        'e1',
        'I had no capacity but I said yes again to the extra meeting today.',
      ),
      _entry(
        'e2',
        'Same thing — said yes when I had no capacity for one more thing.',
      ),
      _entry(
        'e3',
        'I said yes again even though I had no capacity for one more ask.',
      ),
    ];

Future<void> _pumpPaywall(
  WidgetTester tester, {
  bool billingReady = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(
              billingConfiguredForRestore: () => true,
              billingReadyOverride: () => billingReady,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('ProPackagingCopy', () {
    test('defines longer proof trail Pro positioning', () {
      expect(ProPackagingCopy.title, 'ArchiveMe Pro');
      expect(
        ProPackagingCopy.subtitle,
        PaywallAlignmentCopy.body,
      );
      expect(ProPackagingCopy.freeSectionTitle, 'Free');
      expect(
        ProPackagingCopy.freeBullets.single,
        'Start your archive and unlock your first proof.',
      );
      expect(ProPackagingCopy.proSectionTitle, 'Pro');
      expect(ProPackagingCopy.proBullets, hasLength(6));
      expect(ProPackagingCopy.proBullets, contains('Full pattern timeline'));
      expect(ProPackagingCopy.proBullets, contains('Monthly private report'));
      expect(
        ProPackagingCopy.bridgeAfterFirstProof,
        PaywallAlignmentCopy.secondaryReassurance,
      );
      expect(
        ProPackagingCopy.bridgeAfterBeliefChange,
        'Seeing change over time is the reason to keep your archive.',
      );
      expect(
        ProPackagingCopy.offeringsUnavailableBody,
        'Plans are temporarily unavailable. You can still use ArchiveMe.',
      );
    });
  });

  group('ProEvidenceValueCopy', () {
    test('aligns longer proof trail Pro bridge with packaging', () {
      expect(ProEvidenceValueCopy.title, 'Keep the longer proof trail');
      expect(
        ProEvidenceValueCopy.chatGptDifferentiationLine,
        contains('ChatGPT can answer a conversation'),
      );
      expect(
        ProEvidenceValueCopy.sheetFooter,
        contains('remembers differently'),
      );
      expect(
        ProEvidenceValueCopy.proBulletsForDisplay(exportReportsLive: true),
        contains('Full pattern timeline'),
      );
    });
  });

  group('ProPackagingEngine', () {
    test('uses existing purchase CTA when offerings available', () {
      final display = ProPackagingEngine.build(
        offeringsAvailable: true,
        showPlanPrices: true,
      );
      expect(display.purchaseCta, ConsumerUiCopy.paywallPrimaryCta);
      expect(display.showPlanPrices, isTrue);
    });

    test('hides prices when offerings unavailable', () {
      final display = ProPackagingEngine.build(
        offeringsAvailable: false,
        showPlanPrices: true,
      );
      expect(display.showPlanPrices, isFalse);
      expect(display.unavailableBody, ProPackagingCopy.offeringsUnavailableBody);
    });
  });

  group('ArchiveMeProValueSection', () {
    testWidgets('renders free and pro sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveMeProValueSection(
              packaging: ProPackagingEngine.build(
                offeringsAvailable: false,
                showPlanPrices: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('archive_me_pro_value_section')), findsOneWidget);
      expect(find.byKey(const Key('archive_me_pro_free_section')), findsOneWidget);
      expect(find.byKey(const Key('archive_me_pro_pro_section')), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(
        find.text('Start your archive and unlock your first proof.'),
        findsOneWidget,
      );
      expect(find.text('Full pattern timeline'), findsOneWidget);
      expect(find.text('Monthly private report'), findsOneWidget);
    });
  });

  group('PaywallScreen packaging', () {
    testWidgets('opens with value sections when offerings empty', (tester) async {
      await _pumpPaywall(tester, billingReady: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallBillingNotConfigured), findsOneWidget);
      expect(find.byKey(const Key('paywall_primary_value_block')), findsOneWidget);
      expect(find.text(PurchaseConfidenceCopy.cardTitle), findsOneWidget);
      expect(find.text(ProPackagingCopy.continueCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('restore purchases visible when offerings empty', (tester) async {
      await _pumpPaywall(tester, billingReady: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('no blank broken UI when RevenueCat products unavailable', (
      tester,
    ) async {
      await _pumpPaywall(tester, billingReady: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(ConsumerUiCopy.paywallBillingNotConfigured), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.text('Full pattern timeline'), findsOneWidget);
      expect(find.text('Monthly private report'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('0.00'), findsNothing);
    });
  });

  group('Account screen packaging', () {
    testWidgets('shows ArchiveMe Pro value section and tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archive_me_pro_value_section')), findsOneWidget);
      expect(find.text(ProPackagingCopy.title), findsWidgets);
      expect(find.text(ProPackagingCopy.accountTileSubtitle), findsOneWidget);
    });
  });

  group('first proof remains free', () {
    test('first proof moment still shows without paywall gate', () {
      final entries = _threeRelatedEntries();
      final moment = FirstProofMomentEngine.build(entries: entries);
      expect(
        FirstProofMomentGates.shouldShow(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          entryCount: 3,
          moment: moment,
        ),
        isTrue,
      );
      expect(moment, isNotNull);
    });

    test('pro boundary does not show before first proof foundation', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 2,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });
  });

  group('weekly review bridge is not intrusive', () {
    test('pro boundary requires confirmed repeat and not on post-save', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 5,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: true,
        ),
        isTrue,
      );
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 5,
          resolved: false,
          isPro: false,
          isPostSave: true,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: true,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 1,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });
  });

  group('value moment bridge copy', () {
    testWidgets('first proof payoff shows full timeline bridge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final payoff = FirstProofPayoffEngine.build(entries: _threeRelatedEntries());
      expect(payoff, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstProofPayoffCard(
                payoff: payoff!,
                entryCount: 3,
                onWatchThisNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pro_packaging_bridge_first_proof')), findsOneWidget);
      expect(find.text(ProPackagingCopy.bridgeAfterFirstProof), findsOneWidget);
    });

    testWidgets('belief change moment shows keep archive bridge', (tester) async {
      final moment = BeliefChangeMomentEngine.build(
        entries: [
          ..._threeRelatedEntries(),
          _entry(
            'e4',
            'I checked my calendar before answering when they asked me to take on more work.',
          ),
        ],
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefChangeMomentCard(
                moment: moment!,
                entryCount: 4,
                source: 'patterns',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(ProPackagingCopy.bridgeAfterBeliefChange),
        findsOneWidget,
      );
    });
  });

  group('free controls stay available', () {
    test('recording transcript correction and first proof stay free', () {
      expect(ProMemoryBoundaryEngine.canRecord(), isTrue);
      expect(ProMemoryBoundaryEngine.canCorrectTranscript(), isTrue);
      expect(ProMemoryBoundaryEngine.canSeeFirstProof(), isTrue);
    });
  });

  group('protected areas untouched', () {
    test('RevenueCat product id unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('packaging files do not change billing entitlement or signing', () {
      const paths = [
        'lib/features/pro_packaging/pro_value_copy.dart',
        'lib/features/pro_packaging/pro_value_model.dart',
        'lib/features/pro_packaging/pro_value_engine.dart',
        'lib/widgets/account/archive_me_pro_value_section.dart',
        'lib/widgets/common/pro_packaging_bridge_line.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('proentitlementid')));
        expect(content, isNot(contains('purchasepackage')));
        expect(content, isNot(contains('build_number')));
        expect(content, isNot(contains('codesign')));
        expect(content, isNot(contains('productidentifier')));
      }
    });
  });
}
