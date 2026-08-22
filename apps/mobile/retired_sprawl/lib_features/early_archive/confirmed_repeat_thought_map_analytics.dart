import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for Thought Map — section ids and surface only.
abstract final class ConfirmedRepeatThoughtMapAnalytics {
  ConfirmedRepeatThoughtMapAnalytics._();

  static const missingPieceTappedEvent =
      'confirmed_repeat_thought_map_missing_piece';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void recordMissingPieceTapped({
    required ThoughtMapSectionId section,
    required String surface,
    required int entryCount,
  }) {
    final props = <String, Object>{
      'section': section.name,
      'surface': surface,
      'entry_count': entryCount,
    };
    captureForTest?.call(missingPieceTappedEvent, props);
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_THOUGHT_MAP event=$missingPieceTappedEvent '
        'section=${section.name} surface=$surface entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}