import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local counts for return-day quick-answer capture quality.
class ReturnCaptureMetricsStore {
  ReturnCaptureMetricsStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'activation_return_capture_metrics';

  Future<ReturnCaptureMetrics> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) {
      return const ReturnCaptureMetrics();
    }
    return ReturnCaptureMetrics(
      quickAnswerSelectedCount:
          (map['quickAnswerSelectedCount'] as num?)?.toInt() ?? 0,
      recordedAfterQuickAnswerCount:
          (map['recordedAfterQuickAnswerCount'] as num?)?.toInt() ?? 0,
      skippedCount: (map['skippedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> recordQuickAnswerSelected() async {
    final current = await read();
    await _write(
      ReturnCaptureMetrics(
        quickAnswerSelectedCount: current.quickAnswerSelectedCount + 1,
        recordedAfterQuickAnswerCount: current.recordedAfterQuickAnswerCount,
        skippedCount: current.skippedCount,
      ),
    );
  }

  Future<void> recordRecordedAfterQuickAnswer() async {
    final current = await read();
    await _write(
      ReturnCaptureMetrics(
        quickAnswerSelectedCount: current.quickAnswerSelectedCount,
        recordedAfterQuickAnswerCount:
            current.recordedAfterQuickAnswerCount + 1,
        skippedCount: current.skippedCount,
      ),
    );
  }

  Future<void> recordSkipped() async {
    final current = await read();
    await _write(
      ReturnCaptureMetrics(
        quickAnswerSelectedCount: current.quickAnswerSelectedCount,
        recordedAfterQuickAnswerCount: current.recordedAfterQuickAnswerCount,
        skippedCount: current.skippedCount + 1,
      ),
    );
  }

  Future<void> _write(ReturnCaptureMetrics metrics) async {
    await _prefs.writeMap(_key, {
      'quickAnswerSelectedCount': metrics.quickAnswerSelectedCount,
      'recordedAfterQuickAnswerCount': metrics.recordedAfterQuickAnswerCount,
      'skippedCount': metrics.skippedCount,
    });
  }
}

class ReturnCaptureMetrics {
  const ReturnCaptureMetrics({
    this.quickAnswerSelectedCount = 0,
    this.recordedAfterQuickAnswerCount = 0,
    this.skippedCount = 0,
  });

  final int quickAnswerSelectedCount;
  final int recordedAfterQuickAnswerCount;
  final int skippedCount;

  /// Selected / (selected + skipped) when user dismisses without answering.
  double? get quickAnswerSelectionRate {
    final denom = quickAnswerSelectedCount + skippedCount;
    if (denom == 0) return null;
    return quickAnswerSelectedCount / denom;
  }

  /// Recorded after selecting a quick answer / selections made.
  double? get recordedAfterQuickAnswerRate {
    if (quickAnswerSelectedCount == 0) return null;
    return recordedAfterQuickAnswerCount / quickAnswerSelectedCount;
  }
}