enum ThreeMomentCompletionStage {
  start,
  second,
  third,
}

extension ThreeMomentCompletionStageStorage on ThreeMomentCompletionStage {
  String get analyticsValue => switch (this) {
        ThreeMomentCompletionStage.start => 'start',
        ThreeMomentCompletionStage.second => 'second',
        ThreeMomentCompletionStage.third => 'third',
      };
}

enum ThreeMomentCompletionActionType {
  saveOneSentence,
  noticedSomething,
  saveOneMoreMoment,
  notToday,
}

extension ThreeMomentCompletionActionTypeStorage
    on ThreeMomentCompletionActionType {
  String get analyticsValue => switch (this) {
        ThreeMomentCompletionActionType.saveOneSentence => 'save_one_sentence',
        ThreeMomentCompletionActionType.noticedSomething => 'noticed_something',
        ThreeMomentCompletionActionType.saveOneMoreMoment => 'save_one_more_moment',
        ThreeMomentCompletionActionType.notToday => 'not_today',
      };
}

class ThreeMomentCompletionResult {
  const ThreeMomentCompletionResult({
    required this.shouldShow,
    required this.stage,
    required this.title,
    required this.body,
    required this.noPressureLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.primaryActionType,
    required this.entryCount,
    required this.source,
  });

  final bool shouldShow;
  final ThreeMomentCompletionStage stage;
  final String title;
  final String body;
  final String noPressureLine;
  final String primaryCta;
  final String secondaryCta;
  final ThreeMomentCompletionActionType primaryActionType;
  final int entryCount;
  final String source;
}
