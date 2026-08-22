import 'package:archiveme_mobile/features/archive_evidence/archive_pattern_copy_guard.dart';

/// Cleans and humanizes repeated phrase copy for archive repeat surfaces.
abstract final class ArchiveRepeatPhraseSanitizer {
  ArchiveRepeatPhraseSanitizer._();

  static bool _isBlocked(String phrase) =>
      ArchivePatternCopyGuard.isBlockedPatternText(phrase);

  static const _trailingConnectors = {
    'and',
    'but',
    'or',
    'because',
    'to',
    'with',
    'if',
    'when',
    'as',
    'so',
  };

  static const _leadingWeakStarts = {
    'is',
    'to',
    'if',
    'a',
    'an',
    'the',
    'it',
    'this',
    'that',
    'and',
    'or',
    'but',
  };

  /// Normalizes a phrase for comparison and display.
  static String sanitize(String phrase) {
    var normalized = phrase
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    while (normalized.isNotEmpty) {
      final words = normalized.split(' ');
      if (words.isEmpty) break;
      if (_trailingConnectors.contains(words.last)) {
        words.removeLast();
        normalized = words.join(' ').trim();
        continue;
      }
      break;
    }

    return normalized;
  }

  /// True when a phrase is too fragmentary for a summary line.
  static bool isLowQuality(String phrase) {
    final cleaned = sanitize(phrase);
    if (_isBlocked(cleaned)) return true;
    if (cleaned.length < 5) return true;

    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return true;
    if (_trailingConnectors.contains(words.last)) return true;
    if (_leadingWeakStarts.contains(words.first) &&
        !_priorityThemes.any(cleaned.contains)) {
      return true;
    }
    if (words.every((w) => _leadingWeakStarts.contains(w) || w == 'test')) {
      return true;
    }
    return false;
  }

  /// Removes near-duplicate fragments, preferring the cleaner/longer phrase.
  static List<String> dedupeNearIdentical(List<String> phrases) {
    final cleaned = phrases
        .map(sanitize)
        .where((p) => p.isNotEmpty && !isLowQuality(p))
        .toList();
    if (cleaned.isEmpty) return const [];

    cleaned.sort((a, b) => b.length.compareTo(a.length));

    final kept = <String>[];
    for (final phrase in cleaned) {
      final duplicate = kept.any(
        (existing) =>
            existing == phrase ||
            existing.contains(phrase) ||
            phrase.contains(existing) ||
            _overlapRatio(existing, phrase) >= 0.75,
      );
      if (!duplicate) kept.add(phrase);
    }
    return kept;
  }

  /// Builds a natural repeat summary from saved text and shared phrases.
  static String buildRepeatSummary({
    required List<String> texts,
    required List<String> sharedPhrases,
    bool lowerConfidence = false,
  }) {
    final blob = texts.join(' ').toLowerCase();

    if (_hasSayingYesPressure(blob)) {
      if (lowerConfidence) {
        return 'These moments may be connected by pressure around saying yes.';
      }
      if (_hasWantedToSayNo(blob)) {
        return 'Both moments point to pressure around saying yes when you wanted to step back.';
      }
      return 'Both moments point to pressure around saying yes when you had no capacity.';
    }

    if (_hasWantedToSayNo(blob)) {
      if (lowerConfidence) {
        return 'These moments may be connected by wanting to say no before agreeing.';
      }
      return 'Both moments point to wanting to say no before agreeing.';
    }

    if (_hasWorkPressure(blob)) {
      return 'Both moments point to work pressure showing up in what you said.';
    }

    if (_hasAgreeingPressure(blob)) {
      return 'Both moments point to the same pressure around agreeing when part of you wanted to stop.';
    }

    final deduped = dedupeNearIdentical(sharedPhrases);
    if (deduped.isEmpty) {
      if (lowerConfidence) {
        return 'These moments may be connected by a similar pressure in what you said.';
      }
      return 'Both moments point to the same pressure around agreeing when part of you wanted to stop.';
    }

    final primary = _humanizePhrase(deduped.first);
    if (deduped.length == 1 || _phrasesTooSimilar(deduped.first, deduped[1])) {
      return 'Both moments point to $primary.';
    }

    if (lowerConfidence) {
      return 'These moments may be connected by $primary.';
    }
    return 'Both moments point to $primary.';
  }

  /// Evidence line with exact saved wording only — never joined fragments.
  static String buildEvidenceLine(List<String> quotes) {
    final cleaned = quotes
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty && !_isBlocked(q))
        .map((q) => q.replaceAll(RegExp(r'\s+'), ' '))
        .toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) {
      return 'Your words: "${cleaned.first}".';
    }
    return 'Your words: "${cleaned.first}" and "${cleaned[1]}".';
  }

  static bool endsWithConnector(String phrase) {
    final words = phrase
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.isNotEmpty && _trailingConnectors.contains(words.last);
  }

  static const _priorityThemes = [
    'said yes',
    'no capacity',
    'work pressure',
    'wanted to say no',
    'say no',
  ];

  static bool _hasSayingYesPressure(String blob) =>
      blob.contains('said yes') ||
      blob.contains('say yes') ||
      blob.contains('no capacity') ||
      (blob.contains('agree') && blob.contains('capacity'));

  static bool _hasWantedToSayNo(String blob) =>
      blob.contains('wanted to say no') ||
      blob.contains('want to say no') ||
      (blob.contains('say no') && blob.contains('but'));

  static bool _hasWorkPressure(String blob) =>
      blob.contains('work pressure') ||
      (blob.contains('work') &&
          (blob.contains('pressure') || blob.contains('deadline')));

  static bool _hasAgreeingPressure(String blob) =>
      blob.contains('agree') || blob.contains('agreed') || blob.contains('yes');

  static String _humanizePhrase(String phrase) {
    final cleaned = sanitize(phrase);
    if (cleaned.contains('said yes') && cleaned.contains('capacity')) {
      return 'pressure around saying yes when you had no capacity';
    }
    if (cleaned.contains('said yes') || cleaned == 'say yes') {
      return 'pressure around saying yes when you had no capacity';
    }
    if (cleaned.contains('wanted to say no') || cleaned.contains('say no')) {
      return 'wanting to say no before agreeing';
    }
    if (cleaned.contains('work') && cleaned.contains('pressure')) {
      return 'work pressure showing up in what you said';
    }
    return cleaned;
  }

  static bool _phrasesTooSimilar(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return _overlapRatio(a, b) >= 0.6;
  }

  static double _overlapRatio(String a, String b) {
    final aTokens = sanitize(a).split(' ').where((w) => w.length > 2).toSet();
    final bTokens = sanitize(b).split(' ').where((w) => w.length > 2).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    return aTokens.intersection(bTokens).length / aTokens.union(bTokens).length;
  }
}