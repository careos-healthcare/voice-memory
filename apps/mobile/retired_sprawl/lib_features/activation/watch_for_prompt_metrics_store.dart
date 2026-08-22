import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local counts for tomorrow watch-for prompt funnel quality.
class WatchForPromptMetricsStore {
  WatchForPromptMetricsStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'activation_watch_for_prompt_metrics';

  Future<WatchForPromptMetrics> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) {
      return const WatchForPromptMetrics();
    }
    return WatchForPromptMetrics(
      shownCount: (map['shownCount'] as num?)?.toInt() ?? 0,
      acceptedCount: (map['acceptedCount'] as num?)?.toInt() ?? 0,
      lowStrengthAccepted: (map['lowStrengthAccepted'] as num?)?.toInt() ?? 0,
      mediumStrengthAccepted:
          (map['mediumStrengthAccepted'] as num?)?.toInt() ?? 0,
      highStrengthAccepted: (map['highStrengthAccepted'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> recordShown({required String strength}) async {
    final current = await read();
    await _write(
      WatchForPromptMetrics(
        shownCount: current.shownCount + 1,
        acceptedCount: current.acceptedCount,
        lowStrengthAccepted: current.lowStrengthAccepted,
        mediumStrengthAccepted: current.mediumStrengthAccepted,
        highStrengthAccepted: current.highStrengthAccepted,
      ),
    );
  }

  Future<void> recordAccepted({required String strength}) async {
    final current = await read();
    var low = current.lowStrengthAccepted;
    var medium = current.mediumStrengthAccepted;
    var high = current.highStrengthAccepted;
    switch (strength) {
      case 'high':
        high++;
      case 'medium':
        medium++;
      default:
        low++;
    }
    await _write(
      WatchForPromptMetrics(
        shownCount: current.shownCount,
        acceptedCount: current.acceptedCount + 1,
        lowStrengthAccepted: low,
        mediumStrengthAccepted: medium,
        highStrengthAccepted: high,
      ),
    );
  }

  Future<void> _write(WatchForPromptMetrics metrics) async {
    await _prefs.writeMap(_key, {
      'shownCount': metrics.shownCount,
      'acceptedCount': metrics.acceptedCount,
      'lowStrengthAccepted': metrics.lowStrengthAccepted,
      'mediumStrengthAccepted': metrics.mediumStrengthAccepted,
      'highStrengthAccepted': metrics.highStrengthAccepted,
    });
  }
}

class WatchForPromptMetrics {
  const WatchForPromptMetrics({
    this.shownCount = 0,
    this.acceptedCount = 0,
    this.lowStrengthAccepted = 0,
    this.mediumStrengthAccepted = 0,
    this.highStrengthAccepted = 0,
  });

  final int shownCount;
  final int acceptedCount;
  final int lowStrengthAccepted;
  final int mediumStrengthAccepted;
  final int highStrengthAccepted;

  double? get acceptanceRate =>
      shownCount == 0 ? null : acceptedCount / shownCount;
}