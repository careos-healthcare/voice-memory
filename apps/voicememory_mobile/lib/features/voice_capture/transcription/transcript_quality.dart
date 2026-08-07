/// Validates whether server transcription text is usable evidence.
abstract class TranscriptQuality {
  TranscriptQuality._();

  static const int minAlphabeticCharacters = 8;
  static const int minWordCount = 2;
  static const int minSingleWordLetters = 8;

  static const Set<String> _blockedExactPhrases = {
    '...',
    '.',
    '..',
    '—',
    '-',
    'um',
    'uh',
    'erm',
    'hmm',
  };

  static TranscriptQualityVerdict evaluate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const TranscriptQualityVerdict.invalid(
        normalized: '',
        reason: 'empty',
      );
    }

    final lower = normalized.toLowerCase();
    if (_blockedExactPhrases.contains(lower)) {
      return TranscriptQualityVerdict.invalid(
        normalized: normalized,
        reason: 'blocked_phrase',
      );
    }

    if (_isPunctuationOnly(normalized)) {
      return TranscriptQualityVerdict.invalid(
        normalized: normalized,
        reason: 'punctuation_only',
      );
    }

    final alphabeticCount = _alphabeticCharacterCount(normalized);
    if (alphabeticCount < minAlphabeticCharacters) {
      return TranscriptQualityVerdict.invalid(
        normalized: normalized,
        reason: 'too_few_letters',
      );
    }

    final words = _realWords(normalized);
    if (words.length < minWordCount && !_isClearlyMeaningfulSingleWord(words)) {
      return TranscriptQualityVerdict.invalid(
        normalized: normalized,
        reason: 'too_few_words',
      );
    }

    return TranscriptQualityVerdict.valid(normalized: normalized);
  }

  static bool isUsableEvidence(String? raw) => evaluate(raw ?? '').isValid;

  static bool _isPunctuationOnly(String text) {
    final withoutWhitespaceAndPunctuation = text.replaceAll(
      RegExp(r'[\s\p{P}\p{S}]', unicode: true),
      '',
    );
    return withoutWhitespaceAndPunctuation.isEmpty;
  }

  static int _alphabeticCharacterCount(String text) {
    return RegExp(r'[A-Za-z]').allMatches(text).length;
  }

  static List<String> _realWords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s\-—]+'))
        .map((word) => word.replaceAll(RegExp(r"[^\w']"), ''))
        .where((word) => word.replaceAll(RegExp(r'[^a-z]'), '').isNotEmpty)
        .toList();
  }

  static bool _isClearlyMeaningfulSingleWord(List<String> words) {
    if (words.length != 1) return false;
    return _alphabeticCharacterCount(words.first) >= minSingleWordLetters;
  }
}

class TranscriptQualityVerdict {
  const TranscriptQualityVerdict.valid({required this.normalized})
    : isValid = true,
      reason = null;

  const TranscriptQualityVerdict.invalid({
    required this.normalized,
    required this.reason,
  }) : isValid = false;

  final String normalized;
  final bool isValid;
  final String? reason;
}
