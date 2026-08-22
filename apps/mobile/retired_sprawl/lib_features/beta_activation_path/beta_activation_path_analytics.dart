import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/beta_activation_path/beta_activation_path_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Metadata-only analytics for beta activation path cards.
abstract final class BetaActivationPathAnalytics {
  BetaActivationPathAnalytics._();

  static const seenEvent = 'beta_activation_path_seen';
  static const ctaTappedEvent = 'beta_activation_path_cta_tapped';
  static const dismissedEvent = 'beta_activation_path_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required BetaActivationPathResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({
    required BetaActivationPathResult result,
    required BetaActivationPathActionType actionType,
  }) {
    _emit(ctaTappedEvent, result: result, actionType: actionType);
  }

  static void dismissed({required BetaActivationPathResult result}) {
    _emit(
      dismissedEvent,
      result: result,
      actionType: result.secondaryActionType,
    );
  }

  static void _emit(
    String event, {
    required BetaActivationPathResult result,
    BetaActivationPathActionType? actionType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'stage': result.stage.analyticsValue,
      'entry_count': result.entryCount,
      'has_useful_proof': result.hasUsefulProof ? 1 : 0,
      'has_timeline_proof': result.hasTimelineProof ? 1 : 0,
      'has_paywall_seen': result.hasPaywallSeen ? 1 : 0,
    };
    if (actionType != null) {
      props['action_type'] = actionType.analyticsValue;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_BETA_ACTIVATION_PATH event=$event source=${result.source} '
        'stage=${result.stage.analyticsValue} entry_count=${result.entryCount} '
        'has_useful_proof=${result.hasUsefulProof} '
        'has_timeline_proof=${result.hasTimelineProof} '
        'has_paywall_seen=${result.hasPaywallSeen}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}