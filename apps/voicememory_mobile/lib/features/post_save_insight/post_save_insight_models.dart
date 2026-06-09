import '../first_session/first_session_pattern_model.dart';

/// One possible read on the user's first saved moment.
class PostSaveInsightSignal {
  const PostSaveInsightSignal({
    required this.id,
    required this.title,
    required this.explanation,
    required this.mightMean,
    required this.wouldConfirm,
    required this.wouldContradict,
    required this.recordNextQuestion,
    required this.categoryId,
    this.evidenceLine,
    this.angleCategory,
    this.strengthLabel,
    this.whySuggested,
    this.evidenceChips = const [],
    this.isPrimary = false,
    this.evidenceUsed,
    this.readId,
  });

  final String id;
  final String title;
  final String explanation;
  final String mightMean;
  final String wouldConfirm;
  final String wouldContradict;
  final String recordNextQuestion;
  final String categoryId;
  final String? evidenceLine;
  final String? angleCategory;
  final String? strengthLabel;
  final String? whySuggested;
  final List<String> evidenceChips;
  final bool isPrimary;
  final String? evidenceUsed;
  final String? readId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'explanation': explanation,
        'mightMean': mightMean,
        'wouldConfirm': wouldConfirm,
        'wouldContradict': wouldContradict,
        'recordNextQuestion': recordNextQuestion,
        'categoryId': categoryId,
        if (evidenceLine != null) 'evidenceLine': evidenceLine,
        if (angleCategory != null) 'angleCategory': angleCategory,
        if (strengthLabel != null) 'strengthLabel': strengthLabel,
        if (whySuggested != null) 'whySuggested': whySuggested,
        'evidenceChips': evidenceChips,
        'isPrimary': isPrimary,
        if (evidenceUsed != null) 'evidenceUsed': evidenceUsed,
        if (readId != null) 'readId': readId,
      };
}

/// Two-signal A/B read choice shown after recording.
class AbReadPair {
  const AbReadPair({required this.optionA, required this.optionB});

  final PostSaveInsightSignal optionA;
  final PostSaveInsightSignal optionB;
}

/// Signals derived from a first-session pattern for post-save choice UI.
class PostSaveInsightBundle {
  const PostSaveInsightBundle({
    required this.signals,
    required this.sourcePattern,
    this.needsClearerMoment = false,
    this.clearerMomentPrompt,
    this.clearerMomentTitle,
    this.loopUnsupported = false,
    this.archiveRepeatDetected = false,
    this.changedAngleDetected = false,
  });

  final List<PostSaveInsightSignal> signals;
  final FirstSessionPattern sourcePattern;
  final bool needsClearerMoment;
  final String? clearerMomentPrompt;
  final String? clearerMomentTitle;
  final bool loopUnsupported;
  final bool archiveRepeatDetected;
  final bool changedAngleDetected;

  bool get hasChoice => signals.length >= 2 && !needsClearerMoment;

  AbReadPair? get abPair {
    if (signals.length < 2) return null;
    return AbReadPair(optionA: signals[0], optionB: signals[1]);
  }
}
