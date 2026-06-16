import 'language_model.dart';

/// Lightweight, on-device reflection language detection.
///
/// Phase 1 uses only cheap heuristics — script ranges plus a small set of
/// common words — with no external APIs. Anything unclear or unsupported
/// falls back safely to English so existing flows never break.
DetectedLanguage detectReflectionLanguage(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const DetectedLanguage.fallback();
  }

  // 1) Script detection wins outright — Gujarati/Devanagari are unambiguous.
  final scriptHit = _detectByScript(trimmed);
  if (scriptHit != null) return scriptHit;

  // 2) Common-word detection for Latin-script languages.
  final tokens = _tokenize(trimmed);
  final esHits = _countHits(tokens, _spanishWords);
  final frHits = _countHits(tokens, _frenchWords);

  if (esHits == 0 && frHits == 0) {
    return _englishResult(tokens.length);
  }

  // Both languages matched equally — treat as mixed/unclear, fall back.
  if (esHits == frHits) {
    return const DetectedLanguage.fallback();
  }

  final isSpanish = esHits > frHits;
  final hits = isSpanish ? esHits : frHits;
  return DetectedLanguage(
    code: isSpanish ? 'es' : 'fr',
    displayName: isSpanish ? 'Spanish' : 'French',
    confidence: _wordConfidence(hits, tokens.length),
    isSupported: true,
    source: LanguageSource.heuristic,
  );
}

/// Returns a script-based detection, or null when no supported script is found.
DetectedLanguage? _detectByScript(String text) {
  var gujarati = 0;
  var devanagari = 0;
  for (final rune in text.runes) {
    if (rune >= 0x0A80 && rune <= 0x0AFF) {
      gujarati++;
    } else if (rune >= 0x0900 && rune <= 0x097F) {
      devanagari++;
    }
  }
  if (gujarati == 0 && devanagari == 0) return null;

  if (gujarati >= devanagari) {
    return const DetectedLanguage(
      code: 'gu',
      displayName: 'Gujarati',
      confidence: 0.95,
      isSupported: true,
      source: LanguageSource.heuristic,
    );
  }
  return const DetectedLanguage(
    code: 'hi',
    displayName: 'Hindi',
    confidence: 0.95,
    isSupported: true,
    source: LanguageSource.heuristic,
  );
}

/// English is the default. Very short, unclear text gets low confidence so the
/// UI can stay quiet rather than claiming a confident read.
DetectedLanguage _englishResult(int tokenCount) {
  final confidence = tokenCount >= 4 ? 0.6 : 0.2;
  return DetectedLanguage(
    code: 'en',
    displayName: 'English',
    confidence: confidence,
    isSupported: true,
    source: confidence < 0.3
        ? LanguageSource.fallback
        : LanguageSource.heuristic,
  );
}

double _wordConfidence(int hits, int tokenCount) {
  if (hits >= 2) return 0.8;
  // A single hit in a short phrase is medium; in a long phrase it is weaker.
  return tokenCount <= 6 ? 0.55 : 0.45;
}

List<String> _tokenize(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'''[\s,.!?;:"()\[\]{}\-\u2019']+'''))
      .where((t) => t.isNotEmpty)
      .toList();
}

int _countHits(List<String> tokens, Set<String> words) {
  var hits = 0;
  for (final token in tokens) {
    if (words.contains(token)) hits++;
  }
  return hits;
}

const Set<String> _spanishWords = {
  'que',
  'porque',
  'estoy',
  'siento',
  'ayer',
  'hoy',
  'mañana',
  'trabajo',
  'preocupado',
  'preocupada',
  'cansado',
  'cansada',
  'pero',
  'siempre',
  'nada',
};

const Set<String> _frenchWords = {
  'je',
  'suis',
  'parce',
  'aujourd',
  'demain',
  'travail',
  'inquiet',
  'inquiète',
  'fatigué',
  'fatiguée',
  'hier',
  'toujours',
  'pourquoi',
};
