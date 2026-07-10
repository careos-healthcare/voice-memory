import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../evidence_anchors/evidence_anchor_copy.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_copy.dart';
import '../present_day_relevance/present_day_relevance_copy.dart';

/// Tightens anchor eligibility for proof-level surfaces — metadata-safe only.
abstract final class AnchorSpecificityGuard {
  AnchorSpecificityGuard._();

  static const minProofLevelWords = 3;
  static const minProofLevelChars = 18;
  static const maxGenericDensityRatio = 0.5;
  static const maxGenericWordsInShortPhrase = 3;
  static const shortPhraseWordLimit = 5;

  static const genericTerms = {
    'stress',
    'work',
    'tired',
    'bad day',
    'checking',
    'pressure',
    'again',
    'same thing',
    'felt bad',
    'not sure',
    'busy',
    'thing',
    'things',
    'today',
    'moment',
    'time',
    'felt',
    'feeling',
    'unsettled',
    'office',
    'day',
    'changed',
    'sure',
    'bad',
    'busy day',
    'work pressure',
    'office pressure',
    'stress at work',
    'bad day at work',
    'checking again',
    'same thing again',
    'felt tired again',
    'felt pressure again',
    'not sure what changed',
  };

  static const weakContextTerms = {
    'work',
    'office',
    'today',
    'day',
    'time',
    'again',
    'feeling',
    'felt',
    'pressure',
    'stress',
  };

  static const systemLikeTerms = {
    'saved privately',
    'record moment',
    'archive',
    'subscription',
    'pro',
    'privacy',
    'encrypted',
    'paywall',
    'archiveme',
    'saved moment',
    'appeared across',
    'appeared recently',
    'treats it more lightly',
    'your past is context',
    'chatgpt',
  };

  static const _knownSystemCopy = {
    EvidenceAnchorCopy.fallbackSummary,
    EvidenceWeightingCopy.explanationFresh,
    EvidenceWeightingCopy.explanationRepeated,
    EvidenceWeightingCopy.explanationFading,
    EvidenceWeightingCopy.explanationSoftened,
    EvidenceWeightingCopy.explanationOldSignal,
    EvidenceWeightingCopy.explanationNeedsFreshProof,
    PresentDayRelevanceCopy.currentStateBody,
    PresentDayRelevanceCopy.fadingStateBody,
    PresentDayRelevanceCopy.softenedStateBody,
    PresentDayRelevanceCopy.unclearStateBody,
  };

  static const _concreteActionPatterns = [
    'said yes again',
    'said yes when',
    'said yes',
    'no capacity',
    'checking the same message',
    'checking the message',
    'avoiding replying',
    'avoided replying',
    'avoided the message',
    're-reading the email',
    're-reading the',
    're-reading',
    'rereading',
    'putting off the same task',
    'putting off',
    'put it off',
    'before sending',
    'after feeling pressure',
    'after work pressure',
    'before feeling done',
    'same task',
    'same message',
    'same ask',
    'one more thing',
    'one more ask',
  ];

  static const _strongActionVerbs = {
    'agreed',
    'asked',
    'avoided',
    'avoiding',
    'checked',
    'checking',
    'paused',
    'replied',
    'replying',
    'reread',
    'rereading',
    'reading',
    'sending',
    'said',
    'stopped',
    'putting',
  };

  static const _concreteObjectHints = {
    'message',
    'messages',
    'email',
    'emails',
    'task',
    'tasks',
    'reply',
    'replies',
    'replying',
    'sending',
    'meeting',
    'meetings',
    'ask',
    'asks',
    'capacity',
    'text',
    'conversation',
    'deadline',
    'project',
    'request',
    'invitation',
    'commitment',
    'boundary',
    'boundaries',
    'done',
  };

  static const _fillerWords = {
    'a',
    'an',
    'at',
    'for',
    'had',
    'have',
    'i',
    'in',
    'it',
    'my',
    'no',
    'of',
    'on',
    'the',
    'to',
    'was',
    'what',
    'when',
    'with',
  };

  static const _selfSufficientBoundaryPatterns = {
    'said yes again',
    'said yes when',
    'said yes',
    'no capacity',
    'one more thing',
    'one more ask',
  };

  static bool isProofLevelEligible(String anchor) {
    final cleaned = anchor.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return false;
    if (_isKnownSystemCopy(cleaned)) return false;
    if (isSystemLikeAnchor(cleaned)) return false;
    if (isGenericAnchor(cleaned)) return false;
    if (isWeakContextOnly(cleaned)) return false;
    if (hasGenericDensityTooHigh(cleaned) && !_hasConcreteActionAndObject(cleaned)) {
      return false;
    }
    return hasPhraseSpecificity(cleaned);
  }

  static bool hasProofLevelSafeAnchor(EvidenceAnchorExtractionResult? extraction) {
    if (extraction == null || !extraction.shouldExtract) return false;
    return extraction.anchors.any((anchor) => anchor.isSafeForDisplay);
  }

  static bool isGenericAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;

    for (final term in genericTerms) {
      if (lower == term) return true;
      if (term.contains(' ') && lower.contains(term) && !_hasConcreteActionAndObject(lower)) {
        return true;
      }
    }

    for (final term
        in ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels) {
      if (lower == term || lower.contains(term)) {
        if (!_hasConcreteActionAndObject(lower)) return true;
      }
    }

    final words = _words(lower);
    if (words.length == 1 && genericTerms.contains(words.single)) {
      return true;
    }
    if (words.length <= 2 && words.every(genericTerms.contains)) {
      return true;
    }
    if (hasGenericDensityTooHigh(lower) && !_hasConcreteActionAndObject(lower)) {
      return true;
    }

    return false;
  }

  static bool isSystemLikeAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;
    for (final term in systemLikeTerms) {
      if (term.contains(' ')) {
        if (lower.contains(term)) return true;
        continue;
      }
      if (RegExp(r'\b${RegExp.escape(term)}\b').hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  static bool isWeakContextOnly(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (_hasStrongActionAndConcreteObject(lower)) return false;

    final words = _words(lower);
    final contentWords =
        words.where((word) => !_fillerWords.contains(word)).toList();
    if (contentWords.isEmpty) return true;

    return contentWords.every(
      (word) =>
          weakContextTerms.contains(word) ||
          genericTerms.contains(word) ||
          word == 'busy',
    );
  }

  static bool hasGenericDensityTooHigh(String anchor) {
    final words = _words(anchor.trim().toLowerCase());
    if (words.isEmpty) return true;

    final genericCount = words
        .where(
          (word) => genericTerms.contains(word) || weakContextTerms.contains(word),
        )
        .length;

    if (words.length <= shortPhraseWordLimit &&
        genericCount >= maxGenericWordsInShortPhrase) {
      return true;
    }

    return genericCount / words.length > maxGenericDensityRatio;
  }

  static bool hasPhraseSpecificity(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return false;

    if (_isSelfSufficientBoundaryPhrase(lower)) {
      return !isWeakContextOnly(lower) && !isGenericAnchor(lower);
    }

    for (final pattern in _concreteActionPatterns) {
      if (!lower.contains(pattern)) continue;
      if (_selfSufficientBoundaryPatterns.contains(pattern)) {
        return true;
      }
      if (_hasConcreteActionAndObject(lower)) {
        return true;
      }
    }

    return _hasConcreteActionAndObject(lower);
  }

  static bool _isSelfSufficientBoundaryPhrase(String lower) {
    if (_selfSufficientBoundaryPatterns.contains(lower)) {
      return true;
    }
    return _selfSufficientBoundaryPatterns.any(lower.contains);
  }

  static bool _hasConcreteActionAndObject(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (!_hasStrongActionAndConcreteObject(lower)) return false;
    if (hasGenericDensityTooHigh(lower)) return false;

    final words = _words(lower);
    final contentWords =
        words.where((word) => !_fillerWords.contains(word)).toList();
    if (contentWords.isEmpty) return false;

    final onlyWeakContext = contentWords.every(
      (word) =>
          weakContextTerms.contains(word) ||
          genericTerms.contains(word) ||
          word == 'busy',
    );
    return !onlyWeakContext;
  }

  static bool _hasStrongActionAndConcreteObject(String anchor) {
    final words = _words(anchor.trim().toLowerCase());
    if (words.isEmpty) return false;
    return words.any(_matchesActionVerb) && _hasConcreteObject(words);
  }

  static bool _matchesActionVerb(String word) {
    if (_strongActionVerbs.contains(word)) return true;
    final normalized = word.replaceAll('-', '');
    return _strongActionVerbs.contains(normalized);
  }

  static bool _hasConcreteObject(List<String> words) {
    for (final word in words) {
      if (_concreteObjectHints.contains(word)) return true;
    }
    return false;
  }

  static List<String> _words(String lower) =>
      lower.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

  static bool _isKnownSystemCopy(String anchor) {
    final normalized = anchor.trim().toLowerCase();
    for (final copy in _knownSystemCopy) {
      if (normalized == copy.trim().toLowerCase()) return true;
    }
    return false;
  }
}
