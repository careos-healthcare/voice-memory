import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/adaptive_question/adaptive_question_service.dart';
import 'package:voicememory_mobile/features/changes/change_thread.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_markers.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

/// One question or none. The service is only allowed to speak when the reader's
/// own saved words carry the grounding, and everything it says is either their
/// clause restated or a fixed factual question.
void main() {
  setUp(ProductAnalytics.resetForTest);

  group('grounded question', () {
    test('a repeated thread asks about the point the words stop at', () {
      final question = AdaptiveQuestionService.next(
        conclusion: _repeatedCheckingChange(),
        threadStatus: ChangeThreadStatus.repeated,
      );

      expect(
        question?.text,
        'Last time, you said you kept checking after the task was complete. '
        'What happened when you reached that point today?',
      );
      expect(
        question?.openDimension,
        ChangeDimension.stoppingOrCompletionBehaviour,
      );
      // A comparison is grounded in the moment "last time" actually means.
      expect(question?.groundingEntryId, 'entry-then');
    });

    test('a first observation asks about the ending the words never gave', () {
      final question = AdaptiveQuestionService.next(
        conclusion: _stoppedOnceObservation(),
      );

      expect(
        question?.text,
        'You said you stopped the report after one check and closed the '
        'laptop. How did it end today?',
      );
      expect(question?.openDimension, ChangeDimension.outcome);
    });

    test('a marker saying it is not settled makes the ending the question', () {
      final question = AdaptiveQuestionService.next(
        conclusion: _keptCheckingObservation(),
        markers: const StructuredMarkers(
          entryId: 'entry-now',
          resolution: MarkerResolution.unresolved,
        ),
      );

      expect(
        question?.text,
        'You said you kept checking after the task was complete. How did it '
        'end today?',
      );
      expect(question?.openDimension, ChangeDimension.outcome);
    });

    test('there is exactly one question and no second sentence asking', () {
      for (final question in [
        AdaptiveQuestionService.next(
          conclusion: _repeatedCheckingChange(),
          threadStatus: ChangeThreadStatus.repeated,
        ),
        AdaptiveQuestionService.next(conclusion: _stoppedOnceObservation()),
      ]) {
        expect(question, isNotNull);
        expect('?'.allMatches(question!.text).length, 1);
      }
    });

    test('nothing it says advises, labels or diagnoses', () {
      final question = AdaptiveQuestionService.next(
        conclusion: _repeatedCheckingChange(),
        threadStatus: ChangeThreadStatus.repeated,
      );

      for (final banned in const [
        'you should',
        'you need to',
        'you are',
        'try to',
        'remember',
        'growth',
        'journey',
        'healing',
        'therapy',
        'trauma',
        'diagnos',
        'disorder',
        'progress',
        'well done',
        'proud',
      ]) {
        expect(
          question!.text.toLowerCase(),
          isNot(contains(banned)),
          reason: '"$banned" is not language this product uses',
        );
      }
    });

    test('the reader is restated in the second person, not quoted as I', () {
      expect(
        AdaptiveQuestionService.firstPersonClause(
          'I was worried about the deadline all evening.',
        ),
        'were worried about the deadline all evening',
      );
      expect(
        AdaptiveQuestionService.firstPersonClause(
          'I checked my report twice before I sent it.',
        ),
        'checked your report twice',
      );
    });

    test('the question text is never handed to analytics', () async {
      final question = AdaptiveQuestionService.next(
        conclusion: _repeatedCheckingChange(),
        threadStatus: ChangeThreadStatus.repeated,
      );

      expect(question, isNotNull);
      expect(ProductAnalytics.eventsForTest, isEmpty);
      expect(ProductAnalytics.queuedEventCountForTest, 0);
    });
  });

  group('no question at all', () {
    test('without a validated conclusion', () {
      expect(AdaptiveQuestionService.next(conclusion: null), isNull);
    });

    test('when the reader corrected the reading', () {
      for (final choice in const [
        InsightFeedbackChoice.wrongAngle,
        InsightFeedbackChoice.tooGeneric,
        InsightFeedbackChoice.hide,
      ]) {
        expect(
          AdaptiveQuestionService.next(
            conclusion: _repeatedCheckingChange(),
            threadStatus: ChangeThreadStatus.repeated,
            latestCorrection: _correction(choice),
          ),
          isNull,
          reason: choice.name,
        );
      }
      // Confirming the reading leaves the question standing.
      expect(
        AdaptiveQuestionService.next(
          conclusion: _repeatedCheckingChange(),
          threadStatus: ChangeThreadStatus.repeated,
          latestCorrection: _correction(InsightFeedbackChoice.accurate),
        ),
        isNotNull,
      );
    });

    test('when the reader has hidden the thread', () {
      final view = _threadView(ChangeThreadVisibility.suppressed);

      expect(
        AdaptiveQuestionService.next(
          conclusion: _repeatedCheckingChange(),
          threadStatus: view.thread.currentStatus,
          threadIsVisible: view.thread.isVisible,
        ),
        isNull,
      );
    });

    test(
      'when no cited clause is something the reader said about themselves',
      () {
        expect(
          AdaptiveQuestionService.next(conclusion: _thirdPersonObservation()),
          isNull,
        );
        expect(
          AdaptiveQuestionService.firstPersonClause(
            'The meeting ran late and nobody said anything about the deadline.',
          ),
          isNull,
        );
      },
    );

    test('when the saved words already answer every askable dimension', () {
      final question = AdaptiveQuestionService.next(
        conclusion: _fullyAnsweredObservation(),
      );

      expect(question, isNull);
    });

    test('when a clause is too thin to restate', () {
      expect(AdaptiveQuestionService.firstPersonClause('I did.'), isNull);
      expect(AdaptiveQuestionService.firstPersonClause('I went home'), isNull);
    });
  });
}

InsightFeedbackRecord _correction(InsightFeedbackChoice choice) =>
    InsightFeedbackRecord(
      insightId: 'change-checking',
      insightType: InsightFeedbackType.auditableConclusion,
      choice: choice,
      createdAt: DateTime(2026, 7, 31, 12),
      sourceRoute: 'record_post_save',
    );

ChangeThreadView _threadView(ChangeThreadVisibility visibility) =>
    ChangeThreadView(
      thread: ChangeThread(
        threadId: 'thread-checking',
        archiveId: 'archive-1',
        userEditableLabel: 'Checking after finishing',
        subjectRepresentation: const {'check', 'task'},
        firstObservedAt: DateTime.utc(2026, 6, 1),
        latestObservedAt: DateTime.utc(2026, 7, 31),
        currentStatus: ChangeThreadStatus.repeated,
        evidenceEventIds: const ['event-1'],
        policyVersion: 'test',
        visibilityState: visibility,
      ),
      events: [
        ChangeEvent(
          eventId: 'event-1',
          threadId: 'thread-checking',
          conclusionKind: ExplainableInsightKind.change,
          status: ChangeThreadStatus.repeated,
          changedDimensions: const [ChangeDimension.frequency],
          exactEvidence: [
            TranscriptEvidenceCitation(
              entryId: 'entry-then',
              quote: _thenQuote,
              startUtf16: 0,
              endUtf16: _thenQuote.length,
              role: TranscriptEvidenceRole.supporting,
              sourceCapturedAt: DateTime.utc(2026, 6, 1),
              sourceType: EvidenceSourceType.voice,
            ),
          ],
          occurredAt: DateTime.utc(2026, 7, 31),
          confidenceBand: EvidenceConfidenceBand.repeatedAcrossMoments,
          uncertainty: 'Two moments cannot show whether this holds.',
          alternativeExplanation: 'The later task may have been a smaller one.',
        ),
      ],
    );

const _thenTranscript =
    'I kept checking after the task was complete, and the evening slipped '
    'away before I noticed.';
const _nowTranscript =
    'I checked once after the task was done, and the evening stayed mine.';
const _thenQuote = 'I kept checking after the task was complete';
const _nowQuote = 'I checked once after the task was done';

ValidatedExplainableConclusion _repeatedCheckingChange() => _gate(
  ExplainableConclusion(
    id: 'change-checking',
    statement:
        'You checked once after the task was done, where the same task once '
        'took repeated checking.',
    confidence: 80,
    reasoning: const [
      'The earlier saved words describe checking that kept going.',
      'The later saved words describe one check after the same task.',
    ],
    uncertaintyNote:
        'Two moments cannot show whether the shorter checking holds.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-then',
        quote: _thenQuote,
        startUtf16: _thenTranscript.indexOf(_thenQuote),
        endUtf16: _thenTranscript.indexOf(_thenQuote) + _thenQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 6, 1, 9),
        sourceType: EvidenceSourceType.voice,
        temporalRole: EvidenceTemporalRole.then,
        confidenceScore: 0.9,
      ),
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: _nowQuote,
        startUtf16: _nowTranscript.indexOf(_nowQuote),
        endUtf16: _nowTranscript.indexOf(_nowQuote) + _nowQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
        confidenceScore: 0.9,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'The later task may simply have been a smaller one.',
        rationale: 'Neither saved moment says how large the task was.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
    kind: ExplainableInsightKind.change,
  ),
  const {'entry-then': _thenTranscript, 'entry-now': _nowTranscript},
);

ValidatedExplainableConclusion _keptCheckingObservation() =>
    _singleMomentObservation(
      id: 'observation-checking',
      transcript: _thenTranscript,
      quote: _thenQuote,
      statement: 'You described checking that kept going after the task.',
      reasoning: 'The saved words describe checking after the task.',
    );

ValidatedExplainableConclusion _stoppedOnceObservation() {
  const transcript =
      'I stopped the report after one check and closed the laptop.';
  return _singleMomentObservation(
    id: 'observation-stopped',
    transcript: transcript,
    quote: transcript,
    statement: 'You described stopping the report after one check.',
    reasoning: 'The saved words describe stopping after one check.',
  );
}

ValidatedExplainableConclusion _thirdPersonObservation() {
  const transcript =
      'The meeting ran late and nobody said anything about the deadline.';
  return _singleMomentObservation(
    id: 'observation-meeting',
    transcript: transcript,
    quote: transcript,
    statement: 'The meeting ran late and the deadline went unmentioned.',
    reasoning: 'The saved words describe a meeting that ran late.',
  );
}

ValidatedExplainableConclusion _fullyAnsweredObservation() {
  const transcript =
      'I often avoided the meeting for hours and felt very tense before I '
      'stopped, and the day resolved.';
  return _singleMomentObservation(
    id: 'observation-answered',
    transcript: transcript,
    quote: transcript,
    statement: 'You avoided the meeting for hours before the day resolved.',
    reasoning: 'The saved words describe avoiding the meeting for hours.',
  );
}

ValidatedExplainableConclusion _singleMomentObservation({
  required String id,
  required String transcript,
  required String quote,
  required String statement,
  required String reasoning,
}) => _gate(
  ExplainableConclusion(
    id: id,
    statement: statement,
    confidence: 60,
    reasoning: [reasoning],
    uncertaintyNote: 'One moment cannot show whether this repeats.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: quote,
        startUtf16: transcript.indexOf(quote),
        endUtf16: transcript.indexOf(quote) + quote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'This may belong to this moment rather than a habit.',
        rationale: 'Only one saved moment supports it so far.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  ),
  {'entry-now': transcript},
);

ValidatedExplainableConclusion _gate(
  ExplainableConclusion conclusion,
  Map<String, String> transcripts,
) {
  final gated = ExplainableConclusionRenderGate.visible(
    conclusion,
    canonicalTranscripts: transcripts,
  );
  expect(
    gated,
    isNotNull,
    reason: 'fixture "${conclusion.id}" must survive the render gate',
  );
  return gated!;
}
