import 'dart:io';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_gates.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_copy.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/pro_memory/pro_memory_boundary_copy.dart';
import 'package:archiveme_mobile/features/pro_memory/pro_memory_boundary_engine.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/paywall_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_paywall/pro_memory_upgrade_bridge.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/weekly_review/weekly_archive_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    'e1',
    'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    'e2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    'e3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fiveRelatedEntries() => [
  ..._threeRelatedEntries(),
  _entry(
    'e4',
    'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
  _entry(
    'e5',
    'Same yes pattern came back but it felt less urgent and easier to stop.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

WeeklyArchiveReviewResult _fullWeeklyReview() =>
    const WeeklyArchiveReviewResult(
      state: WeeklyArchiveReviewState.full,
      title: WeeklyArchiveReviewCopy.title,
      subtitle: WeeklyArchiveReviewCopy.subtitle,
      whatRepeated: WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatRepeatedLabel,
        body: "'said yes' appeared across several moments.",
        isSupported: true,
      ),
      whatChanged: WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatChangedLabel,
        body: 'One later entry sounded softer than before.',
        isSupported: true,
      ),
      whatHelped: WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatHelpedLabel,
        body: 'Pausing before agreeing seemed to help.',
        isSupported: true,
      ),
      whatToWatchNext: WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatToWatchLabel,
        body: WeeklyArchiveReviewCopy.watchBeforeAgree,
        isSupported: true,
      ),
    );

PatternDetailResult _detailWithMoments(int momentCount) {
  final moments = List.generate(
    momentCount,
    (i) => PatternDetailMoment(
      entryId: 'm$i',
      dateTimeLabel: 'Jun ${10 + i}, 2026 · 12:00 PM',
      previewText: 'Moment preview $i about saying yes again.',
      statusChipLabel: 'Used as evidence',
      statusKey: 'used_as_evidence',
    ),
  );
  return PatternDetailResult(
    patternLabel: 'Saying yes before checking capacity',
    patternKey: 'said yes',
    evidencePhrases: const ['said yes'],
    whatChangedBody: 'One later entry sounded softer.',
    whatChangedSupported: true,
    whatHelpedBody: 'Not enough evidence yet.',
    whatHelpedSupported: false,
    whatToWatchNextBody: WeeklyArchiveReviewCopy.watchBeforeAgree,
    savedMoments: moments,
  );
}

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
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  group('ProMemoryBoundaryCopy', () {
    test('defines upgrade bridge and fallback copy', () {
      expect(ProMemoryBoundaryCopy.upgradeBridgeTitle, 'ArchiveMe Pro');
      expect(
        ProMemoryBoundaryCopy.upgradeBridgeBody,
        contains('longer proof trail'),
      );
      expect(ProMemoryBoundaryCopy.seeProCta, 'See Pro');
      expect(
        ProMemoryBoundaryCopy.offeringsUnavailableBody,
        'Monthly and yearly plans will appear when App Store products finish loading.',
      );
    });
  });

  group('ProMemoryBoundaryEngine free loop', () {
    test('record, transcript correction, and first proof stay free', () {
      expect(ProMemoryBoundaryEngine.canRecord(), isTrue);
      expect(ProMemoryBoundaryEngine.canCorrectTranscript(), isTrue);
      expect(ProMemoryBoundaryEngine.canSeeFirstProof(), isTrue);
    });

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

    test('recent saved history keeps first-proof range for free users', () {
      final moments = List.generate(5, (i) => 'moment_$i');
      final visible = ProMemoryBoundaryEngine.visibleRecentMoments(
        moments: moments,
        isPro: false,
      );
      expect(
        visible,
        hasLength(ProMemoryBoundaryEngine.freePatternDetailMomentLimit),
      );
      expect(visible, moments.take(3).toList());
    });

    test('Pro user sees all saved moments', () {
      final moments = List.generate(5, (i) => 'moment_$i');
      final visible = ProMemoryBoundaryEngine.visibleRecentMoments(
        moments: moments,
        isPro: true,
      );
      expect(visible, hasLength(5));
    });
  });

  group('ProMemoryBoundaryEngine weekly review gating', () {
    test('free user gets preview section only', () {
      expect(
        ProMemoryBoundaryEngine.includeWeeklyReviewSection(
          sectionIndex: 0,
          isPro: false,
        ),
        isTrue,
      );
      expect(
        ProMemoryBoundaryEngine.includeWeeklyReviewSection(
          sectionIndex: 1,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        ProMemoryBoundaryEngine.canAccessFullWeeklyReview(isPro: false),
        isFalse,
      );
      expect(
        ProMemoryBoundaryEngine.canAccessFullWeeklyReview(isPro: true),
        isTrue,
      );
    });

    test('detects gated weekly review sections', () {
      expect(
        ProMemoryBoundaryEngine.hasGatedWeeklyReviewSections(
          review: _fullWeeklyReview(),
          isPro: false,
        ),
        isTrue,
      );
      expect(
        ProMemoryBoundaryEngine.hasGatedWeeklyReviewSections(
          review: _fullWeeklyReview(),
          isPro: true,
        ),
        isFalse,
      );
    });
  });

  group('private recap export is free forever', () {
    test('free and Pro users can both export the full private report', () {
      expect(
        ProMemoryBoundaryEngine.canExportPrivateReport(isPro: false),
        isTrue,
      );
      expect(
        ProMemoryBoundaryEngine.canExportPrivateReport(isPro: true),
        isTrue,
      );
      expect(PrivateArchiveReportGates.showFullExport(isPro: false), isTrue);
      expect(PrivateArchiveReportGates.showFullExport(isPro: true), isTrue);
    });

    test('the export shows no Pro preview note, even for free users', () {
      expect(PrivateArchiveReportGates.showPreviewNote(isPro: false), isFalse);
      expect(
        PrivateArchiveReportGates.includeSectionInPreview(
          sectionIndex: 99,
          isPro: false,
        ),
        isTrue,
      );
    });
  });

  group('ProMemoryBoundaryEngine entitlement resolution', () {
    test('uses cached entitlement when reader unavailable', () async {
      expect(
        await ProMemoryBoundaryEngine.resolveIsPro(
          reader: FakeArchiveEntitlementReader(pro: false),
          cachedIsPro: true,
        ),
        isTrue,
      );
    });

    test('falls back to cached false when reader throws', () async {
      expect(
        await ProMemoryBoundaryEngine.resolveIsPro(
          reader: _ThrowingEntitlementReader(),
          cachedIsPro: false,
        ),
        isFalse,
      );
    });
  });

  group('ProMemoryBoundaryEngine offerings fallback', () {
    test('matches packaging unavailable copy', () {
      expect(
        ProMemoryBoundaryEngine.offeringsUnavailableFallback(),
        ProPackagingCopy.offeringsUnavailableBody,
      );
      final display = ProMemoryBoundaryEngine.buildPaywallPackaging(
        offeringsAvailable: false,
        showPlanPrices: true,
      );
      expect(display.showPlanPrices, isFalse);
      expect(
        display.unavailableBody,
        ProPackagingCopy.offeringsUnavailableBody,
      );
    });
  });

  group('ProMemoryUpgradeBridge', () {
    testWidgets('renders longer archive memory bridge copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProMemoryUpgradeBridge(onSeePro: () {}, onNotNow: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(ProMemoryBoundaryCopy.upgradeBridgeTitle),
        findsOneWidget,
      );
      expect(
        find.text(ProMemoryBoundaryCopy.upgradeBridgeBody),
        findsOneWidget,
      );
      expect(find.text(ProMemoryBoundaryCopy.seeProCta), findsOneWidget);
      expect(
        find.byKey(const Key('pro_memory_upgrade_bridge')),
        findsOneWidget,
      );
    });
  });

  group('WeeklyArchiveReviewSheet pro boundary', () {
    testWidgets('free user sees preview and upgrade bridge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WeeklyArchiveReviewSheet(
              review: _fullWeeklyReview(),
              isPro: false,
              onSeePro: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_archive_review_repeated_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_changed_body')),
        findsNothing,
      );
      expect(
        find.text(ProMemoryBoundaryCopy.weeklyReviewPreviewTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_memory_upgrade_bridge_compact')),
        findsOneWidget,
      );
    });

    testWidgets('Pro user sees full weekly review', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WeeklyArchiveReviewSheet(
              review: _fullWeeklyReview(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_archive_review_repeated_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_changed_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_helped_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_watch_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_memory_upgrade_bridge_compact')),
        findsNothing,
      );
    });
  });

  group('PatternDetailSheet pro boundary', () {
    testWidgets(
      'free user sees first-proof moments and older evidence bridge',
      (tester) async {
        final detail = _detailWithMoments(5);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PatternDetailSheet(
                detail: detail,
                isPro: false,
                onSeePro: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('pattern_detail_moment_row_0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pattern_detail_moment_row_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pattern_detail_moment_row_2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pattern_detail_moment_row_3')),
          findsNothing,
        );
        expect(
          find.text(ProMemoryBoundaryCopy.olderEvidenceTitle),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pro_memory_upgrade_bridge_compact')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Pro user sees all evidence moments', (tester) async {
      final detail = _detailWithMoments(5);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PatternDetailSheet(detail: detail)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_detail_moment_row_4')),
        findsOneWidget,
      );
      expect(find.text(ProMemoryBoundaryCopy.olderEvidenceTitle), findsNothing);
    });
  });

  group('Pattern detail engine still builds for free users', () {
    test('grounded pattern detail remains available at first proof', () {
      final detail = PatternDetailEngine.build(
        entries: _fiveRelatedEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(detail, isNotNull);
      expect(detail!.evidencePhrases, isNotEmpty);
      expect(detail.patternLabel, isNotEmpty);
      expect(PatternDetailCopy.viewPatternDetailsCta, isNotEmpty);
    });
  });

  group('Paywall offerings empty fallback', () {
    testWidgets('restore purchases visible when offerings empty', (
      tester,
    ) async {
      await _pumpPaywall(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      final unavailableBody = tester.widget<Text>(
        find.byKey(const Key('paywall_unavailable_body')),
      );
      expect(
        unavailableBody.data,
        allOf(
          contains(ConsumerUiCopy.paywallBillingNotConfigured),
          contains(ConsumerUiCopy.paywallUnavailablePlansLoading),
        ),
      );
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });
  });

  group('protected areas untouched', () {
    test('RevenueCat product id unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('pro memory files do not change billing entitlement or signing', () {
      const paths = [
        'lib/features/pro_memory/pro_memory_boundary_copy.dart',
        'lib/features/pro_memory/pro_memory_boundary_engine.dart',
        'lib/widgets/archive_paywall/pro_memory_upgrade_bridge.dart',
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

class _ThrowingEntitlementReader extends ArchiveEntitlementReader {
  @override
  Future<bool> get isPro async => throw StateError('offline');
}