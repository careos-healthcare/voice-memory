import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';

enum ImpossibleInsightKind {
  exactRecurringPhrase,
  repeatedTriggerActionCost,
  explicitMicroHabit,
  reversal,
  narrowSequenceCorrelation,
}

class ImpossibleInsight {
  const ImpossibleInsight({
    required this.kind,
    required this.conclusion,
    required this.nextEvidenceQuestion,
  });

  final ImpossibleInsightKind kind;
  final ValidatedExplainableConclusion conclusion;
  final String nextEvidenceQuestion;

  ExplainableConclusion get value => conclusion.value;
}

class ImpossibleInsightCandidate {
  const ImpossibleInsightCandidate({
    required this.kind,
    required this.statement,
    required this.confidence,
    required this.uncertainty,
    required this.evidence,
    required this.alternative,
    required this.alternativeRationale,
    required this.nextEvidenceQuestion,
  });

  final ImpossibleInsightKind kind;
  final String statement;
  final int confidence;
  final String uncertainty;
  final List<TranscriptEvidenceCitation> evidence;
  final String alternative;
  final String alternativeRationale;
  final String nextEvidenceQuestion;
}
