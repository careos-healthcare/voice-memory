/// Sharp early compare insight grounded in saved entry text.
class EarlySpecificInsight {
  const EarlySpecificInsight({
    required this.title,
    required this.oneLinePattern,
    required this.evidenceLine,
    required this.nextQuestion,
    required this.confidenceLabel,
    required this.shouldShow,
  });

  final String title;
  final String oneLinePattern;
  final String evidenceLine;
  final String nextQuestion;
  final String confidenceLabel;
  final bool shouldShow;

  static const EarlySpecificInsight none = EarlySpecificInsight(
    title: '',
    oneLinePattern: '',
    evidenceLine: '',
    nextQuestion: '',
    confidenceLabel: '',
    shouldShow: false,
  );
}