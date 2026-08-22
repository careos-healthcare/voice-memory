/// Improves lexical diversity scoring by preserving clinical compound terms.
class JargonAwareAnalyzer {
  const JargonAwareAnalyzer();

  static const List<MapEntry<String, String>> _compoundClinicalTerms = [
    MapEntry('cognitive behavioral therapy', 'cognitive_behavioral_therapy'),
    MapEntry('serotonin reuptake', 'serotonin_reuptake'),
    MapEntry('executive function', 'executive_function'),
  ];

  /// Computes unique-token ratio on a jargon-normalized token stream.
  double calculateNormalizedTtr(String text) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return 0;
    return tokens.toSet().length / tokens.length;
  }

  List<String> _tokenize(String text) {
    var normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    normalized = _collapseCompoundTerms(normalized);
    normalized = normalized
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return const [];

    return normalized
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  String _collapseCompoundTerms(String text) {
    var collapsed = text;
    final sortedTerms = List<MapEntry<String, String>>.from(
      _compoundClinicalTerms,
    )..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final term in sortedTerms) {
      collapsed = collapsed.replaceAll(
        RegExp('\\b${RegExp.escape(term.key)}\\b'),
        term.value,
      );
    }
    return collapsed;
  }
}