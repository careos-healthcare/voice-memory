/// The single primary prompt shown on the Record screen: one small recording
/// derived from the user's own thread plan or daily suggestion evidence.
/// One clear starting point — never a task list, never fabricated.
class OneSmallRecording {
  const OneSmallRecording({
    required this.hasRecording,
    this.title = defaultTitle,
    this.basedOnLine = defaultBasedOnLine,
    this.prompt = '',
    this.supportingLine = defaultSupportingLine,
    this.sourceTerms = const [],
    this.entryIds = const [],
  });

  /// Keeps the card focused — a hint of where it came from, nothing more.
  static const int maxTerms = 3;

  static const String defaultTitle = 'Today\u2019s one small recording';
  static const String defaultBasedOnLine = 'Based on your thread plan';
  static const String defaultSupportingLine =
      'You do not need to solve everything today.';
  static const String recordCtaLabel = 'Record this';

  /// False when the archive holds no plan or suggestion evidence.
  final bool hasRecording;

  final String title;
  final String basedOnLine;

  /// The one prompt — short and action-oriented.
  final String prompt;

  final String supportingLine;

  /// Thread/suggestion terms behind the prompt (capped at [maxTerms]).
  final List<String> sourceTerms;

  /// Journal entry ids behind the prompt, when thread evidence backs it.
  final List<String> entryIds;

  factory OneSmallRecording.none() =>
      const OneSmallRecording(hasRecording: false);
}
