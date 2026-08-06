import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_engine.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_model.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_copy.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_engine.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_model.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_copy.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_copy.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_engine.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/archive_backup_bridge_card.dart';
import 'package:voicememory_mobile/widgets/pro/archive_backup_bridge_sheet.dart';
import 'package:voicememory_mobile/widgets/pro/monthly_private_report_preview_card.dart';
import 'package:voicememory_mobile/widgets/pro/monthly_private_report_preview_sheet.dart';
import 'package:voicememory_mobile/widgets/pro/pro_evidence_value_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_evidence_value_sheet.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_sheet.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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
    transcript: _strongRepeat,
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

MonthlyPrivateReportPreview _preview() =>
    MonthlyPrivateReportEngine.build(entries: _threeRelatedEntries())!;

ArchiveBackupBridgeContext _backupContext({bool isPro = false}) =>
    ArchiveBackupBridgeContext(
      surface: ArchiveBackupBridgeSurface.settings,
      entryCount: 3,
      isPro: isPro,
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
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/pro_conversion_path/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/pro_conversion_path/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('ProConversionAuditCopy', () {
    test('core paid reason is defined', () {
      expect(
        ProConversionAuditCopy.corePaidReason,
        PaywallAlignmentCopy.corePaidReason,
      );
    });

    test('subscription route is stable', () {
      expect(ProConversionAuditCopy.subscriptionRoute, '/subscription');
      expect(ProConversionAuditCopy.proPreviewRoute, '/pro-preview');
    });
  });

  group('ProConversionSurface routes', () {
    test('revenue bridges target subscription or value preview', () {
      expect(ProConversionSurface.proLockMoment.primaryRoute, '/subscription');
      expect(
        ProConversionSurface.monthlyPrivateReportPreview.primaryRoute,
        '/subscription',
      );
      expect(
        ProConversionSurface.archiveBackupBridge.primaryRoute,
        '/subscription',
      );
      expect(
        ProConversionSurface.proEvidenceValue.primaryRoute,
        '/subscription',
      );
      expect(
        ProConversionSurface.settingsProValuePreview.primaryRoute,
        '/pro-preview',
      );
    });

    test('sheet-first surfaces are flagged', () {
      expect(
        ProConversionSurface.proLockMoment.opensSheetBeforeSubscribe,
        isTrue,
      );
      expect(
        ProConversionSurface
            .monthlyPrivateReportPreview
            .opensSheetBeforeSubscribe,
        isTrue,
      );
      expect(
        ProConversionSurface.archiveBackupBridge.opensSheetBeforeSubscribe,
        isTrue,
      );
    });
  });

  group('ProConversionAuditEngine copy guard', () {
    test('revenue feature copy passes audit', () {
      expect(ProConversionAuditEngine.passesRevenueCopyAudit(), isTrue);
    });

    test('paid reason mentions longer proof trail or evidence', () {
      expect(
        ProConversionAuditCopy.mentionsPaidMemoryReason(
          ProConversionAuditEngine.revenueFeatureCopy(),
        ),
        isTrue,
      );
      expect(
        ProLockMomentCopy.paidReason.toLowerCase(),
        contains('longer proof trail'),
      );
      expect(
        ProEvidenceValueCopy.title.toLowerCase(),
        contains('longer proof trail'),
      );
      expect(
        MonthlyPrivateReportCopy.proReason.toLowerCase(),
        contains('longer proof trail'),
      );
    });

    test('no therapy medical or backup-live claims', () {
      final strings = ProConversionAuditEngine.revenueFeatureCopy();
      expect(ProConversionAuditCopy.hasNoMedicalClaims(strings), isTrue);
      expect(ProConversionAuditCopy.hasNoBannedLiveClaims(strings), isTrue);
    });

    test('no more AI framing in revenue copy', () {
      final blob = ProConversionAuditEngine.revenueFeatureCopy()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('better chat answers')));
      expect(blob, isNot(contains('smarter chat')));
    });

    test('settings pro preview route documented', () {
      expect(ProValueCopy.proPreviewRoute, '/pro-preview');
    });
  });

  group('ProConversionAuditEngine gating', () {
    test('Pro users do not see upgrade prompts on patterns surfaces', () {
      final entries = _threeRelatedEntries();
      expect(
        ProConversionAuditEngine.blocksUpgradeForProUser(
          entries: entries,
          entryCount: entries.length,
          hasFirstProof: true,
        ),
        isTrue,
      );
    });

    test('zero-entry users do not see monetisation bridges', () {
      expect(
        ProConversionAuditEngine.blocksMonetisationBeforeValue(entries: []),
        isTrue,
      );
    });

    test('confirmed repeat required before bridges show', () {
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          _threeRelatedEntries(),
        ),
        isTrue,
      );
    });
  });

  group('Pro Lock Moment CTA path', () {
    testWidgets('sheet See Pro invokes subscription callback', (tester) async {
      var openedSubscription = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProLockMomentSheet(
              source: 'test',
              entryCount: 3,
              hasFirstProof: true,
              hasConfirmedRepeat: true,
              onSeePro: () => openedSubscription = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pro_lock_moment_sheet_see_pro')));
      await tester.pump();

      expect(openedSubscription, isTrue);
    });

    testWidgets('card CTA opens sheet', (tester) async {
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
      await tester.pump();

      await tester.tap(find.byKey(const Key('pro_lock_moment_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('pro_lock_moment_sheet_title')),
        findsOneWidget,
      );
    });
  });

  group('Monthly Private Report Preview CTA path', () {
    testWidgets('sheet See Pro invokes subscription callback', (tester) async {
      var openedSubscription = false;
      final preview = _preview();
      addTearDown(tester.view.resetPhysicalSize);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewSheet(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 3,
              preview: preview,
              onSeePro: () => openedSubscription = true,
            ),
          ),
        ),
      );

      final seePro = find.byKey(
        const Key('monthly_private_report_preview_sheet_see_pro'),
      );
      await tester.ensureVisible(seePro);
      await tester.tap(seePro);
      await tester.pump();

      expect(openedSubscription, isTrue);
    });

    testWidgets('card CTA opens sheet', (tester) async {
      final preview = _preview();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewCard(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 3,
              preview: preview,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('monthly_private_report_preview_cta')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('monthly_private_report_preview_sheet_title')),
        findsOneWidget,
      );
    });
  });

  group('Archive Backup Bridge CTA path', () {
    testWidgets('card opens preservation sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBackupBridgeCard(
              contextData: _backupContext(),
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('archive_backup_bridge_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('archive_backup_bridge_sheet_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_backup_bridge_sheet_device_backup')),
        findsOneWidget,
      );
    });

    testWidgets('sheet See Pro invokes subscription callback', (tester) async {
      var openedSubscription = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBackupBridgeSheet(
              contextData: _backupContext(),
              onSeePro: () => openedSubscription = true,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('archive_backup_bridge_sheet_see_pro')),
      );
      await tester.pump();

      expect(openedSubscription, isTrue);
    });

    test('Pro user on patterns does not see upgrade bridge', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          ArchiveBackupBridgeEngine.buildContext(
            surface: ArchiveBackupBridgeSurface.archivePatterns,
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            entries: entries,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Pro Evidence Value CTA path', () {
    testWidgets('sheet See Pro invokes subscription callback', (tester) async {
      var openedSubscription = false;
      addTearDown(tester.view.resetPhysicalSize);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProEvidenceValueSheet(
              surface: ProEvidenceValueSurface.archivePatterns,
              entryCount: 3,
              onSeePro: () => openedSubscription = true,
            ),
          ),
        ),
      );

      final seePro = find.byKey(const Key('pro_evidence_value_sheet_see_pro'));
      await tester.ensureVisible(seePro);
      await tester.tap(seePro);
      await tester.pump();

      expect(openedSubscription, isTrue);
    });

    testWidgets('card CTA opens sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProEvidenceValueCard(
              surface: ProEvidenceValueSurface.archivePatterns,
              entryCount: 3,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('pro_evidence_value_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('pro_evidence_value_sheet_title')),
        findsOneWidget,
      );
    });

    test('hidden for Pro users', () {
      final entries = _threeRelatedEntries();
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.archivePatterns,
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            entries: entries,
          ),
        ),
        isFalse,
      );
    });
  });
}
