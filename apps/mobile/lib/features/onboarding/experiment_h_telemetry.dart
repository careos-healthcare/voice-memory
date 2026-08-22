import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/events/archive_event.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_events.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_feature_flags.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:meta/meta.dart';

/// Persists Experiment H exposure for retention / paywall cohort analysis.
abstract final class ExperimentHTelemetry {
  ExperimentHTelemetry._();

  static const _cohortKey = 'experiment_h_cohort_v1';

  static Future<void> trackShown({required String source}) async {
    if (!ExperimentHFeatureFlags.isEnabled) return;
    await _markExposed(source: source);
    await ActivationTracker.trackEvent(
      ArchiveEvent(
        ExperimentHEvents.onboardingShown,
        payload: {'source': source, 'cohort': 'experiment_h'},
      ),
    );
  }

  static Future<void> trackToggleInteracted({
    required bool showingChatComparison,
  }) async {
    if (!ExperimentHFeatureFlags.isEnabled) return;
    await ActivationTracker.trackEvent(
      ArchiveEvent(
        ExperimentHEvents.toggleInteracted,
        payload: {
          'showing_chat_comparison': showingChatComparison.toString(),
          'cohort': await cohortTag(),
        },
      ),
    );
  }

  static Future<void> trackFirstInsightVerified({
    required String entryId,
  }) async {
    if (!ExperimentHFeatureFlags.isEnabled) return;
    await ActivationTracker.trackEvent(
      ArchiveEvent(
        ExperimentHEvents.firstInsightVerified,
        payload: {
          'entry_id': entryId,
          'cohort': await cohortTag(),
        },
      ),
    );
  }

  /// Tags downstream D1/D7 / paywall analytics when user was in Experiment H.
  static Future<String> cohortTag() async {
    if (!AppServices.isInitialized) return 'baseline';
    final raw = await AppServices.instance.prefs.readMap(_cohortKey);
    if (raw?['exposed'] == true) return 'experiment_h';
    return 'baseline';
  }

  static Future<void> _markExposed({required String source}) async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    final existing = await prefs.readMap(_cohortKey);
    if (existing?['exposed'] == true) return;
    await prefs.writeMap(_cohortKey, {
      'exposed': true,
      'source': source,
      'exposedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore prefs) async {
    await prefs.writeMap(_cohortKey, {'exposed': false});
  }
}