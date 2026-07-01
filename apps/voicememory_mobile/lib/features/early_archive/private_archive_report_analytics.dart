import 'package:flutter/foundation.dart';

import 'private_archive_report_model.dart';

/// Safe analytics for private archive report — metadata only.
abstract final class PrivateArchiveReportAnalytics {
  PrivateArchiveReportAnalytics._();

  static const seenEvent = 'private_archive_report_seen';
  static const copyEvent = 'private_archive_report_copy';
  static const shareEvent = 'private_archive_report_share';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String surface,
    required int entryCount,
    required bool isFullExport,
  }) {
    _emit(
      seenEvent,
      surface: surface,
      entryCount: entryCount,
      exportTier: isFullExport ? 'full' : 'preview',
    );
  }

  static void copyTapped({
    required String surface,
    required int entryCount,
    required bool isFullExport,
  }) {
    _emit(
      copyEvent,
      surface: surface,
      entryCount: entryCount,
      exportTier: isFullExport ? 'full' : 'preview',
    );
  }

  static void shareTapped({
    required String surface,
    required int entryCount,
    required bool isFullExport,
  }) {
    _emit(
      shareEvent,
      surface: surface,
      entryCount: entryCount,
      exportTier: isFullExport ? 'full' : 'preview',
    );
  }

  static void _emit(
    String event, {
    required String surface,
    required int entryCount,
    required String exportTier,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
      'export_tier': exportTier,
    };
    captureForTest?.call(event, props);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRIVATE_ARCHIVE_REPORT event=$event surface=$surface '
        'entry_count=$entryCount export_tier=$exportTier',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
