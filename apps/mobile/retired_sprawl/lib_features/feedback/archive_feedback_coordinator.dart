import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_store.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Saves quick feedback on ArchiveMe output and loads a gentle summary for
/// future checks. Always fails softly — feedback must never block the loop.
abstract class ArchiveFeedbackCoordinator {
  ArchiveFeedbackCoordinator._();

  static ArchiveFeedbackStore _store() => ArchiveFeedbackStore.instance();

  /// Tracks that a feedback row was shown. Safe to call more than once.
  static void trackFeedbackShown() {
    ActivationTracker.trackArchiveFeedbackShown();
  }

  static Future<void> saveFeedback({
    required ArchiveFeedbackType type,
    required ArchiveFeedbackTargetType targetType,
    String? targetId,
    String? patternTitle,
    String? resultHint,
    String? languageCode,
    String? id,
    DateTime? createdAt,
  }) async {
    if (!AppServices.isInitialized) return;
    try {
      final feedback = ArchiveFeedback(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        targetType: targetType,
        createdAt: createdAt ?? DateTime.now(),
        targetId: targetId,
        patternTitle: patternTitle,
        resultHint: resultHint,
        languageCode: languageCode,
      );
      await _store().save(feedback);
      ActivationTracker.trackArchiveFeedbackSelected(type);
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Best-effort only.
    }
  }

  static Future<ArchiveFeedbackSummary> loadSummary() async {
    if (!AppServices.isInitialized) return ArchiveFeedbackSummary.empty;
    try {
      return await _store().summary();
    } catch (_, stackTrace) {
      return ArchiveFeedbackSummary.empty;
    }
  }

  static Future<ArchiveFeedbackType?> latestDominantIssue() async {
    return (await loadSummary()).dominantIssue;
  }
}