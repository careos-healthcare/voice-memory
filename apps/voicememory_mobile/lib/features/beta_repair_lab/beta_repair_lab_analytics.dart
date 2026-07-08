import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_repair_lab_copy.dart';
import 'beta_repair_lab_model.dart';

abstract final class BetaRepairLabAnalytics {
  BetaRepairLabAnalytics._();

  static const seenEvent = 'beta_repair_lab_seen';
  static const modeSelectedEvent = 'beta_repair_lab_mode_selected';
  static const modeClearedEvent = 'beta_repair_lab_mode_cleared';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required String source}) {
    _emit(
      seenEvent,
      source: source,
      selectedMode: BetaRepairLabMode.none.analyticsValue,
    );
  }

  static void modeSelected({
    required String source,
    required BetaRepairLabMode selectedMode,
    required BetaRepairLabMode previousMode,
  }) {
    _emit(
      modeSelectedEvent,
      source: source,
      selectedMode: selectedMode.analyticsValue,
      previousMode: previousMode.analyticsValue,
    );
  }

  static void modeCleared({
    required String source,
    required BetaRepairLabMode previousMode,
  }) {
    _emit(
      modeClearedEvent,
      source: source,
      selectedMode: BetaRepairLabMode.none.analyticsValue,
      previousMode: previousMode.analyticsValue,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String selectedMode,
    String? previousMode,
  }) {
    final props = <String, Object>{
      'source': source,
      'selected_mode': selectedMode,
    };
    if (previousMode != null) {
      props['previous_mode'] = previousMode;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_REPAIR_LAB event=$event source=$source '
        'selected_mode=$selectedMode'
        '${previousMode == null ? '' : ' previous_mode=$previousMode'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
