import '../../storage/mobile_prefs_store.dart';
import 'language_model.dart';

/// Stores the most recent reflection language metadata plus lightweight
/// counters. Kept in its own prefs key so the larger activation schema and the
/// persisted reflection models stay untouched (preserving original text and
/// existing English flows).
class ReflectionLanguageStore {
  ReflectionLanguageStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'reflection_language_state';

  Future<ReflectionLanguageState> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) return const ReflectionLanguageState();
    return ReflectionLanguageState.fromMap(map);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  /// Records a fresh detection. [originalText] is preserved verbatim so the
  /// reflection is never altered by language handling.
  Future<ReflectionLanguageState> recordDetection(
    DetectedLanguage detected, {
    String? originalText,
  }) async {
    final next = await _prefs.updateMap(_key, (current) {
      final state = _state(current);
      final unsupported = !detected.isSupported;
      final fallbackUsed =
          detected.source == LanguageSource.fallback || unsupported;
      return state
          .copyWith(
            languageCode: detected.uiLanguageCode,
            languageConfidence: detected.confidence,
            originalText: originalText ?? state.originalText,
            detectedCount: state.detectedCount + 1,
            unsupportedCount:
                state.unsupportedCount + (unsupported ? 1 : 0),
            fallbackUsedCount:
                state.fallbackUsedCount + (fallbackUsed ? 1 : 0),
          )
          .toMap();
    });
    return ReflectionLanguageState.fromMap(next);
  }

  /// Records a manual override of the reflection language.
  Future<ReflectionLanguageState> recordOverride(String languageCode) async {
    final next = await _prefs.updateMap(_key, (current) {
      return _state(current)
          .copyWith(languageCode: languageCode, languageConfidence: 1.0)
          .toMap();
    });
    return ReflectionLanguageState.fromMap(next);
  }

  ReflectionLanguageState _state(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ReflectionLanguageState();
    return ReflectionLanguageState.fromMap(map);
  }
}

/// Persisted reflection-language metadata and counters.
class ReflectionLanguageState {
  const ReflectionLanguageState({
    this.languageCode = kFallbackLanguageCode,
    this.languageConfidence = 0,
    this.originalText,
    this.detectedCount = 0,
    this.unsupportedCount = 0,
    this.fallbackUsedCount = 0,
  });

  final String languageCode;
  final double languageConfidence;
  final String? originalText;
  final int detectedCount;
  final int unsupportedCount;
  final int fallbackUsedCount;

  ReflectionLanguageState copyWith({
    String? languageCode,
    double? languageConfidence,
    String? originalText,
    int? detectedCount,
    int? unsupportedCount,
    int? fallbackUsedCount,
  }) {
    return ReflectionLanguageState(
      languageCode: languageCode ?? this.languageCode,
      languageConfidence: languageConfidence ?? this.languageConfidence,
      originalText: originalText ?? this.originalText,
      detectedCount: detectedCount ?? this.detectedCount,
      unsupportedCount: unsupportedCount ?? this.unsupportedCount,
      fallbackUsedCount: fallbackUsedCount ?? this.fallbackUsedCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'languageCode': languageCode,
        'languageConfidence': languageConfidence,
        if (originalText != null) 'originalText': originalText,
        'detectedCount': detectedCount,
        'unsupportedCount': unsupportedCount,
        'fallbackUsedCount': fallbackUsedCount,
      };

  factory ReflectionLanguageState.fromMap(Map<String, dynamic> map) {
    return ReflectionLanguageState(
      languageCode: (map['languageCode'] as String?) ?? kFallbackLanguageCode,
      languageConfidence: (map['languageConfidence'] as num?)?.toDouble() ?? 0,
      originalText: map['originalText'] as String?,
      detectedCount: (map['detectedCount'] as num?)?.toInt() ?? 0,
      unsupportedCount: (map['unsupportedCount'] as num?)?.toInt() ?? 0,
      fallbackUsedCount: (map['fallbackUsedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
