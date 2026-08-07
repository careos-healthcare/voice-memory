import '../pattern_match_quality/pattern_match_quality_model.dart';

/// Present-day relevance weight — not a proof verdict.
enum PresentDayRelevanceState { current, fading, softened, unclear }

extension PresentDayRelevanceStateAnalytics on PresentDayRelevanceState {
  String get analyticsValue => switch (this) {
    PresentDayRelevanceState.current => 'current',
    PresentDayRelevanceState.fading => 'fading',
    PresentDayRelevanceState.softened => 'softened',
    PresentDayRelevanceState.unclear => 'unclear',
  };
}

/// Resolved present-day relevance summary from existing signals only.
class PresentDayRelevanceResult {
  const PresentDayRelevanceResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasBeliefSurface,
    required this.relevanceState,
    required this.title,
    required this.body,
    required this.stateBody,
    required this.footer,
    required this.differentiationLine,
    this.patternMatchQuality,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasBeliefSurface;
  final PresentDayRelevanceState relevanceState;
  final String title;
  final String body;
  final String stateBody;
  final String footer;
  final String differentiationLine;
  final PatternMatchQualityResult? patternMatchQuality;
}
