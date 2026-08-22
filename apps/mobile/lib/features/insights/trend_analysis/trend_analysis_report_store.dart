import 'dart:convert';

import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists the latest generated weekly self-reflection reports per window.
class TrendAnalysisReportStore {
  TrendAnalysisReportStore(this._prefs);

  static const _keyPrefix = 'trend_analysis_report_v1_';

  final MobilePrefsStore _prefs;

  Future<void> save(WeeklySelfReflectionReport report) {
    return _prefs.writeString(
      '$_keyPrefix${report.window.storageKey}',
      jsonEncode(report.toJson()),
    );
  }

  Future<WeeklySelfReflectionReport?> load(TrendAnalysisWindow window) async {
    final raw = await _prefs.readString('$_keyPrefix${window.storageKey}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return WeeklySelfReflectionReport.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> clear(TrendAnalysisWindow window) {
    return _prefs.writeString('$_keyPrefix${window.storageKey}', '');
  }
}
