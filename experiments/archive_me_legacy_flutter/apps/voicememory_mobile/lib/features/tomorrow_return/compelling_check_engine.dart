import '../feedback/archive_feedback_model.dart';
import '../feedback/archive_feedback_summary_engine.dart';
import 'compelling_check_model.dart';

/// Builds sharper tomorrow check questions from loop context.
CompellingCheckQuestion buildCompellingCheck({
  required String baseQuestion,
  String? patternTitle,
  String? resultHint,
  String? reflectionText,
  ArchiveFeedbackSummary? feedbackSummary,
  ArchiveFeedbackType? feedback,
  bool preferDirect = false,
  String sharpnessLabel = CompellingCheckSharpness.practical,
}) {
  final dominant = feedback ?? feedbackSummary?.dominantIssue;
  final hint = _normalizeHint(resultHint);
  final title = (patternTitle ?? '').toLowerCase();

  if (dominant == ArchiveFeedbackType.tooGeneric ||
      dominant == ArchiveFeedbackType.moreSpecific) {
    return _exactMoment();
  }

  if (hint == 'lighter') {
    return _helpedMoment();
  }
  if (hint == 'heavier') {
    return _heavierMoment();
  }
  if (hint == 'changed') {
    return _changedMoment();
  }

  if (_matches(title, ['responsibility', 'carry', 'saying yes', 'pressure'])) {
    return _beforeMoment(
      question: 'Did you say yes before checking what you needed?',
      why:
          'This is useful because it catches the moment before the pattern starts.',
      example: 'I noticed it before I said yes.',
    );
  }

  if (_matches(title, ['worry', 'looping', 'quiet'])) {
    return _beforeMoment(
      question: 'Did the worry take over when things got quiet?',
      why:
          'This is useful because it checks whether the pattern returns in the quiet moment.',
      example: 'It came back when I stopped working.',
    );
  }

  if (_matches(title, ['avoidance', 'avoided', 'put off'])) {
    return _beforeMoment(
      question: 'Did you choose relief now and pressure later?',
      why: 'This is useful because it checks the moment before delay starts.',
      example: 'I avoided the message and felt pressure later.',
    );
  }

  if (preferDirect && sharpnessLabel == CompellingCheckSharpness.direct) {
    return _directFallback(baseQuestion);
  }

  final trimmed = baseQuestion.trim();
  if (trimmed.isNotEmpty && !_isVague(trimmed)) {
    return CompellingCheckQuestion(
      type: CompellingCheckType.repeatMoment,
      question: trimmed,
      whyThisCheck:
          'This is useful because it makes tomorrow\u2019s check specific.',
      exampleAnswer: 'It started before I answered.',
      sharpnessLabel: CompellingCheckSharpness.practical,
      source: 'baseQuestion',
    );
  }

  return _repeatFallback();
}

/// Four chooser options keyed by [CompellingCheckSharpness].
Map<String, CompellingCheckQuestion> buildCompellingCheckOptions({
  required String baseQuestion,
  String? patternTitle,
  String? resultHint,
  ArchiveFeedbackSummary? feedbackSummary,
  ArchiveFeedbackType? feedback,
  bool preferDirect = false,
}) {
  return {
    CompellingCheckSharpness.gentle:
        buildCompellingCheck(
          baseQuestion: baseQuestion,
          patternTitle: patternTitle,
          resultHint: 'same',
          feedbackSummary: feedbackSummary,
          feedback: feedback,
          sharpnessLabel: CompellingCheckSharpness.gentle,
        ).copyWith(
          question: 'Did this pattern show up again?',
          whyThisCheck: 'A gentle check keeps tomorrow easy to answer.',
          exampleAnswer: 'It showed up in an ordinary moment.',
          sharpnessLabel: CompellingCheckSharpness.gentle,
        ),
    CompellingCheckSharpness.direct: buildCompellingCheck(
      baseQuestion: baseQuestion,
      patternTitle: patternTitle,
      resultHint: resultHint,
      feedbackSummary: feedbackSummary,
      feedback: feedback,
      preferDirect: true,
      sharpnessLabel: CompellingCheckSharpness.direct,
    ),
    CompellingCheckSharpness.practical: buildCompellingCheck(
      baseQuestion: baseQuestion,
      patternTitle: patternTitle,
      resultHint: resultHint,
      feedbackSummary: feedbackSummary,
      feedback: feedback,
      sharpnessLabel: CompellingCheckSharpness.practical,
    ),
    CompellingCheckSharpness.mostSpecific: _exactMoment(),
  };
}

/// Default chooser label from feedback and missed-check signals.
String defaultCompellingSharpnessLabel({
  ArchiveFeedbackSummary? feedbackSummary,
  ArchiveFeedbackType? feedback,
  bool preferDirect = false,
}) {
  final dominant = feedback ?? feedbackSummary?.dominantIssue;
  if (dominant == ArchiveFeedbackType.tooGeneric ||
      dominant == ArchiveFeedbackType.moreSpecific) {
    return CompellingCheckSharpness.mostSpecific;
  }
  if (preferDirect) return CompellingCheckSharpness.direct;
  return CompellingCheckSharpness.practical;
}

CompellingCheckQuestion _exactMoment() => const CompellingCheckQuestion(
  type: CompellingCheckType.exactMoment,
  question: 'What exact moment did this show up?',
  whyThisCheck: 'A useful check should point to one moment, not the whole day.',
  exampleAnswer: 'It showed up before I replied.',
  sharpnessLabel: CompellingCheckSharpness.mostSpecific,
);

CompellingCheckQuestion _helpedMoment() => const CompellingCheckQuestion(
  type: CompellingCheckType.helpedMoment,
  question: 'What helped make it lighter?',
  whyThisCheck: 'If it felt lighter, the useful part is noticing what helped.',
  exampleAnswer: 'It felt lighter after I paused.',
  sharpnessLabel: CompellingCheckSharpness.practical,
);

CompellingCheckQuestion _heavierMoment() => const CompellingCheckQuestion(
  type: CompellingCheckType.heavierMoment,
  question: 'What made it heavier?',
  whyThisCheck:
      'If it felt heavier, the useful part is noticing what added pressure.',
  exampleAnswer: 'It felt heavier after I took it on alone.',
  sharpnessLabel: CompellingCheckSharpness.direct,
);

CompellingCheckQuestion _changedMoment() => const CompellingCheckQuestion(
  type: CompellingCheckType.changedMoment,
  question: 'What was different today?',
  whyThisCheck: 'If it changed, that can show what moves the pattern.',
  exampleAnswer: 'It changed when I waited before answering.',
  sharpnessLabel: CompellingCheckSharpness.practical,
);

CompellingCheckQuestion _beforeMoment({
  required String question,
  required String why,
  required String example,
}) => CompellingCheckQuestion(
  type: CompellingCheckType.beforeMoment,
  question: question,
  whyThisCheck: why,
  exampleAnswer: example,
  sharpnessLabel: CompellingCheckSharpness.direct,
);

CompellingCheckQuestion _repeatFallback() => const CompellingCheckQuestion(
  type: CompellingCheckType.repeatMoment,
  question: 'What happens right before it shows up?',
  whyThisCheck:
      'This is useful because it makes tomorrow\u2019s check specific.',
  exampleAnswer: 'It started before I answered.',
  sharpnessLabel: CompellingCheckSharpness.practical,
);

CompellingCheckQuestion _directFallback(String baseQuestion) {
  final trimmed = baseQuestion.trim();
  if (trimmed.isNotEmpty && !_isVague(trimmed)) {
    return CompellingCheckQuestion(
      type: CompellingCheckType.beforeMoment,
      question: trimmed,
      whyThisCheck:
          'This is useful because it catches the moment before the pattern starts.',
      exampleAnswer: 'I noticed it before it started.',
      sharpnessLabel: CompellingCheckSharpness.direct,
    );
  }
  return _beforeMoment(
    question: 'What happens right before it shows up?',
    why:
        'This is useful because it catches the moment before the pattern starts.',
    example: 'It started before I answered.',
  );
}

String _normalizeHint(String? resultHint) {
  switch (resultHint) {
    case 'lighter':
      return 'lighter';
    case 'heavier':
      return 'heavier';
    case 'changed':
    case 'not_today':
    case 'none_fit':
      return 'changed';
    case 'same':
    case 'showed_up_again':
    default:
      return 'same';
  }
}

bool _matches(String title, List<String> needles) {
  for (final n in needles) {
    if (title.contains(n)) return true;
  }
  return false;
}

bool _isVague(String question) {
  final q = question.toLowerCase();
  const vague = {
    'did this pattern show up again?',
    'was it a one-off, or did it repeat?',
    'was it a one-off, or did it feel lighter again?',
    'did it pass, or did it keep looping?',
    'did it feel resolved, or still heavy?',
  };
  return vague.contains(q);
}

extension CompellingCheckQuestionCopy on CompellingCheckQuestion {
  CompellingCheckQuestion copyWith({
    CompellingCheckType? type,
    String? question,
    String? whyThisCheck,
    String? exampleAnswer,
    String? sharpnessLabel,
    String? source,
  }) => CompellingCheckQuestion(
    type: type ?? this.type,
    question: question ?? this.question,
    whyThisCheck: whyThisCheck ?? this.whyThisCheck,
    exampleAnswer: exampleAnswer ?? this.exampleAnswer,
    sharpnessLabel: sharpnessLabel ?? this.sharpnessLabel,
    source: source ?? this.source,
  );
}
