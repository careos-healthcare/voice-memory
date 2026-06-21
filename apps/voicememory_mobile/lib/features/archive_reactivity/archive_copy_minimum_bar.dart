import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../patterns/pattern_display_copy_gate.dart';
import 'archive_copy_grammar_gate.dart';
import 'archive_copy_normalizer.dart';
import 'archive_log_hygiene.dart';

class ArchiveCopyMinimumResult {
  const ArchiveCopyMinimumResult({
    required this.approved,
    required this.reason,
    required this.normalizedText,
  });

  final bool approved;
  final String reason;
  final String normalizedText;
}

/// Stricter product-quality gate applied after [PatternDisplayCopyGate].
abstract class ArchiveCopyMinimumBar {
  ArchiveCopyMinimumBar._();

  static const _placeholderTokens = {
    'summary',
    'changed',
    'notice',
    'why',
    'next',
    'text here',
    'before text here',
    'now text here',
    'shift text here',
  };

  static const _genericFiller = {
    'that may matter.',
    'notice what repeats.',
    'that makes it more worth watching.',
    'something worth watching.',
    'still worth watching.',
    'a few entries point toward this.',
    'record one more ordinary moment and see whether this comes back.',
    'record one more ordinary moment…',
    'record one more ordinary moment...',
  };

  static const _bannedDiagnostic = [
    'anxiety',
    'anxious',
    'trauma',
    'traumatic',
    'compulsive',
    'compulsion',
    'disorder',
    'pathology',
    'diagnosis',
    'diagnose',
    'self-sabotage',
    'obsessive',
    'obsession',
    'panic',
    'depressed',
    'depression',
  ];

  static const _bannedCertainty = [
    'you always',
    'you never',
    'this means',
    'this proves',
    'definitely',
    'clearly',
    'obviously',
    'must be',
    'is definitely',
  ];

  static const _signalWords = {
    'checking',
    'testing',
    'test',
    'standard',
    'pressure',
    'trust',
    'relief',
    'reassurance',
    'reassured',
    'app',
    'work',
    'loop',
    'thread',
    'finish',
    'safe',
    'urgency',
    'feel',
    'task',
    'stakes',
    'concern',
  };

  static const _comparativeWords = {
    'before',
    'now',
    'earlier',
    'this time',
    'returned',
    'returning',
    'softened',
    'shifted',
    'stronger',
  };

  static const _specificityFields = {
    'currentBelief',
    'insightLine',
    'insight',
    'precisionLine',
  };

  static const _precisionFields = {'precisionLine'};
  static const _contrastFields = {
    'contrastBefore',
    'contrastNow',
    'contrastShift',
  };
  static const _returnHookFields = {
    'returnHookTitle',
    'returnHookLine',
    'returnHookQuestion',
    'returnHookCta',
  };

  static ArchiveCopyMinimumResult validate({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) =>
      validateNormalized(
        field: field,
        normalizedText: ArchiveCopyNormalizer.normalize(text),
        allowShortLabel: allowShortLabel,
        requireSpecificity: requireSpecificity,
        allowGenericFallback: allowGenericFallback,
      );

  static ArchiveCopyMinimumResult validateNormalized({
    required String field,
    required String normalizedText,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) {
    final normalized = normalizedText.trim();
    if (normalized.isEmpty) {
      return _reject(field, normalized, 'empty');
    }

    final banned = _bannedPhraseIssue(normalized);
    if (banned != null) {
      return _reject(field, normalized, banned);
    }

    final malformed = _malformedIssue(normalized);
    if (malformed != null) {
      return _reject(field, normalized, malformed);
    }

    if (!allowGenericFallback && _isGenericFiller(normalized)) {
      return _reject(field, normalized, 'generic_filler');
    }

    if (_isPlaceholder(normalized)) {
      return _reject(field, normalized, 'placeholder');
    }

    if (!allowShortLabel &&
        _meaningfulWordCount(normalized) < _minMeaningfulWords(field)) {
      return _reject(field, normalized, 'too_short');
    }

    final maxWords = _maxWordsForField(field);
    if (_wordCount(normalized) > maxWords) {
      return _reject(field, normalized, 'too_long');
    }

    if (requireSpecificity && _specificityFields.contains(field)) {
      if (!_hasSpecificity(normalized)) {
        return _reject(field, normalized, 'lacks_specificity');
      }
    }

    if (!ArchiveCopyGrammarGate.checkForDisplayLog(
      field: _grammarFieldFor(field),
      text: normalized,
    ).approved) {
      return _reject(field, normalized, 'grammar_gate');
    }

    _logApproved(field, normalized);
    return ArchiveCopyMinimumResult(
      approved: true,
      reason: 'approved',
      normalizedText: normalized,
    );
  }

  @visibleForTesting
  static String normalize(String text) => ArchiveCopyNormalizer.normalize(text);

  static bool isApproved({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) =>
      validate(
        field: field,
        text: text,
        allowShortLabel: allowShortLabel,
        requireSpecificity: requireSpecificity,
        allowGenericFallback: allowGenericFallback,
      ).approved;

  static String displayOrEmpty({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) {
    final result = validate(
      field: field,
      text: text,
      allowShortLabel: allowShortLabel,
      requireSpecificity: requireSpecificity,
      allowGenericFallback: allowGenericFallback,
    );
    return result.approved ? result.normalizedText : '';
  }

  static bool passesCombinedGate({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) =>
      validate(
        field: field,
        text: text,
        allowShortLabel: allowShortLabel,
        requireSpecificity: requireSpecificity,
        allowGenericFallback: allowGenericFallback,
      ).approved;

  static String? _bannedPhraseIssue(String normalized) {
    final lower = normalized.toLowerCase();
    for (final banned in _bannedDiagnostic) {
      if (lower.contains(banned)) return 'banned_diagnostic';
    }
    for (final banned in _bannedCertainty) {
      if (lower.contains(banned)) return 'banned_certainty';
    }
    if (RegExp(
      r"^(you are|you're|you’re)\b",
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 'banned_certainty';
    }
    return null;
  }

  static String? _malformedIssue(String normalized) {
    if (!ArchiveCopyNormalizer.hasResidualMalformedText(normalized)) {
      return null;
    }

    if (RegExp(r',[^\s]').hasMatch(normalized)) {
      return 'malformed_comma';
    }

    final withoutArchiveMe = normalized.replaceAll(
      RegExp(r'ArchiveMe', caseSensitive: false),
      '',
    );
    if (RegExp(r'[a-z][A-Z]').hasMatch(withoutArchiveMe)) {
      return 'malformed_casing';
    }

    return 'malformed_residual';
  }

  static bool _isPlaceholder(String normalized) {
    final lower = normalized.toLowerCase();
    if (_placeholderTokens.contains(lower)) return true;
    final words = lower
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.length == 1 && _placeholderTokens.contains(words.first);
  }

  static bool _isGenericFiller(String normalized) {
    final lower = normalized.toLowerCase();
    if (_genericFiller.contains(lower)) return true;
    final withoutEllipsis = lower.replaceAll('…', '...');
    return _genericFiller.contains(withoutEllipsis);
  }

  static bool _hasSpecificity(String text) {
    if (_containsUserQuote(text)) return true;

    final lower = text.toLowerCase();
    for (final signal in _signalWords) {
      if (RegExp(r'\b' + RegExp.escape(signal) + r's?\b').hasMatch(lower)) {
        return true;
      }
    }
    for (final comparative in _comparativeWords) {
      if (lower.contains(comparative)) return true;
    }
    return false;
  }

  static bool _containsUserQuote(String text) =>
      text.contains('"') ||
      text.contains('“') ||
      text.contains('”') ||
      text.contains('\'') ||
      text.contains('‘') ||
      text.contains('’');

  static int _maxWordsForField(String field) {
    if (_precisionFields.contains(field)) return 24;
    if (_contrastFields.contains(field)) return 22;
    if (_returnHookFields.contains(field)) return 24;
    return 28;
  }

  static PatternDisplayField _grammarFieldFor(String field) => switch (field) {
    'hero' || 'precisionLine' || 'shortSummary' || 'returnHookTitle' =>
      PatternDisplayField.hero,
    'evidence' ||
    'contrastBefore' ||
    'contrastNow' ||
    'returnHookLine' =>
      PatternDisplayField.evidence,
    'whatChanged' || 'contrastShift' => PatternDisplayField.whatChanged,
    'currentBelief' || 'insightLine' || 'insight' =>
      PatternDisplayField.currentBelief,
    'whatToTest' ||
    'nextQuestion' ||
    'returnHookQuestion' ||
    'returnHookCta' ||
    'whatToNotice' =>
      PatternDisplayField.whatToTest,
    _ => PatternDisplayField.hero,
  };

  static int _minMeaningfulWords(String field) =>
      field == 'hero' || field == 'returnHookTitle' ? 2 : 3;

  static int _wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static int _meaningfulWordCount(String text) {
    const stopWords = {'a', 'an', 'the', 'to', 'it', 'is', 'may', 'be'};
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .length;
  }

  static ArchiveCopyMinimumResult _reject(
    String field,
    String normalized,
    String reason,
  ) {
    _logRejected(field, normalized, reason);
    return ArchiveCopyMinimumResult(
      approved: false,
      reason: reason,
      normalizedText: normalized,
    );
  }

  static void _logApproved(String field, String text) {
    final phrase = ArchiveLogHygiene.normalizedLogPhrase(text);
    final clipped = phrase.length <= 96 ? phrase : '${phrase.substring(0, 93)}…';
    debugPrint(
      'ARCHIVEME_COPY_MINIMUM_BAR approved=true field=$field '
      'reason=approved textHash=${_textHash(phrase)} phrase="$clipped"',
    );
  }

  static void _logRejected(String field, String text, String reason) {
    debugPrint(
      'ARCHIVEME_COPY_MINIMUM_BAR approved=false field=$field '
      'reason=$reason textHash=${_textHash(text)}',
    );
  }

  static String _textHash(String text) {
    final bytes = utf8.encode(text.trim().toLowerCase());
    var hash = 0;
    for (final byte in bytes) {
      hash = (hash * 31 + byte) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
