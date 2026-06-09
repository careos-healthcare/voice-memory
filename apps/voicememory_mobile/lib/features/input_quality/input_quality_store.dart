import '../../storage/mobile_prefs_store.dart';
import 'input_quality_model.dart';

/// Local snapshot of recent reflection quality, used for trial summary and to
/// coach toward clearer moments. Stored as a single map for QA visibility.
class InputQualityStore {
  InputQualityStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'input_quality_state';

  Future<InputQualityState> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) return const InputQualityState();
    return InputQualityState.fromMap(map);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  /// Records a fresh assessment, updating the latest level/score/issues and the
  /// running average score.
  Future<InputQualityState> recordAssessment(InputQualityResult result) async {
    final next = await _prefs.updateMap(_key, (current) {
      final state = _state(current).withAssessment(result);
      return state.toMap();
    });
    return InputQualityState.fromMap(next);
  }

  /// Records that the user added a sharpening sentence.
  Future<InputQualityState> recordSharpened() async {
    final next = await _prefs.updateMap(_key, (current) {
      final state = _state(current);
      return state
          .copyWith(sharpenedInputCount: state.sharpenedInputCount + 1)
          .toMap();
    });
    return InputQualityState.fromMap(next);
  }

  /// Records that the user kept weak input despite coaching.
  Future<InputQualityState> recordAcceptedWeak() async {
    final next = await _prefs.updateMap(_key, (current) {
      final state = _state(current);
      return state
          .copyWith(acceptedWeakInputCount: state.acceptedWeakInputCount + 1)
          .toMap();
    });
    return InputQualityState.fromMap(next);
  }

  InputQualityState _state(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const InputQualityState();
    return InputQualityState.fromMap(map);
  }
}

/// Persisted input-quality metadata.
class InputQualityState {
  const InputQualityState({
    this.lastQualityLevel,
    this.lastScore = 0,
    this.lastIssues = const [],
    this.acceptedWeakInputCount = 0,
    this.sharpenedInputCount = 0,
    this.scoreSum = 0,
    this.assessmentCount = 0,
  });

  final InputQualityLevel? lastQualityLevel;
  final double lastScore;
  final List<InputQualityIssue> lastIssues;
  final int acceptedWeakInputCount;
  final int sharpenedInputCount;
  final double scoreSum;
  final int assessmentCount;

  double? get averageInputQualityScore =>
      assessmentCount == 0 ? null : scoreSum / assessmentCount;

  InputQualityState withAssessment(InputQualityResult result) {
    return copyWith(
      lastQualityLevel: result.level,
      lastScore: result.score,
      lastIssues: result.issues,
      scoreSum: scoreSum + result.score,
      assessmentCount: assessmentCount + 1,
    );
  }

  InputQualityState copyWith({
    InputQualityLevel? lastQualityLevel,
    double? lastScore,
    List<InputQualityIssue>? lastIssues,
    int? acceptedWeakInputCount,
    int? sharpenedInputCount,
    double? scoreSum,
    int? assessmentCount,
  }) {
    return InputQualityState(
      lastQualityLevel: lastQualityLevel ?? this.lastQualityLevel,
      lastScore: lastScore ?? this.lastScore,
      lastIssues: lastIssues ?? this.lastIssues,
      acceptedWeakInputCount:
          acceptedWeakInputCount ?? this.acceptedWeakInputCount,
      sharpenedInputCount: sharpenedInputCount ?? this.sharpenedInputCount,
      scoreSum: scoreSum ?? this.scoreSum,
      assessmentCount: assessmentCount ?? this.assessmentCount,
    );
  }

  Map<String, dynamic> toMap() => {
        if (lastQualityLevel != null) 'lastQualityLevel': lastQualityLevel!.name,
        'lastScore': lastScore,
        'lastIssues': lastIssues.map((i) => i.name).toList(),
        'acceptedWeakInputCount': acceptedWeakInputCount,
        'sharpenedInputCount': sharpenedInputCount,
        'scoreSum': scoreSum,
        'assessmentCount': assessmentCount,
      };

  factory InputQualityState.fromMap(Map<String, dynamic> map) {
    return InputQualityState(
      lastQualityLevel: _levelFromName(map['lastQualityLevel'] as String?),
      lastScore: (map['lastScore'] as num?)?.toDouble() ?? 0,
      lastIssues: ((map['lastIssues'] as List?) ?? const [])
          .map((e) => _issueFromName(e.toString()))
          .whereType<InputQualityIssue>()
          .toList(),
      acceptedWeakInputCount:
          (map['acceptedWeakInputCount'] as num?)?.toInt() ?? 0,
      sharpenedInputCount: (map['sharpenedInputCount'] as num?)?.toInt() ?? 0,
      scoreSum: (map['scoreSum'] as num?)?.toDouble() ?? 0,
      assessmentCount: (map['assessmentCount'] as num?)?.toInt() ?? 0,
    );
  }

  static InputQualityLevel? _levelFromName(String? name) {
    if (name == null) return null;
    for (final level in InputQualityLevel.values) {
      if (level.name == name) return level;
    }
    return null;
  }

  static InputQualityIssue? _issueFromName(String name) {
    for (final issue in InputQualityIssue.values) {
      if (issue.name == name) return issue;
    }
    return null;
  }
}
