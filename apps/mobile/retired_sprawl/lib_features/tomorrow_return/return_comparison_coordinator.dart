import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_capture_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_retention_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Builds and persists return comparisons after a due commitment is fulfilled.
abstract class ReturnComparisonCoordinator {
  ReturnComparisonCoordinator._();

  static ReturnComparisonStore _comparisonStore() =>
      ReturnComparisonStore(AppServices.instance.prefs);

  static TomorrowCommitmentStore _commitmentStore() =>
      TomorrowCommitmentStore(AppServices.instance.prefs);

  static Future<ReturnComparison?> loadLatest() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.returnComparisonSample;
    }
    return _comparisonStore().read();
  }

  /// When the user records on the commitment target day, compare and complete.
  static Future<ReturnComparison?> buildAfterSaveIfDue({
    required List<JournalEntry> entries,
    TomorrowReturnLoop? loop,
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    if (entries.isEmpty) return null;

    final clock = now ?? DateTime.now();
    final commitment = await _commitmentStore().read();
    if (commitment == null || !_isDueToday(commitment, clock)) {
      return null;
    }

    final latest = ([
      ...entries,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).first;

    final selection = await ReturnCaptureStore.instance().loadLatest();
    final comparisonHint = selection?.comparisonHint;

    final comparison = const ReturnComparisonEngine().build(
      commitment: commitment,
      entry: latest,
      loop: loop,
      now: clock,
      comparisonHint: comparisonHint,
    );

    await _comparisonStore().write(comparison);
    await _commitmentStore().write(commitment.copyWith(completedAt: clock));
    await ReturnRetentionCoordinator.onComparisonSaved(comparison, now: clock);
    return comparison;
  }

  static bool _isDueToday(TomorrowCommitment commitment, DateTime now) {
    if (commitment.completedAt != null) return false;
    final today = TomorrowCommitment.dateOnly(now);
    final target = TomorrowCommitment.dateOnly(commitment.targetDate);
    return today == target;
  }

  /// Delegates patterns-open acknowledgment to commitment coordinator.
  static Future<void> acknowledgePatternsOpened({DateTime? now}) =>
      TomorrowCommitmentCoordinator.acknowledgePatternsOpened(now: now);
}