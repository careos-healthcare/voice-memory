import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../surface_priority/surface_priority_model.dart';
import 'first_run_positioning_copy.dart';
import 'first_run_positioning_model.dart';

/// Metadata-only analytics for first-run revenue positioning.
abstract final class FirstRunPositioningAnalytics {
  FirstRunPositioningAnalytics._();

  static const seenEvent = 'first_run_positioning_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required FirstRunPositioningResult result}) {
    final props = <String, Object>{
      'entry_count': result.entryCount,
      'source': result.source,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_FIRST_RUN_POSITIONING event=$seenEvent '
        'source=${result.source} entry_count=${result.entryCount}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}

/// Early revenue positioning — education only, before first proof.
abstract final class FirstRunPositioningEngine {
  FirstRunPositioningEngine._();

  static const maxEntryCount = 1;

  static FirstRunPositioningResult build({
    required int entryCount,
    required String source,
  }) {
    return FirstRunPositioningResult(
      shouldShow: entryCount <= maxEntryCount,
      title: FirstRunPositioningCopy.title,
      body: FirstRunPositioningCopy.body,
      footer: FirstRunPositioningCopy.footer,
      entryCount: entryCount,
      source: source,
    );
  }

  static bool allowsEducationSlot({
    required SurfacePriorityCardKey? guidanceSlot,
  }) {
    if (guidanceSlot == null) return true;
    return guidanceSlot == SurfacePriorityCardKey.threeMomentCompletion ||
        guidanceSlot == SurfacePriorityCardKey.firstMomentCapture ||
        guidanceSlot == SurfacePriorityCardKey.secondMomentReturn;
  }

  static bool shouldShow({
    required FirstRunPositioningResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofSeen,
    required bool isPermissionBlocked,
    required int entryCount,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (entryCount > maxEntryCount) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofSeen) return false;
    if (isPermissionBlocked) return false;
    return true;
  }
}
