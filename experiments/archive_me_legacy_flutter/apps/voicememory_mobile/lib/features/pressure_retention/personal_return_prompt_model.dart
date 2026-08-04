/// A set of Record-screen starter prompts, personalized from the user's own
/// prior entries when there is evidence — otherwise the generic defaults.
class PersonalReturnPromptSet {
  const PersonalReturnPromptSet({
    required this.prompts,
    this.personalized = false,
    this.sourceTerms = const [],
    this.emptyStateFallback,
  });

  /// Small label shown above personalized prompts.
  static const String personalizedLabel = "Based on what you've recorded";

  /// 3–4 prompt strings, ready to render.
  final List<String> prompts;

  /// True when [prompts] were built from the user's own entries.
  final bool personalized;

  /// The repeated terms the prompts were built from (may be empty).
  final List<String> sourceTerms;

  /// Gentle starter line for users with no evidence yet.
  final String? emptyStateFallback;
}
