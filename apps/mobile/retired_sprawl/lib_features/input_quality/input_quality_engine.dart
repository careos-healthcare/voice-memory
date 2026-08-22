import 'package:archiveme_mobile/features/input_quality/input_quality_model.dart';

/// Words that summarise a whole day or mood without a concrete moment.
const _vagueSummaryWords = <String>{
  'stressful',
  'stressed',
  'weird',
  'annoying',
  'annoyed',
  'fine',
  'okay',
  'ok',
  'tired',
  'busy',
  'bad',
  'good',
  'meh',
  'rough',
};

const _vagueSummaryPhrases = <String>{
  'bad day',
  'same as usual',
  'same as always',
  'same old',
  'nothing much',
};

/// Cues that anchor the reflection to a concrete moment / time / place / person.
const _momentCues = <String>{
  'when',
  'after',
  'before',
  'because',
  'while',
  'during',
  'once',
  'with',
  'message',
  'call',
  'meeting',
  'conversation',
  'replied',
  'reply',
  'text',
  'email',
};

const _momentPhrases = <String>{
  'as soon as',
  'at work',
  'in the morning',
  'last night',
  'this morning',
};

/// Cues that name a feeling or an action, not just a mood label.
const _feelingActionCues = <String>{
  'worried',
  'worry',
  'guilty',
  'guilt',
  'pressure',
  'lighter',
  'heavier',
  'avoided',
  'avoid',
  'asked',
  'paused',
  'replayed',
  'carried',
  'delayed',
  'started',
  'stopped',
  'noticed',
};

const _feelingActionPhrases = <String>{'said yes', 'said no'};

/// Pure mood labels with no event attached.
const _moodWords = <String>{
  'stressful',
  'stressed',
  'sad',
  'happy',
  'weird',
  'annoyed',
  'annoying',
  'tired',
  'anxious',
  'angry',
  'fine',
  'okay',
  'ok',
  'bad',
  'good',
  'frustrated',
  'overwhelmed',
  'calm',
  'flat',
};

/// Markers of a broad day summary rather than one moment.
const _summaryMarkers = <String>{'today', 'day', 'work', 'everything', 'usual'};

const _unclearRefWords = <String>{'it', 'this', 'stuff'};
const _unclearRefPhrases = <String>{'that thing'};

const _stopwords = <String>{
  'the',
  'a',
  'an',
  'was',
  'is',
  'were',
  'are',
  'be',
  'been',
  'am',
  'i',
  'my',
  'me',
  'we',
  'to',
  'of',
  'and',
  'so',
  'very',
  'really',
  'just',
  'it',
  'this',
  'that',
  'as',
  'in',
  'on',
  'at',
  'had',
  'have',
};

/// Assesses how useful a reflection is and how to coach it toward one moment.
InputQualityResult assessReflectionQuality(String text) {
  final lower = text.toLowerCase().trim();
  final words = _words(lower);
  final meaningful = words
      .where((w) => w.length >= 2 && !_stopwords.contains(w))
      .toList();
  final meaningfulCount = meaningful.length;

  final hasMoment = _hasAny(lower, words, _momentCues, _momentPhrases);
  final hasFeelingOrAction = _hasAny(
    lower,
    words,
    _feelingActionCues,
    _feelingActionPhrases,
  );
  final hasVagueSummary =
      words.any(_vagueSummaryWords.contains) ||
      _vagueSummaryPhrases.any(lower.contains);
  final hasMood = words.any(_moodWords.contains);
  final hasSummaryMarker = words.any(_summaryMarkers.contains);
  final hasUnclearRef =
      (words.any(_unclearRefWords.contains) ||
          _unclearRefPhrases.any(lower.contains)) &&
      meaningfulCount < 8;

  final issues = <InputQualityIssue>[];
  if (meaningfulCount < 6) issues.add(InputQualityIssue.tooShort);
  if (hasVagueSummary && !hasMoment && !hasFeelingOrAction) {
    issues.add(InputQualityIssue.tooGeneral);
  }
  if (!hasMoment) issues.add(InputQualityIssue.noMoment);
  if (!hasFeelingOrAction) issues.add(InputQualityIssue.noFeelingOrAction);
  if (hasUnclearRef && !hasMoment) {
    issues.add(InputQualityIssue.unclearReference);
  }
  if (hasMood && !hasMoment && !hasFeelingOrAction) {
    issues.add(InputQualityIssue.onlyMood);
  }
  if (hasSummaryMarker && !hasMoment && meaningfulCount < 8) {
    issues.add(InputQualityIssue.onlySummary);
  }

  final score = _score(
    meaningfulCount: meaningfulCount,
    hasMoment: hasMoment,
    hasFeelingOrAction: hasFeelingOrAction,
    hasVagueSummary: hasVagueSummary,
  );

  final level = _level(score);
  final shouldAsk =
      level == InputQualityLevel.vague || level == InputQualityLevel.tooShort;

  return InputQualityResult(
    level: level,
    issues: issues,
    score: score,
    helpfulPrompt: _helpfulPrompt(issues),
    exampleRewrite: _exampleRewrite(lower),
    shouldAskForSharpening: shouldAsk,
  );
}

double _score({
  required int meaningfulCount,
  required bool hasMoment,
  required bool hasFeelingOrAction,
  required bool hasVagueSummary,
}) {
  var score = 0.25;
  if (hasMoment) score += 0.35;
  if (hasFeelingOrAction) score += 0.30;
  if (meaningfulCount >= 6) score += 0.15;
  if (meaningfulCount >= 10) score += 0.10;
  if (hasVagueSummary && !hasMoment && !hasFeelingOrAction) score -= 0.10;
  if (meaningfulCount < 3) score -= 0.15;
  if (score < 0) return 0;
  if (score > 1) return 1;
  return score;
}

InputQualityLevel _level(double score) {
  if (score >= 0.75) return InputQualityLevel.strong;
  if (score >= 0.50) return InputQualityLevel.usable;
  if (score >= 0.25) return InputQualityLevel.vague;
  return InputQualityLevel.tooShort;
}

String _helpfulPrompt(List<InputQualityIssue> issues) {
  if (issues.contains(InputQualityIssue.tooShort)) {
    return 'Add one moment from today.';
  }
  if (issues.contains(InputQualityIssue.tooGeneral)) {
    return 'Name the moment, not the whole day.';
  }
  if (issues.contains(InputQualityIssue.unclearReference)) {
    return 'Name what \u2018it\u2019 was.';
  }
  if (issues.contains(InputQualityIssue.noMoment)) {
    return 'Say when it happened.';
  }
  if (issues.contains(InputQualityIssue.noFeelingOrAction)) {
    return 'Say what you did or felt.';
  }
  return 'Make it one clear moment.';
}

String _exampleRewrite(String lower) {
  if (lower.contains('worry') || lower.contains('worried')) {
    return 'The worry came back when things got quiet.';
  }
  if (lower.contains('tired')) {
    return 'I felt tired before saying yes again.';
  }
  if (lower.contains('stress') ||
      lower.contains('pressure') ||
      lower.contains('annoy')) {
    return 'I felt pressure when I was asked to help before I had time.';
  }
  return 'I noticed this when something happened today.';
}

List<String> _words(String lower) {
  return lower.split(RegExp('[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
}

bool _hasAny(
  String lower,
  List<String> words,
  Set<String> wordCues,
  Set<String> phraseCues,
) {
  if (words.any(wordCues.contains)) return true;
  return phraseCues.any(lower.contains);
}