import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for pattern correction — metadata only.
abstract final class PatternCorrectionAnalytics {
  PatternCorrectionAnalytics._();

  static const openedEvent = 'pattern_correction_opened';
  static const reasonSelectedEvent = 'pattern_correction_reason_selected';
  static const actionSelectedEvent = 'pattern_correction_action_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void opened({required String source, required int entryCount}) {
    final props = <String, Object>{'source': source, 'entry_count': entryCount};
    captureForTest?.call(openedEvent, props);
    ActivationFunnelAnalytics.track(
      openedEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_CORRECTION event=$openedEvent source=$source '
        'entry_count=$entryCount',
      );
    }
  }

  static void reasonSelected({
    required String source,
    required int entryCount,
    required PatternCorrectionReason reason,
  }) {
    final reasonType = _reasonKey(reason);
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'reason_type': reasonType,
    };
    captureForTest?.call(reasonSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      reasonSelectedEvent,
      source: source,
      entryCount: entryCount,
      reason: reasonType,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_CORRECTION event=$reasonSelectedEvent source=$source '
        'entry_count=$entryCount reason_type=$reasonType',
      );
    }
  }

  static void actionSelected({
    required String source,
    required int entryCount,
    required PatternCorrectionAction action,
  }) {
    final actionType = _actionKey(action);
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'action_type': actionType,
    };
    captureForTest?.call(actionSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      actionSelectedEvent,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_CORRECTION event=$actionSelectedEvent source=$source '
        'entry_count=$entryCount action_type=$actionType',
      );
    }
  }

  static String _reasonKey(PatternCorrectionReason reason) => switch (reason) {
    PatternCorrectionReason.wrongPattern => 'wrong_pattern',
    PatternCorrectionReason.wrongWording => 'wrong_wording',
    PatternCorrectionReason.tooPersonal => 'too_personal',
    PatternCorrectionReason.doesNotBelong => 'does_not_belong',
    PatternCorrectionReason.notUseful => 'not_useful',
  };

  static String _actionKey(PatternCorrectionAction action) => switch (action) {
    PatternCorrectionAction.renamePattern => 'rename_pattern',
    PatternCorrectionAction.removeFromPattern => 'remove_from_pattern',
    PatternCorrectionAction.correctTranscript => 'correct_transcript',
    PatternCorrectionAction.deleteMoment => 'delete_moment',
    PatternCorrectionAction.privacyCentre => 'privacy_centre',
    PatternCorrectionAction.betaFeedback => 'beta_feedback',
    PatternCorrectionAction.keepRecording => 'keep_recording',
  };

  static String reasonKey(PatternCorrectionReason reason) => _reasonKey(reason);

  static String actionKey(PatternCorrectionAction action) => _actionKey(action);

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}