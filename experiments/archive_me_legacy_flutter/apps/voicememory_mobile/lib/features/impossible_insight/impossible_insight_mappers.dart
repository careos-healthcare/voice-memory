import '../post_save_insight/post_save_insight_models.dart';
import 'impossible_insight_models.dart';

abstract final class ImpossibleInsightMappers {
  static PostSaveInsightSignal toPostSaveSignal(ImpossibleInsight insight) {
    final value = insight.value;
    final quotes = value.evidence.map((item) => item.quote).toList();
    return PostSaveInsightSignal(
      id: value.id,
      readId: 'impossible_${insight.kind.name}',
      title: value.statement,
      explanation: value.uncertaintyNote,
      mightMean: value.statement,
      wouldConfirm: insight.nextEvidenceQuestion,
      wouldContradict: value.alternatives.first.statement,
      recordNextQuestion: insight.nextEvidenceQuestion,
      categoryId: 'impossible_insight',
      angleCategory: 'evidence',
      strengthLabel: _strength(value.confidence),
      whySuggested: 'Based only on the quoted words below.',
      evidenceLine: quotes.firstOrNull,
      evidenceUsed: quotes.map((quote) => '“$quote”').join(' · '),
      evidenceChips: quotes,
      isPrimary: true,
      explainableConclusion: value,
    );
  }

  static String _strength(int confidence) => switch (confidence) {
    >= 86 => 'Strong evidence',
    >= 76 => 'Repeated evidence',
    _ => 'One explicit moment',
  };
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
