import '../../models/journal_entry.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../evidence_anchors/evidence_anchor_copy.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_copy.dart';
import '../present_day_relevance/present_day_relevance_copy.dart';
import '../timeline/timeline_entry_display.dart';

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
    'work stress',
    'kept coming back',
    'same pressure',
    'before bed',
    'before work',
    'before starting',
    'tired and unsure',
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
    'unsettled',
    'tired',
    'unsure',
    'busy',
    'bed',
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

  static const _vagueBehaviorPatterns = {
    'checking again',
    'avoiding again',
    'putting it off again',
    'put it off again',
    're-reading again',
    'rereading again',
    'said yes again',
    'replying later',
    'waiting too long',
    'kept checking',
    'kept avoiding',
    'kept delaying',
    'no capacity',
    'said yes',
  };

  static const _emotionalContextOnlyPatterns = {
    'feeling pressure before work',
    'stress after work again',
    'felt unsettled today at the office',
    'bad day with pressure again',
    'work stress kept coming back',
    'the same pressure at work',
    'feeling tired and unsure again',
    'busy day and same thing again',
    'pressure before starting',
    'stress before bed',
  };

  static const _behaviorSpecificPatterns = [
    'checking the same message before sending',
    'avoiding replying after feeling pressure',
    're-reading the email before feeling done',
    'putting off the same task after work pressure',
    'said yes when i had no capacity for one more thing',
    'checking the door twice before leaving',
    'delaying the same invoice after opening it',
    'rewriting the same reply before sending',
  ];

  static const _contextMarkers = {
    'before sending',
    'before leaving',
    'after opening it',
    'after feeling pressure',
    'when i had no capacity',
    'before feeling done',
    'after work pressure',
    'for one more thing',
    'for one more ask',
    'twice before',
    'same message',
    'same task',
    'same reply',
    'same invoice',
    'same email',
    'same door',
    'same ask',
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

  static const _strongActionVerbs = {
    'agreed',
    'asked',
    'avoided',
    'avoiding',
    'checked',
    'checking',
    'delayed',
    'delaying',
    'kept',
    'paused',
    'replied',
    'replying',
    'rewriting',
    'reread',
    'rereading',
    'reading',
    'sending',
    'said',
    'stopped',
    'putting',
    'waiting',
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
    'invoice',
    'invoices',
    'door',
    'call',
    'calls',
    'form',
    'forms',
    'application',
    'applications',
    'document',
    'documents',
    'note',
    'notes',
    'plan',
    'plans',
    'decision',
    'decisions',
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

  static bool isProofLevelEligible(String anchor) {
    final cleaned = anchor.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return false;
    if (_isKnownSystemCopy(cleaned)) return false;
    if (isSystemLikeAnchor(cleaned)) return false;
    if (isVagueBehaviorAnchor(cleaned)) return false;
    if (isEmotionalContextOnlyAnchor(cleaned)) return false;
    if (isGenericAnchor(cleaned)) return false;
    if (isWeakContextOnly(cleaned)) return false;
    if (hasGenericDensityTooHigh(cleaned) && !isBehaviorSpecific(cleaned)) {
      return false;
    }
    return isBehaviorSpecific(cleaned);
  }

  static bool hasProofLevelSafeAnchor(EvidenceAnchorExtractionResult? extraction) {
    if (extraction == null || !extraction.shouldExtract) return false;
    return extraction.anchors.any((anchor) => anchor.isSafeForDisplay);
  }

  static String? behaviorSpecificPhraseFromEntries(List<JournalEntry> entries) =>
      findBehaviorSpecificPhraseInTexts(
        entries
            .map(_entryText)
            .where((text) => text.trim().isNotEmpty)
            .toList(),
      );

  static String? findBehaviorSpecificPhraseInTexts(List<String> texts) {
    if (texts.isEmpty) return null;
    final lowerTexts = texts.map((text) => text.toLowerCase()).toList();
    final ranked = [..._behaviorSpecificPatterns]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final pattern in ranked) {
      if (!lowerTexts.any((text) => text.contains(pattern))) continue;
      if (isProofLevelEligible(pattern)) return pattern;
    }
    return null;
  }

  static bool isVagueBehaviorAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (_vagueBehaviorPatterns.contains(lower)) return true;
    for (final pattern in _vagueBehaviorPatterns) {
      if (lower == pattern) return true;
      if (lower.contains(pattern) && !hasRecognizableContext(lower)) {
        return true;
      }
    }
    return false;
  }

  static bool isEmotionalContextOnlyAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;
    for (final pattern in _emotionalContextOnlyPatterns) {
      if (lower == pattern || lower.contains(pattern)) {
        return !isBehaviorSpecific(lower);
      }
    }
    if (!_hasStrongActionAndConcreteObject(lower)) {
      final words = _words(lower);
      final hasEmotionalOnly = words.any(
        (word) =>
            weakContextTerms.contains(word) || genericTerms.contains(word),
      );
      if (hasEmotionalOnly && !hasRecognizableContext(lower)) {
        return true;
      }
    }
    return false;
  }

  static bool isBehaviorSpecific(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (!_hasStrongActionAndConcreteObject(lower)) return false;
    if (!hasRecognizableContext(lower)) return false;
    if (hasGenericDensityTooHigh(lower)) return false;

    final contentWords =
        _words(lower).where((word) => !_fillerWords.contains(word)).toList();
    if (contentWords.isEmpty) return false;

    final onlyWeakContext = contentWords.every(
      (word) =>
          weakContextTerms.contains(word) ||
          genericTerms.contains(word) ||
          word == 'busy',
    );
    return !onlyWeakContext;
  }

  static bool hasRecognizableContext(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (_contextMarkers.any(lower.contains)) return true;
    if (_behaviorSpecificPatterns.any(lower.contains)) return true;
    if (lower.contains('same ') &&
        _hasConcreteObject(_words(lower)) &&
        _words(lower).any(_matchesActionVerb)) {
      return true;
    }
    if (lower.contains('capacity') &&
        (lower.contains('one more') || lower.contains('when i had'))) {
      return true;
    }
    return false;
  }

  static bool isGenericAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;

    for (final term in genericTerms) {
      if (lower == term) return true;
      if (term.contains(' ') &&
          lower.contains(term) &&
          !isBehaviorSpecific(lower)) {
        return true;
      }
    }

    for (final term
        in ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels) {
      if (lower == term || lower.contains(term)) {
        if (!isBehaviorSpecific(lower)) return true;
      }
    }

    final words = _words(lower);
    if (words.length == 1 && genericTerms.contains(words.single)) {
      return true;
    }
    if (words.length <= 2 && words.every(genericTerms.contains)) {
      return true;
    }
    if (hasGenericDensityTooHigh(lower) && !isBehaviorSpecific(lower)) {
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
    if (isBehaviorSpecific(lower)) return false;

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

  static bool hasPhraseSpecificity(String anchor) => isBehaviorSpecific(anchor);

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

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.trim().isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static bool _isKnownSystemCopy(String anchor) {
    final normalized = anchor.trim().toLowerCase();
    for (final copy in _knownSystemCopy) {
      if (normalized == copy.trim().toLowerCase()) return true;
    }
    return false;
  }
}
