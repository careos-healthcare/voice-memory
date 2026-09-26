/// Rules for a Reflect with me question.
///
/// The app may ask a question. It may quote the person's own words. It does
/// not give advice, a diagnosis, or an opinion.
abstract final class ReflectQuestionPolicy {
  ReflectQuestionPolicy._();

  static const maxQuestions = 3;
  static const silence = Duration(milliseconds: 1500);
  static const gemmaTimeout = Duration(milliseconds: 800);

  static const _advice = [
    'advice',
    'diagnose',
    'diagnosis',
    'disorder',
    'treatment',
    'therapy',
    'therapist',
    'you should',
    'i think',
    'in my opinion',
    'recommend',
  ];

  static bool canAskAnother({required int questionsAlreadyAsked}) =>
      questionsAlreadyAsked < maxQuestions;

  static bool isClosing(String utterance) {
    final normalized = utterance
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();
    return normalized == "that's all" || normalized == 'thats all';
  }

  /// The first sentence, unchanged apart from surrounding space.
  static String verbatimSentence(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(trimmed);
    return match?.group(0)?.trim() ?? trimmed;
  }

  static String spokenDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// A question built only from the last sentence and, when present, one
  /// earlier verbatim sentence.
  static String localQuestion({
    required String lastSentence,
    String? earlierQuote,
    DateTime? earlierOn,
  }) {
    final earlier = earlierQuote?.trim() ?? '';
    if (earlier.isNotEmpty && earlierOn != null) {
      return "On ${spokenDate(earlierOn)} you said '$earlier'. "
          "What's different now?";
    }
    final last = lastSentence.trim();
    if (last.isEmpty) return 'What stood out just then?';
    return "You said '$last'. What stood out just then?";
  }

  /// A spoken question is kept when it is one question, quotes only words
  /// that were actually said, and adds no advice.
  static bool accept({
    required String question,
    String? requiredQuote,
    List<String> sources = const [],
  }) {
    final text = question.trim();
    if (text.isEmpty || !text.endsWith('?')) return false;
    if (_hasAdvice(text, requiredQuote)) return false;
    final needed = requiredQuote?.trim() ?? '';
    if (needed.isNotEmpty && !text.contains(needed)) return false;
    return _quotesAreVerbatim(text, sources);
  }

  static bool _hasAdvice(String question, String? requiredQuote) {
    var outside = question.toLowerCase();
    final quote = requiredQuote?.trim().toLowerCase() ?? '';
    if (quote.isNotEmpty) outside = outside.replaceAll(quote, '');
    return _advice.any(outside.contains);
  }

  static bool _quotesAreVerbatim(String question, List<String> sources) {
    final pattern = RegExp(
      "(?<![A-Za-z])'([^']+)'|(?<![A-Za-z])\"([^\"]+)\"",
    );
    for (final match in pattern.allMatches(question)) {
      final quote = (match.group(1) ?? match.group(2) ?? '').trim();
      if (quote.isEmpty) continue;
      final allowed = sources.any((source) => source.contains(quote));
      if (!allowed) return false;
    }
    return true;
  }
}
