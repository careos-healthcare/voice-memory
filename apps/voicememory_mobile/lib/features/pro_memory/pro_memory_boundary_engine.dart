import '../../billing/archive_entitlement_reader.dart';
import '../activation/paywall_timing_gates.dart';
import '../early_archive/private_archive_report_gates.dart';
import '../pro_packaging/pro_value_copy.dart';
import '../pro_packaging/pro_value_engine.dart';
import '../pro_packaging/pro_value_model.dart';
import '../weekly_review/weekly_archive_review_model.dart';

/// Display-only Pro boundary for longer archive memory — no billing changes.
abstract final class ProMemoryBoundaryEngine {
  ProMemoryBoundaryEngine._();

  /// Recent saved moments visible on free tier (first-proof range).
  static const freeRecentSavedMomentLimit = 3;

  /// Weekly review sections visible on free tier (what repeated only).
  static const freeWeeklyReviewPreviewSectionCount = 1;

  /// Pattern detail evidence moments visible on free tier.
  static const freePatternDetailMomentLimit = 3;

  static bool canRecord() => true;

  static bool canCorrectTranscript() => true;

  static bool canSeeFirstProof() => true;

  static bool canAccessFullWeeklyReview({required bool isPro}) => isPro;

  static bool canExportPrivateReport({required bool isPro}) =>
      PrivateArchiveReportGates.showFullExport(isPro: isPro);

  static bool canSeeFullPatternHistory({required bool isPro}) => isPro;

  static bool showWeeklyReviewPreviewNote({required bool isPro}) => !isPro;

  static bool showPrivateReportPreviewNote({required bool isPro}) => !isPro;

  static bool includeWeeklyReviewSection({
    required int sectionIndex,
    required bool isPro,
  }) => isPro || sectionIndex < freeWeeklyReviewPreviewSectionCount;

  static bool hasGatedWeeklyReviewSections({
    required WeeklyArchiveReviewResult review,
    required bool isPro,
  }) {
    if (isPro || review.state != WeeklyArchiveReviewState.full) return false;
    return review.whatChanged != null ||
        review.whatHelped != null ||
        review.whatToWatchNext != null;
  }

  static List<T> visibleRecentMoments<T>({
    required List<T> moments,
    required bool isPro,
  }) {
    if (isPro) return moments;
    if (moments.length <= freePatternDetailMomentLimit) return moments;
    return moments.take(freePatternDetailMomentLimit).toList();
  }

  static bool hasGatedOlderMoments({
    required int totalMomentCount,
    required bool isPro,
  }) => !isPro && totalMomentCount > freePatternDetailMomentLimit;

  static int gatedOlderMomentCount({
    required int totalMomentCount,
    required bool isPro,
  }) {
    if (isPro || totalMomentCount <= freePatternDetailMomentLimit) return 0;
    return totalMomentCount - freePatternDetailMomentLimit;
  }

  static bool includePrivateReportSection({
    required int sectionIndex,
    required bool isPro,
    int previewSectionCount = 1,
  }) => PrivateArchiveReportGates.includeSectionInPreview(
    sectionIndex: sectionIndex,
    isPro: isPro,
    previewSectionCount: previewSectionCount,
  );

  /// Uses cached entitlement when offline; never hard-blocks core free loop.
  static Future<bool> resolveIsPro({
    ArchiveEntitlementReader? reader,
    bool? cachedIsPro,
  }) async {
    if (cachedIsPro == true) return true;
    final entitlementReader =
        reader ?? ArchiveEntitlementReader.forAccessCheck();
    try {
      return await entitlementReader.isPro;
    } catch (_) {
      return cachedIsPro ?? false;
    }
  }

  static bool shouldShowUpgradeBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool isPostSave,
    required bool hasConfirmedRepeat,
    required bool hasArchiveSummary,
    required bool hasWeeklyArchiveReview,
    bool hasPatternChanged = false,
    bool hasPrivateArchiveReportPreview = false,
    bool hasReturnCheckAnswered = false,
  }) => PaywallTimingGates.showFullArchiveHistoryProBoundary(
    entryCount: entryCount,
    resolved: resolved,
    isPro: isPro,
    isPostSave: isPostSave,
    hasConfirmedRepeat: hasConfirmedRepeat,
    hasArchiveSummary: hasArchiveSummary,
    hasWeeklyArchiveReview: hasWeeklyArchiveReview,
    hasPatternChanged: hasPatternChanged,
    hasPrivateArchiveReportPreview: hasPrivateArchiveReportPreview,
    hasReturnCheckAnswered: hasReturnCheckAnswered,
  );

  static ProPackagingDisplay buildPaywallPackaging({
    required bool offeringsAvailable,
    required bool showPlanPrices,
    String? purchaseCta,
  }) => ProPackagingEngine.build(
    offeringsAvailable: offeringsAvailable,
    showPlanPrices: showPlanPrices,
    purchaseCta: purchaseCta,
  );

  static String offeringsUnavailableFallback() =>
      ProPackagingCopy.offeringsUnavailableBody;
}
