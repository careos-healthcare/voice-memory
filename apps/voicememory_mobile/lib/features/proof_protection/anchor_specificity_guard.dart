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
    'checking again',
    'checked again',
    'avoiding replying',
    'avoided replying',
    'avoided the message',
    're-reading',
    'rereading',
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

  static const _actionVerbHints = {
    'agreed',
    'asked',
    'avoided',
    'checked',
    'checking',
    'paused',
    'replied',
    'replying',
    'reread',
    'reading',
    'sending',
    'said',
    'stopped',
    'putting',
  };

  static bool isProofLevelEligible(String anchor) {
    final cleaned = anchor.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return false;
    if (_isKnownSystemCopy(cleaned)) return false;
    if (isSystemLikeAnchor(cleaned)) return false;
    if (isGenericAnchor(cleaned)) return false;
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
    }

    for (final term
        in ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels) {
      if (lower == term || lower.contains(term)) {
        if (!hasPhraseSpecificity(anchor)) return true;
      }
    }

    final words =
        lower.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.length == 1 && genericTerms.contains(words.single)) {
      return true;
    }
    if (words.length <= 2 && words.every(genericTerms.contains)) {
      return true;
    }

    return false;
  }

  static bool isSystemLikeAnchor(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return true;
    return systemLikeTerms.any(lower.contains);
  }

  static bool hasPhraseSpecificity(String anchor) {
    final lower = anchor.trim().toLowerCase();
    if (lower.isEmpty) return false;

    for (final pattern in _concreteActionPatterns) {
      if (lower.contains(pattern)) return true;
    }

    final words =
        lower.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.length < minProofLevelWords && lower.length < minProofLevelChars) {
      return false;
    }

    final hasActionVerb = words.any(_actionVerbHints.contains);
    final nonGenericWords =
        words.where((word) => !genericTerms.contains(word)).length;
    return hasActionVerb && nonGenericWords >= 2;
  }

  static bool _isKnownSystemCopy(String anchor) {
    final normalized = anchor.trim().toLowerCase();
    for (final copy in _knownSystemCopy) {
      if (normalized == copy.trim().toLowerCase()) return true;
    }
    return false;
  }
}
