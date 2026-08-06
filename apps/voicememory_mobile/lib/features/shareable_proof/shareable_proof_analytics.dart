import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'shareable_proof_model.dart';

/// Metadata-only analytics for non-private share proof.
abstract final class ShareableProofAnalytics {
  ShareableProofAnalytics._();

  static const seenEvent = 'shareable_proof_seen';
  static const copiedEvent = 'shareable_proof_copied';
  static const sharedEvent = 'shareable_proof_shared';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    required ShareableProofResult result,
    ShareableProofTemplate? template,
  }) {
    _track(
      seenEvent,
      source: source,
      surface: surface,
      result: result,
      template: template ?? result.selectedTemplate,
    );
  }

  static void copied({
    required String source,
    required String surface,
    required ShareableProofResult result,
    required ShareableProofTemplate template,
  }) {
    _track(
      copiedEvent,
      source: source,
      surface: surface,
      result: result,
      template: template,
    );
  }

  static void shared({
    required String source,
    required String surface,
    required ShareableProofResult result,
    required ShareableProofTemplate template,
  }) {
    _track(
      sharedEvent,
      source: source,
      surface: surface,
      result: result,
      template: template,
    );
  }

  static void _track(
    String event, {
    required String source,
    required String surface,
    required ShareableProofResult result,
    required ShareableProofTemplate template,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': result.entryCount,
      'share_template': template.id,
      'has_timeline_proof': result.hasTimelineProof ? 1 : 0,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: result.entryCount,
      surfaceType: surface,
      lineId: template.id,
      hasConfirmedRepeat: result.hasTimelineProof,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_SHAREABLE_PROOF event=$event source=$source surface=$surface '
        'entry_count=${result.entryCount} share_template=${template.id} '
        'has_timeline_proof=${result.hasTimelineProof}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
