/// Where a [DetectedLanguage] came from.
enum LanguageSource {
  /// Inferred from the reflection text by the lightweight detector.
  heuristic,

  /// Chosen explicitly by the user via the language override.
  userSelected,

  /// Safe default when detection was unclear or the script is unsupported.
  fallback,
}

/// A supported user-facing language for Phase 1 multilingual reflection.
class SupportedLanguage {
  const SupportedLanguage(this.code, this.displayName);

  final String code;
  final String displayName;
}

/// The languages ArchiveMe can adapt user-facing copy into. English is the
/// safe fallback for anything unsupported or unclear.
const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage('en', 'English'),
  SupportedLanguage('es', 'Spanish'),
  SupportedLanguage('fr', 'French'),
  SupportedLanguage('hi', 'Hindi'),
  SupportedLanguage('gu', 'Gujarati'),
];

const String kFallbackLanguageCode = 'en';

/// True when [code] is one of the supported language codes.
bool isSupportedLanguage(String? code) {
  if (code == null) return false;
  for (final lang in kSupportedLanguages) {
    if (lang.code == code) return true;
  }
  return false;
}

/// Human-readable name for a language code, falling back to English.
String languageDisplayName(String? code) {
  for (final lang in kSupportedLanguages) {
    if (lang.code == code) return lang.displayName;
  }
  return 'English';
}

/// Result of detecting the language of a reflection.
class DetectedLanguage {
  const DetectedLanguage({
    required this.code,
    required this.displayName,
    required this.confidence,
    required this.isSupported,
    required this.source,
  });

  /// English fallback, used when detection is unclear or the script is unknown.
  const DetectedLanguage.fallback({
    this.code = kFallbackLanguageCode,
    this.displayName = 'English',
    this.confidence = 0.0,
    this.isSupported = true,
    this.source = LanguageSource.fallback,
  });

  /// A user-chosen language override.
  factory DetectedLanguage.userSelected(String code) {
    return DetectedLanguage(
      code: code,
      displayName: languageDisplayName(code),
      confidence: 1,
      isSupported: isSupportedLanguage(code),
      source: LanguageSource.userSelected,
    );
  }

  final String code;
  final String displayName;
  final double confidence;
  final bool isSupported;
  final LanguageSource source;

  /// True when the detected language is anything other than English.
  bool get isNonEnglish => code != kFallbackLanguageCode;

  /// True when confidence is too low to trust the detection.
  bool get isLowConfidence => confidence < 0.3;

  /// The language code used to render UI: supported codes pass through,
  /// everything else falls back to English.
  String get uiLanguageCode => isSupported ? code : kFallbackLanguageCode;

  DetectedLanguage copyWith({
    String? code,
    String? displayName,
    double? confidence,
    bool? isSupported,
    LanguageSource? source,
  }) {
    return DetectedLanguage(
      code: code ?? this.code,
      displayName: displayName ?? this.displayName,
      confidence: confidence ?? this.confidence,
      isSupported: isSupported ?? this.isSupported,
      source: source ?? this.source,
    );
  }
}