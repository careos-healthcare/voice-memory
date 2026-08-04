import 'package:flutter/foundation.dart';

import '../archive_reactivity/archive_log_hygiene.dart';
import 'legacy_pattern_copy_guard.dart';
import 'transcript_evidence_extractor.dart';

/// Whether the candidate is a short phrase, full belief, or general sentence.
enum PatternCopyRole { phrase, belief, sentence }

enum PatternCopyQualityDecision { approved, rejected }

class PatternCopyQualityResult {
  const PatternCopyQualityResult({
    required this.copy,
    required this.decision,
    required this.reason,
    required this.usedFallback,
  });

  final String copy;
  final PatternCopyQualityDecision decision;
  final String reason;
  final bool usedFallback;
}

/// Rejects weak n-grams and malformed transcript fragments before they reach
/// user-facing pattern / belief surfaces.
abstract class PatternCopyQualityGate {
  PatternCopyQualityGate._();

  static const possibleThread =
      'Your archive is starting to show a possible thread.';
  static const similarDirection = 'A few moments point in a similar direction.';
  static const needsMoreEvidence =
      'Record a few more ordinary moments before ArchiveMe names this pattern.';
  static const currentBeliefFallback =
      'A possible pattern is forming, but ArchiveMe needs more clear evidence before naming it.';

  static const _blockedSubstrings = [
    'follow a heavy should',
    'is test to see',
    'test to see if',
    'test to see',
  ];

  static const _edgeAuxiliaries = {
    'is',
    'to',
    'if',
    'when',
    'should',
    'because',
    'and',
    'or',
    'but',
    'as',
    'at',
    'in',
    'on',
    'of',
    'for',
    'with',
    'by',
    'a',
    'an',
    'the',
  };

  static const _fillerWords = {
    ..._edgeAuxiliaries,
    'be',
    'been',
    'being',
    'was',
    'were',
    'am',
    'are',
    'do',
    'does',
    'did',
    'have',
    'has',
    'had',
    'may',
    'might',
    'can',
    'could',
    'will',
    'would',
    'just',
    'very',
    'really',
    'still',
    'also',
    'then',
    'than',
    'that',
    'this',
    'these',
    'those',
    'what',
    'how',
    'why',
    'who',
    'where',
    'again',
    'more',
    'much',
    'many',
    'some',
    'any',
    'all',
    'not',
    'no',
    'yes',
    'up',
    'out',
    'off',
  };

  static PatternCopyQualityResult gate(
    String candidate, {
    PatternCopyRole role = PatternCopyRole.phrase,
  }) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) {
      return _fallback(role, reason: 'empty', original: trimmed);
    }

    if (LegacyPatternCopyGuard.containsLegacyCopy(trimmed)) {
      return _fallback(role, reason: 'legacy_template', original: trimmed);
    }

    final lower = trimmed.toLowerCase();
    for (final blocked in _blockedSubstrings) {
      if (lower.contains(blocked)) {
        return _fallback(role, reason: 'blocked_substring', original: trimmed);
      }
    }

    if (role == PatternCopyRole.belief) {
      final beliefReason = _beliefIssue(trimmed);
      if (beliefReason != null) {
        return _fallback(
          PatternCopyRole.belief,
          reason: beliefReason,
          original: trimmed,
        );
      }
      _log(
        trimmed,
        decision: PatternCopyQualityDecision.approved,
        reason: 'natural',
      );
      return PatternCopyQualityResult(
        copy: trimmed,
        decision: PatternCopyQualityDecision.approved,
        reason: 'natural',
        usedFallback: false,
      );
    }

    if (role == PatternCopyRole.sentence) {
      final sentenceReason = _sentenceIssue(trimmed);
      if (sentenceReason != null) {
        return _fallback(
          PatternCopyRole.sentence,
          reason: sentenceReason,
          original: trimmed,
        );
      }
      _log(
        trimmed,
        decision: PatternCopyQualityDecision.approved,
        reason: 'natural',
      );
      return PatternCopyQualityResult(
        copy: trimmed,
        decision: PatternCopyQualityDecision.approved,
        reason: 'natural',
        usedFallback: false,
      );
    }

    final phraseReason = _phraseIssue(trimmed);
    if (phraseReason != null) {
      return _fallback(role, reason: phraseReason, original: trimmed);
    }

    _log(
      trimmed,
      decision: PatternCopyQualityDecision.approved,
      reason: 'natural',
    );
    return PatternCopyQualityResult(
      copy: trimmed,
      decision: PatternCopyQualityDecision.approved,
      reason: 'natural',
      usedFallback: false,
    );
  }

  static String? gatePhraseOrNull(String? candidate) {
    if (candidate == null || candidate.trim().isEmpty) return null;
    final result = gate(candidate, role: PatternCopyRole.phrase);
    return result.usedFallback ? null : result.copy;
  }

  static String gateBelief(String candidate) {
    return gate(candidate, role: PatternCopyRole.belief).copy;
  }

  static String gateSentence(String candidate) {
    return gate(candidate, role: PatternCopyRole.sentence).copy;
  }

  static String fallbackFor(PatternCopyRole role) {
    return switch (role) {
      PatternCopyRole.belief => currentBeliefFallback,
      PatternCopyRole.phrase => possibleThread,
      PatternCopyRole.sentence => needsMoreEvidence,
    };
  }

  static String? _sentenceIssue(String sentence) {
    final normalized = sentence.trim().toLowerCase();
    if (normalized.length < 16) return 'too_short';

    if (LegacyPatternCopyGuard.containsLegacyCopy(sentence)) {
      return 'legacy_template';
    }

    for (final blocked in _blockedSubstrings) {
      if (normalized.contains(blocked)) return 'blocked_substring';
    }

    for (final clause in _embeddedClauses(sentence)) {
      if (_words(clause.toLowerCase()).length < 4) continue;
      final issue = _phraseIssue(clause);
      if (issue != null) return 'embedded_$issue';
    }

    return null;
  }

  static String? _beliefIssue(String belief) {
    if (LegacyPatternCopyGuard.containsLegacyCopy(belief)) {
      return 'legacy_template';
    }

    if (!_looksLikeCompleteSentence(belief)) {
      return 'incomplete_sentence';
    }

    for (final clause in _embeddedClauses(belief)) {
      if (_words(clause.toLowerCase()).length < 4) continue;
      final issue = _phraseIssue(clause);
      if (issue != null) return 'embedded_$issue';
    }

    return null;
  }

  static String? _phraseIssue(String phrase) {
    final normalized = phrase.trim().toLowerCase();
    if (normalized.isEmpty) return 'empty';

    if (TranscriptEvidenceExtractor.isShortEvidenceWord(normalized)) {
      return null;
    }

    if (LegacyPatternCopyGuard.containsLegacyCopy(phrase)) {
      return 'legacy_template';
    }

    for (final blocked in _blockedSubstrings) {
      if (normalized.contains(blocked)) return 'blocked_substring';
    }

    if (RegExp(r'\bshould\b').hasMatch(normalized) &&
        (normalized.endsWith(' should') || normalized.endsWith(' should.'))) {
      return 'dangling_should';
    }

    final words = _words(normalized);
    if (words.isEmpty) return 'no_words';

    final first = words.first.replaceAll(RegExp(r'[^a-z]'), '');
    final last = words.last.replaceAll(RegExp(r'[^a-z]'), '');
    if (_edgeAuxiliaries.contains(first)) return 'starts_with_auxiliary';
    if (_edgeAuxiliaries.contains(last) &&
        !LegacyPatternCopyGuard.hasNaturalTrailingPhrase(phrase)) {
      return 'ends_with_auxiliary';
    }

    final meaningful = words
        .map((w) => w.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((w) => w.length >= 3 && !_fillerWords.contains(w))
        .toList();

    if (meaningful.length < 2) return 'too_few_meaningful_words';
    if (meaningful.length < 3 && !_naturalShortPhrase(meaningful)) {
      return 'too_few_meaningful_words';
    }

    if (!_hasSemanticAnchor(meaningful)) return 'no_clear_meaning';

    if (RegExp(
      r'\b(a|an|the)\s+(heavy|light|big|small)\s+\w+\s*$',
    ).hasMatch(normalized)) {
      return 'malformed_fragment';
    }

    return null;
  }

  static bool _naturalShortPhrase(List<String> meaningful) {
    if (meaningful.length != 2) return false;
    return meaningful.every((w) => w.length >= 4);
  }

  static bool _hasSemanticAnchor(List<String> meaningful) {
    const anchors = {
      'pressure',
      'work',
      'behind',
      'enough',
      'guilt',
      'tired',
      'rest',
      'avoid',
      'failure',
      'deadline',
      'capacity',
      'family',
      'health',
      'money',
      'prove',
      'worry',
      'stress',
      'feeling',
      'agree',
      'help',
      'late',
      'exhausted',
      'make',
      'keep',
      'push',
      'carry',
      'ignore',
      'say',
      'said',
    };
    if (meaningful.any(anchors.contains)) return true;
    return meaningful.any((w) => w.length >= 5);
  }

  static bool _looksLikeCompleteSentence(String belief) {
    final trimmed = belief.trim();
    if (trimmed.length < 24) return false;
    if (!trimmed.endsWith('.') &&
        !trimmed.endsWith('!') &&
        !trimmed.endsWith('?')) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    const openers = [
      'you ',
      'something ',
      'a possible ',
      'the ',
      'this ',
      'your ',
      'record ',
      'archiveme ',
    ];
    if (!openers.any(lower.startsWith)) return false;
    return true;
  }

  static Iterable<String> _embeddedClauses(String sentence) sync* {
    final patterns = [
      RegExp(r'\bwhen\s+(.+?)[.?!]?$', caseSensitive: false),
      RegExp(r'\baround\s+(.+?)[.?!]?$', caseSensitive: false),
      RegExp(r'\bwhether\s+(.+?)\s+shows up again', caseSensitive: false),
      RegExp(r'\babout\s+(.+?)[.?!]?$', caseSensitive: false),
      RegExp(r'\bnotice\s+whether\s+(.+?)[.?!]?$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(sentence);
      if (match == null) continue;
      final clause = match.group(1)?.trim();
      if (clause != null && clause.isNotEmpty) yield clause;
    }
  }

  static List<String> _words(String text) {
    return text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  static PatternCopyQualityResult _fallback(
    PatternCopyRole role, {
    required String reason,
    required String original,
  }) {
    debugPrint(
      'ARCHIVEME_PATTERN_COPY_FALLBACK reason=low_confidence_or_bad_grammar',
    );
    _log(
      original.isEmpty ? '(empty)' : original,
      decision: PatternCopyQualityDecision.rejected,
      reason: reason,
    );
    return PatternCopyQualityResult(
      copy: fallbackFor(role),
      decision: PatternCopyQualityDecision.rejected,
      reason: reason,
      usedFallback: true,
    );
  }

  static void _log(
    String phrase, {
    required PatternCopyQualityDecision decision,
    required String reason,
  }) {
    final normalized = ArchiveLogHygiene.normalizedLogPhrase(phrase);
    final clipped = normalized.length <= 96
        ? normalized
        : '${normalized.substring(0, 93)}…';
    debugPrint(
      'ARCHIVEME_PATTERN_COPY_QUALITY phrase="$clipped" decision=${decision.name} reason=$reason',
    );
  }
}
