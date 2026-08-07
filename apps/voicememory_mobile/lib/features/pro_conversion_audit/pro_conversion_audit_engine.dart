import '../archive_backup_bridge/archive_backup_bridge_copy.dart';
import '../archive_backup_bridge/archive_backup_bridge_engine.dart';
import '../archive_backup_bridge/archive_backup_bridge_model.dart';
import '../early_archive/private_archive_report_copy.dart';
import '../monthly_private_report/monthly_private_report_copy.dart';
import '../monthly_private_report/monthly_private_report_engine.dart';
import '../monthly_private_report/monthly_private_report_model.dart';
import '../pro_evidence_value/pro_evidence_value_copy.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../pro_evidence_value/pro_evidence_value_model.dart';
import '../pro_lock_moment/pro_lock_moment_copy.dart';
import '../pro_lock_moment/pro_lock_moment_engine.dart';
import '../pro_value/pro_value_copy.dart';
import '../private_report/private_report_copy.dart';
import '../revenue_foundation/revenue_value_copy.dart';
import '../../models/journal_entry.dart';
import 'pro_conversion_audit_copy.dart';

enum ProConversionSurface {
  proLockMoment(
    analyticsSource: 'record_post_save_pro_lock_moment',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: true,
  ),
  monthlyPrivateReportPreview(
    analyticsSource: 'patterns_monthly_private_report_preview',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: true,
  ),
  archiveBackupBridge(
    analyticsSource: 'patterns_archive_backup_bridge',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: true,
  ),
  proEvidenceValue(
    analyticsSource: 'patterns_pro_evidence_value',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: true,
  ),
  privateArchiveReport(
    analyticsSource: 'patterns_private_report',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: false,
  ),
  weeklyReviewProBridge(
    analyticsSource: 'weekly_review_preview',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: false,
  ),
  settingsProValuePreview(
    analyticsSource: 'settings_pro_value_preview',
    primaryRoute: ProConversionAuditCopy.proPreviewRoute,
    opensSheetBeforeSubscribe: false,
  ),
  settingsArchiveBackupBridge(
    analyticsSource: 'settings',
    primaryRoute: ProConversionAuditCopy.subscriptionRoute,
    opensSheetBeforeSubscribe: true,
  );

  const ProConversionSurface({
    required this.analyticsSource,
    required this.primaryRoute,
    required this.opensSheetBeforeSubscribe,
  });

  final String analyticsSource;
  final String primaryRoute;
  final bool opensSheetBeforeSubscribe;
}

/// Read-only audit helpers for Pro conversion paths and copy guards.
abstract final class ProConversionAuditEngine {
  ProConversionAuditEngine._();

  static List<String> revenueFeatureCopy({bool exportReportsLive = true}) {
    return [
      ...ProLockMomentCopy.allVisibleStrings(),
      ...MonthlyPrivateReportCopy.allVisibleStrings(),
      ...ArchiveBackupBridgeCopy.allVisibleStrings(),
      ...ProEvidenceValueCopy.allVisibleStrings(
        exportReportsLive: exportReportsLive,
      ),
      ...RevenueValueCopy.allConsumerStrings(
        exportReportsLive: exportReportsLive,
        safeSharingLive: false,
      ),
      PrivateReportCopy.previewTitle,
      PrivateReportCopy.previewBody,
      PrivateReportCopy.previewProCta,
      PrivateArchiveReportCopy.previewTitle,
      PrivateArchiveReportCopy.previewBody,
      ProValueCopy.settingsTitle,
      ProValueCopy.settingsSubtitle,
      ProValueCopy.headline,
      ProValueCopy.whyBodyTwo,
    ];
  }

  static bool passesRevenueCopyAudit({bool exportReportsLive = true}) {
    final strings = revenueFeatureCopy(exportReportsLive: exportReportsLive);
    return ProConversionAuditCopy.mentionsPaidMemoryReason(strings) &&
        ProConversionAuditCopy.hasNoBannedLiveClaims(strings) &&
        ProConversionAuditCopy.hasNoMedicalClaims(strings);
  }

  static bool blocksUpgradeForProUser({
    required List<JournalEntry> entries,
    int entryCount = 0,
    bool hasFirstProof = true,
  }) {
    final monthlyPreview = MonthlyPrivateReportEngine.build(entries: entries);
    return !MonthlyPrivateReportEngine.shouldShowCard(
          MonthlyPrivateReportEngine.buildContext(
            surface: MonthlyPrivateReportSurface.archivePatterns,
            entryCount: entryCount,
            isPro: true,
            dismissed: false,
            entries: entries,
            preview: monthlyPreview,
          ),
        ) &&
        !ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: entryCount,
            isPro: true,
            dismissed: false,
            entries: entries,
            firstProofPayoffVisible: hasFirstProof,
          ),
        ) &&
        !ArchiveBackupBridgeEngine.shouldShowCard(
          ArchiveBackupBridgeEngine.buildContext(
            surface: ArchiveBackupBridgeSurface.archivePatterns,
            entryCount: entryCount,
            isPro: true,
            dismissed: false,
            entries: entries,
          ),
        ) &&
        !ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.archivePatterns,
            entryCount: entryCount,
            isPro: true,
            dismissed: false,
            entries: entries,
          ),
        );
  }

  static bool blocksMonetisationBeforeValue({
    required List<JournalEntry> entries,
  }) {
    if (entries.isEmpty) {
      return !MonthlyPrivateReportEngine.shouldShowCard(
            MonthlyPrivateReportEngine.buildContext(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 0,
              isPro: false,
              dismissed: false,
              entries: entries,
              isZeroEntryState: true,
            ),
          ) &&
          !ProLockMomentEngine.shouldShowCard(
            ProLockMomentEngine.buildContext(
              entryCount: 0,
              isPro: false,
              dismissed: false,
              entries: entries,
              isZeroEntryState: true,
            ),
          ) &&
          !ArchiveBackupBridgeEngine.shouldShowCard(
            ArchiveBackupBridgeEngine.buildContext(
              surface: ArchiveBackupBridgeSurface.archivePatterns,
              entryCount: 0,
              isPro: false,
              dismissed: false,
              entries: entries,
              isZeroEntryState: true,
            ),
          );
    }
    return true;
  }
}
