/// Built Positive Pattern from repeated helpful actions in user entries.
class PositivePatternResult {
  const PositivePatternResult({
    required this.title,
    required this.body,
    required this.evidencePhrases,
  });

  final String title;
  final String body;
  final List<String> evidencePhrases;

  bool get hasEvidence => evidencePhrases.isNotEmpty;
}