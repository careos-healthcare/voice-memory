import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local milestone state for once-per-install beta analytics events.
class BetaAnalyticsMilestoneStore {
  BetaAnalyticsMilestoneStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'beta_analytics_milestones_v1';

  Future<BetaAnalyticsMilestoneState> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) {
      return const BetaAnalyticsMilestoneState();
    }
    return BetaAnalyticsMilestoneState.fromMap(map);
  }

  Future<void> write(BetaAnalyticsMilestoneState state) async {
    await _prefs.writeMap(_key, state.toMap());
  }

  Future<BetaAnalyticsMilestoneState> update(
    BetaAnalyticsMilestoneState Function(BetaAnalyticsMilestoneState current)
    mutate,
  ) async {
    var next = const BetaAnalyticsMilestoneState();
    await _prefs.updateMap(_key, (current) {
      next = mutate(BetaAnalyticsMilestoneState.fromMap(current ?? {}));
      return next.toMap();
    });
    return next;
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}

class BetaAnalyticsMilestoneState {
  const BetaAnalyticsMilestoneState({
    this.emittedOnce = const {},
    this.firstSaveAtUtc,
    this.saveCount = 0,
    this.possiblePatternEligible = false,
  });

  factory BetaAnalyticsMilestoneState.fromMap(Map<String, dynamic> map) {
    final onceRaw = map['emittedOnce'];
    final once = onceRaw is Map
        ? onceRaw.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : const <String, bool>{};

    return BetaAnalyticsMilestoneState(
      emittedOnce: once,
      firstSaveAtUtc: _parseDate(map['firstSaveAtUtc']),
      saveCount: _int(map['saveCount']),
      possiblePatternEligible: map['possiblePatternEligible'] == true,
    );
  }

  final Map<String, bool> emittedOnce;
  final DateTime? firstSaveAtUtc;
  final int saveCount;
  final bool possiblePatternEligible;

  bool hasEmitted(String eventName) => emittedOnce[eventName] == true;

  BetaAnalyticsMilestoneState markEmitted(String eventName) {
    return copyWith(
      emittedOnce: {...emittedOnce, eventName: true},
    );
  }

  BetaAnalyticsMilestoneState copyWith({
    Map<String, bool>? emittedOnce,
    DateTime? firstSaveAtUtc,
    int? saveCount,
    bool? possiblePatternEligible,
  }) {
    return BetaAnalyticsMilestoneState(
      emittedOnce: emittedOnce ?? this.emittedOnce,
      firstSaveAtUtc: firstSaveAtUtc ?? this.firstSaveAtUtc,
      saveCount: saveCount ?? this.saveCount,
      possiblePatternEligible:
          possiblePatternEligible ?? this.possiblePatternEligible,
    );
  }

  Map<String, dynamic> toMap() => {
    'emittedOnce': emittedOnce,
    if (firstSaveAtUtc != null)
      'firstSaveAtUtc': firstSaveAtUtc!.toUtc().toIso8601String(),
    'saveCount': saveCount,
    'possiblePatternEligible': possiblePatternEligible,
  };

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}
