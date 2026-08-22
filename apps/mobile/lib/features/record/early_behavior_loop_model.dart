/// Grounded early behaviour-loop insight from saved entry text.
class EarlyBehaviorLoopInsight {
  const EarlyBehaviorLoopInsight({
    required this.title,
    required this.loopLine,
    required this.triggerLine,
    required this.behaviorLine,
    required this.costLine,
    required this.evidenceLine,
    required this.nextCheckLine,
    required this.confidenceLabel,
    required this.shouldShow,
  });

  final String title;
  final String loopLine;
  final String triggerLine;
  final String behaviorLine;
  final String costLine;
  final String evidenceLine;
  final String nextCheckLine;
  final String confidenceLabel;
  final bool shouldShow;

  static const EarlyBehaviorLoopInsight none = EarlyBehaviorLoopInsight(
    title: '',
    loopLine: '',
    triggerLine: '',
    behaviorLine: '',
    costLine: '',
    evidenceLine: '',
    nextCheckLine: '',
    confidenceLabel: '',
    shouldShow: false,
  );
}