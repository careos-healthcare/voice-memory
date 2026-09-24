import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persisted ranking / RAG knobs shown only after the matching milestone.
final class AdvancedSearchSettings {
  const AdvancedSearchSettings({
    this.rrfK = defaultRrfK,
    this.candidateLimit = defaultCandidateLimit,
    this.ragChunkLimit = defaultRagChunkLimit,
  });

  static const defaultRrfK = 60;
  static const defaultCandidateLimit = 50;
  static const defaultRagChunkLimit = 6;

  static const rrfKMin = 20;
  static const rrfKMax = 120;
  static const candidateLimitMin = 20;
  static const candidateLimitMax = 100;
  static const ragChunkLimitMin = 2;
  static const ragChunkLimitMax = 16;

  final int rrfK;
  final int candidateLimit;
  final int ragChunkLimit;

  AdvancedSearchSettings copyWith({
    int? rrfK,
    int? candidateLimit,
    int? ragChunkLimit,
  }) {
    return AdvancedSearchSettings(
      rrfK: rrfK ?? this.rrfK,
      candidateLimit: candidateLimit ?? this.candidateLimit,
      ragChunkLimit: ragChunkLimit ?? this.ragChunkLimit,
    );
  }

  Map<String, dynamic> toJson() => {
    'rrfK': rrfK,
    'candidateLimit': candidateLimit,
    'ragChunkLimit': ragChunkLimit,
  };

  factory AdvancedSearchSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const AdvancedSearchSettings();
    }
    return AdvancedSearchSettings(
      rrfK: _clampInt(json['rrfK'], defaultRrfK, rrfKMin, rrfKMax),
      candidateLimit: _clampInt(
        json['candidateLimit'],
        defaultCandidateLimit,
        candidateLimitMin,
        candidateLimitMax,
      ),
      ragChunkLimit: _clampInt(
        json['ragChunkLimit'],
        defaultRagChunkLimit,
        ragChunkLimitMin,
        ragChunkLimitMax,
      ),
    );
  }

  static int _clampInt(Object? raw, int fallback, int min, int max) {
    final value = raw is int ? raw : (raw is num ? raw.toInt() : fallback);
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// Prefs-backed store for [AdvancedSearchSettings].
class AdvancedSearchSettingsStore {
  AdvancedSearchSettingsStore(this._prefs);

  static const prefsKey = 'advanced_search_settings_v1';

  final MobilePrefsStore _prefs;

  Future<AdvancedSearchSettings> load() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    return AdvancedSearchSettings.fromJson(raw);
  }

  Future<AdvancedSearchSettings> save(AdvancedSearchSettings settings) async {
    await _prefs.writeJsonMap(prefsKey, settings.toJson());
    return settings;
  }

  /// Persisted knobs only after the matching milestone; otherwise defaults.
  Future<AdvancedSearchSettings> loadIfUnlocked({
    required UserMilestoneSnapshot snapshot,
    required ProgressiveSurface surface,
  }) async {
    if (!snapshot.isUnlocked(surface)) {
      return const AdvancedSearchSettings();
    }
    return load();
  }
}
