import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for entry importance — metadata only, no transcript text.
abstract final class EntryImportanceAnalytics {
  EntryImportanceAnalytics._();

  static const markedEvent = 'entry_importance_marked';
  static const removedEvent = 'entry_importance_removed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void marked({required String source, required int entryCount}) =>
      _emit(markedEvent, source: source, entryCount: entryCount);

  static void removed({required String source, required int entryCount}) =>
      _emit(removedEvent, source: source, entryCount: entryCount);

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
  }) {
    final props = <String, Object>{'source': source, 'entry_count': entryCount};
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_ENTRY_IMPORTANCE event=$event source=$source '
        'entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
