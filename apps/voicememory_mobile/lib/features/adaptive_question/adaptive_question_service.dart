import '../changes/change_thread.dart';
import '../explainable_conclusion/change_dimensions.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';
import '../insight_feedback/insight_feedback_models.dart';
import '../structured_markers/structured_markers.dart';
import 'adaptive_question.dart';

/// Derives at most one next question from evidence that already exists.
///
/// This is not a conversation. There is one question or there is none, it is
/// built from a validated conclusion's own citations, and it asks about the one
/// thing the reader's words have not said yet. It never advises, interprets or
/// consoles: the grounding half is the reader's own clause, and the asking half
/// is a fixed factual question chosen by dimension.
abstract final class AdaptiveQuestionService {
  /// Dimensions worth asking about next, most useful first.
  ///
  /// Kept deliberately short. When the saved words and markers already answer
  /// all of them there is nothing left to ask, and no question is produced.
  static const askableDimensions = <ChangeDimension>[
    ChangeDimension.stoppingOrCompletionBehaviour,
    ChangeDimension.outcome,
    ChangeDimension.behaviouralResponse,
    ChangeDimension.emotionalIntensity,
    ChangeDimension.duration,
    ChangeDimension.frequency,
  ];

  static const minimumClauseWords = 3;
  static const minimumClauseLength = 12;
  static const maximumClauseLength = 110;

  /// Returns the single next question, or null when the evidence does not earn
  /// one.
  ///
  /// [threadStatus] and [threadIsVisible] come from the archive's own thread —
  /// `view.thread.currentStatus` and `view.thread.isVisible` on the result of
  /// `ChangeThreadRepository.refresh()`. [latestCorrection] is the reader's most
  /// recent correction for this conclusion, read from `InsightFeedbackStore`.
  static AdaptiveQuestion? next({
    required ValidatedExplainableConclusion? conclusion,
    ChangeThreadStatus? threadStatus,
    bool threadIsVisible = true,
    InsightFeedbackRecord? latestCorrection,
    StructuredMarkers? markers,
  }) {
    if (conclusion == null) return null;
    // A hidden thread is a thread the reader has told us to stop reading.
    if (!threadIsVisible) return null;
    if (_wasRejected(latestCorrection)) return null;

    final value = conclusion.value;
    final supporting = value.evidence
        .where((citation) => citation.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    if (supporting.isEmpty) return null;

    final grounding = _groundingCitation(value.kind, supporting);
    final clause = firstPersonClause(grounding.quote);
    if (clause == null) return null;

    final open = _openDimension(supporting, markers);
    if (open == null) return null;

    final text = '${_grounding(threadStatus, clause)} ${_followUp(open)}';
    // A question that reads as advice, a label or a verdict is not shown at
    // all. Every phrase this service adds is safe by construction, so a hit
    // here comes from the reader's own clause and suppression is the right
    // answer.
    if (_unsafeLanguage.hasMatch(text)) return null;
    if (_questionMark.allMatches(text).length != 1) return null;

    return AdaptiveQuestion(
      text: text,
      conclusionId: value.id,
      groundingEntryId: grounding.entryId,
      openDimension: open,
    );
  }

  /// A correction that says the reading was wrong closes the subject. Asking a
  /// follow-up from a rejected reading would be arguing with the reader.
  static bool _wasRejected(InsightFeedbackRecord? correction) =>
      switch (correction?.choice) {
        InsightFeedbackChoice.wrongAngle ||
        InsightFeedbackChoice.tooGeneric ||
        InsightFeedbackChoice.hide ||
        InsightFeedbackChoice.notQuite ||
        InsightFeedbackChoice.tooEarly => true,
        _ => false,
      };

  /// A comparison is grounded in its earlier side — the moment "last time"
  /// actually refers to. A single observation is grounded in itself.
  static TranscriptEvidenceCitation _groundingCitation(
    ExplainableInsightKind kind,
    List<TranscriptEvidenceCitation> supporting,
  ) {
    if (kind == ExplainableInsightKind.observation) return supporting.last;
    final then = supporting
        .where((citation) => citation.temporalRole == EvidenceTemporalRole.then)
        .toList(growable: false);
    final candidates = then.isEmpty ? supporting : then;
    final dated =
        candidates
            .where((citation) => citation.sourceCapturedAt != null)
            .toList()
          ..sort((a, b) => a.sourceCapturedAt!.compareTo(b.sourceCapturedAt!));
    return dated.isEmpty ? candidates.first : dated.first;
  }

  /// The first askable dimension the reader's own words leave open.
  ///
  /// A marker saying the moment is unresolved makes the outcome the open
  /// question outright: the reader has said it is not settled, so asking how it
  /// ended is grounded rather than redundant.
  static ChangeDimension? _openDimension(
    List<TranscriptEvidenceCitation> supporting,
    StructuredMarkers? markers,
  ) {
    if (markers?.resolution == MarkerResolution.unresolved) {
      return ChangeDimension.outcome;
    }
    final answered = <ChangeDimension>{
      for (final citation in supporting)
        ...ChangeDimensionReader.read(citation.quote).keys,
      if (markers?.strength != null) ChangeDimension.emotionalIntensity,
      if (markers?.action != null && markers?.action != MarkerAction.other)
        ChangeDimension.behaviouralResponse,
      if (markers?.resolution != null) ChangeDimension.outcome,
    };
    for (final dimension in askableDimensions) {
      if (!answered.contains(dimension)) return dimension;
    }
    return null;
  }

  static String _grounding(ChangeThreadStatus? status, String clause) =>
      switch (status) {
        null || ChangeThreadStatus.firstObserved => 'You said you $clause.',
        _ => 'Last time, you said you $clause.',
      };

  static String _followUp(ChangeDimension dimension) => switch (dimension) {
    ChangeDimension.stoppingOrCompletionBehaviour =>
      'What happened when you reached that point today?',
    ChangeDimension.outcome => 'How did it end today?',
    ChangeDimension.behaviouralResponse => 'How did you respond today?',
    ChangeDimension.emotionalIntensity => 'How strong was it today?',
    ChangeDimension.duration => 'How long did it last today?',
    ChangeDimension.frequency => 'How often did that happen today?',
    ChangeDimension.certainty => 'How sure were you today?',
    ChangeDimension.emotionalState => 'How did it feel today?',
    ChangeDimension.action => 'What did you do today?',
    ChangeDimension.copingResponse => 'What did you do with it today?',
    ChangeDimension.situation => 'What was going on today?',
  };

  /// The reader's own first-person clause, restated in the second person.
  ///
  /// Only a clause the reader began with "I" is usable: it is something they
  /// stated about themselves, so restating it cannot invent a claim. Anything
  /// else produces no clause, and therefore no question.
  static String? firstPersonClause(String quote) {
    for (final segment in quote.split(_clauseBreak)) {
      final trimmed = segment.trim();
      final match = _firstPerson.firstMatch(trimmed);
      if (match == null) continue;
      var clause = match.group(1)!.trim();
      // A trailing "... before I could send it" starts a second statement; the
      // first one is the clause we are grounding on.
      clause = clause.split(_subordinateFirstPerson).first.trim();
      clause = clause.replaceAll(_trailingPunctuation, '');
      clause = clause.replaceAll(_danglingConjunction, '');
      clause = _secondPerson(clause);
      if (clause.contains('?')) continue;
      final words = clause
          .split(_whitespace)
          .where((word) => word.isNotEmpty)
          .length;
      if (words < minimumClauseWords) continue;
      if (clause.length < minimumClauseLength) continue;
      if (clause.length > maximumClauseLength) continue;
      return clause;
    }
    return null;
  }

  /// Minimal, whole-word pronoun restatement. Nothing else in the clause moves.
  static String _secondPerson(String clause) {
    var result = clause
        .replaceAll(RegExp(r'^was\b'), 'were')
        .replaceAll(RegExp(r"^wasn't\b"), "weren't")
        .replaceAll(RegExp(r'^am\b'), 'are')
        .replaceAll(RegExp(r'\bI was\b'), 'you were')
        .replaceAll(RegExp(r"\bI'm\b"), "you're")
        .replaceAll(RegExp(r"\bI've\b"), "you've")
        .replaceAll(RegExp(r"\bI'd\b"), "you'd")
        .replaceAll(RegExp(r"\bI'll\b"), "you'll")
        .replaceAll(RegExp(r'\bI\b'), 'you');
    for (final entry in const {
      'myself': 'yourself',
      'mine': 'yours',
      'my': 'your',
      'me': 'you',
    }.entries) {
      result = result.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  static final RegExp _clauseBreak = RegExp(
    r'(?:[.?!;]+\s*)|(?:,\s+(?:and|but|so|then)\s+)',
  );
  static final RegExp _firstPerson = RegExp(r'^[Ii]\s+(.+)$');
  static final RegExp _subordinateFirstPerson = RegExp(
    r'\s+(?:before|because|but|and|so|then|while|after|until|though|although)'
    r'\s+[Ii]\s+',
  );
  static final RegExp _trailingPunctuation = RegExp(r'[,;:\s]+$');
  static final RegExp _danglingConjunction = RegExp(
    r'\s+(?:and|but|so|because|before|then|while|after|until)$',
  );
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _questionMark = RegExp(r'\?');

  /// Language this product does not use: advice, verdicts, labels, diagnosis,
  /// or the vocabulary of therapy and self-improvement.
  static final RegExp _unsafeLanguage = RegExp(
    r"\b(?:you are|you're|you always|you never|you should|shouldn't|"
    r'you need to|you must|need to stop|diagnos\w*|disorder|therapy|'
    r'therapist|trauma|healing|coach\w*|wellness|mindset|journey|'
    r'growth|deep down|true self|real self|your fault|to blame|'
    r'unhealthy|toxic)\b',
    caseSensitive: false,
  );
}
