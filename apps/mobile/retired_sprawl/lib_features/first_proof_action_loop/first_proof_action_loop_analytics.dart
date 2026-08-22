import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_tracker.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Safe analytics for first proof action loop — metadata only.
abstract final class FirstProofActionLoopAnalytics {
  FirstProofActionLoopAnalytics._();

  static const selectedEvent = 'first_proof_action_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static String actionKey(FirstProofActionType action) => switch (action) {
    FirstProofActionType.watchThisNext => 'watch_this_next',
    FirstProofActionType.viewPatternDetails => 'view_pattern_details',
    FirstProofActionType.renamePattern => 'rename_pattern',
    FirstProofActionType.keepRecording => 'keep_recording',
    FirstProofActionType.correctTranscript => 'correct_transcript',
    FirstProofActionType.removeFromPattern => 'remove_from_pattern',
  };

  static void selected({
    required String source,
    required int entryCount,
    required String answer,
    required FirstProofActionType action,
  }) {
    final actionType = actionKey(action);
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'answer': answer,
      'action_type': actionType,
    };

    captureForTest?.call(selectedEvent, props);
    ActivationFunnelAnalytics.track(
      selectedEvent,
      source: source,
      entryCount: entryCount,
      answer: answer,
      actionType: actionType,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_FIRST_PROOF_ACTION event=$selectedEvent source=$source '
        'entry_count=$entryCount answer=$answer action_type=$actionType',
      );
    }

    unawaited(BetaActivationSummaryTracker.trackFirstProofActionSelected(action));
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}