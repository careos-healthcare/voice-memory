import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable local identities for a proof's meaning and its exact wording.
///
/// Corrections are matched on these rather than on raw text, so no comparison
/// of user content ever leaves the device and no model is asked whether its own
/// output matches something the user already rejected.
///
/// The two fingerprints answer different questions:
///
/// * [semanticFraming] is deliberately lossy. Word order, casing, punctuation,
///   inflection and filler words are stripped, so trivial paraphrases of a
///   rejected statement collapse onto the same value and stay suppressed.
/// * [wording] is deliberately precise. It changes whenever the sentence
///   changes at all, so rejecting a phrasing does not reject the relationship.
class ProofFingerprints {
  const ProofFingerprints._();

  /// Words carrying no distinguishing meaning. Kept small and explicit: a
  /// larger list would start folding genuinely different statements together.
  static const Set<String> _filler = {
    'a',
    'about',
    'am',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'been',
    'being',
    'but',
    'by',
    'do',
    'does',
    'doing',
    'for',
    'from',
    'had',
    'has',
    'have',
    'having',
    'in',
    'into',
    'is',
    'it',
    'its',
    'of',
    'on',
    'or',
    'over',
    'still',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'they',
    'this',
    'to',
    'was',
    'were',
    'when',
    'with',
    'you',
    'your',
  };

  static String semanticFraming({
    required String statement,
    required String proofType,
  }) {
    final words =
        _words(statement)
            .map(_stem)
            .where((word) => word.isNotEmpty && !_filler.contains(word))
            .toSet()
            .toList()
          ..sort();
    return _digest('framing_v1|$proofType|${words.join(' ')}');
  }

  static String wording(String statement) =>
      _digest('wording_v1|${_words(statement).join(' ')}');

  static List<String> _words(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  /// Crude, deliberately conservative suffix folding. It exists so "checking"
  /// and "checks" match; it is not a linguistic stemmer and does not need to be.
  static String _stem(String word) {
    for (final suffix in const ['ing', 'ed', 'es', 's']) {
      if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    return word;
  }

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}