import '../../comparison_engine_config.dart';
import '../models/archive_moment_record.dart';
import '../models/pattern_comparison_plan.dart';
import '../models/pattern_evidence_view_state.dart';
import 'comparison_output_parser.dart';
import 'historical_context_pruner.dart' as historical_context_pruner;
import 'pro_trail_gate.dart';

class PatternComparisonExecutor {
  final ComparisonEngineConfig _config;
  final ComparisonOutputParser _parser;
  final int maxHistoricalContextItems;

  const PatternComparisonExecutor({
    ComparisonEngineConfig config = const ComparisonEngineConfig(),
    ComparisonOutputParser parser = const ComparisonOutputParser(),
    this.maxHistoricalContextItems = 30,
  })  : _config = config,
        _parser = parser;

  /// System prompt from [ComparisonEngineConfig] for model evaluation.
  String get systemPrompt => _config.buildSystemPrompt();

  /// Prunes historical moments to protect the model context window.
  List<ArchiveMomentRecord> pruneHistoricalContext(
    List<ArchiveMomentRecord> history,
  ) {
    return historical_context_pruner.pruneHistoricalContext(
      history,
      maxContextItems: maxHistoricalContextItems,
    );
  }

  /// Builds a gated comparison plan for the model pipeline.
  PatternComparisonPlan buildComparisonPlan({
    required ArchiveMomentRecord currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
    required bool isPro,
    required bool hasDismissedProTrailPrompt,
    int? totalMomentCount,
  }) {
    final prunedHistoricalMoments = historical_context_pruner.pruneHistoricalContext(
      historicalMoments,
      maxContextItems: maxHistoricalContextItems,
    );
    final visibleHistoricalMoments = ProTrailGate.visibleHistoricalMoments(
      moments: prunedHistoricalMoments,
      isPro: isPro,
    );

    return PatternComparisonPlan(
      systemPrompt: systemPrompt,
      userPrompt: buildUserPrompt(
        currentMoment: currentMoment,
        historicalMoments: visibleHistoricalMoments,
      ),
      visibleHistoricalMoments: visibleHistoricalMoments,
      totalMomentCount: totalMomentCount ?? (historicalMoments.length + 1),
      isPro: isPro,
      hasDismissedProTrailPrompt: hasDismissedProTrailPrompt,
    );
  }

  /// Bundles system + user prompts for the model evaluation pipeline.
  ({String systemPrompt, String userPrompt}) buildEvaluationPrompts({
    required ArchiveMomentRecord currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
    required bool isPro,
    required bool hasDismissedProTrailPrompt,
  }) {
    final plan = buildComparisonPlan(
      currentMoment: currentMoment,
      historicalMoments: historicalMoments,
      isPro: isPro,
      hasDismissedProTrailPrompt: hasDismissedProTrailPrompt,
    );
    return (
      systemPrompt: plan.systemPrompt,
      userPrompt: plan.userPrompt,
    );
  }

  /// Parses the raw LLM response into structured comparison output.
  ParsedComparisonOutput parseModelOutput(String rawOutput) =>
      _parser.parse(rawOutput);

  /// Maps parsed comparison output plus plan context into passive UI state.
  PatternEvidenceViewState buildEvidenceViewState({
    required PatternComparisonPlan plan,
    required ParsedComparisonOutput parsed,
  }) {
    final showProTrailPrompt = ProTrailGate.shouldShowProTrailPrompt(
      isPro: plan.isPro,
      hasDismissedProTrailPrompt: plan.hasDismissedProTrailPrompt,
      alignmentState: parsed.state,
      totalMomentCount: plan.totalMomentCount,
    );

    return PatternEvidenceViewState(
      state: parsed.state,
      connectionText: parsed.connectionText,
      pastQuote: parsed.pastQuote,
      currentQuote: parsed.currentQuote,
      whatChangedText: parsed.whatChangedText,
      showProTrailPrompt: showProTrailPrompt,
      conversionHeadline:
          showProTrailPrompt ? ProTrailGate.conversionHeadline : null,
    );
  }

  /// Maps explicit comparison fields plus plan context into passive UI state.
  PatternEvidenceViewState buildEvidenceViewStateFromFields({
    required PatternComparisonPlan plan,
    required PatternState state,
    required String connectionText,
    required String pastQuote,
    required String currentQuote,
    required String whatChangedText,
  }) {
    final showProTrailPrompt = ProTrailGate.shouldShowProTrailPrompt(
      isPro: plan.isPro,
      hasDismissedProTrailPrompt: plan.hasDismissedProTrailPrompt,
      alignmentState: state,
      totalMomentCount: plan.totalMomentCount,
    );

    return PatternEvidenceViewState(
      state: state,
      connectionText: connectionText,
      pastQuote: pastQuote,
      currentQuote: currentQuote,
      whatChangedText: whatChangedText,
      showProTrailPrompt: showProTrailPrompt,
      conversionHeadline:
          showProTrailPrompt ? ProTrailGate.conversionHeadline : null,
    );
  }

  /// End-to-end: parse raw model output and build passive UI state.
  PatternEvidenceViewState buildEvidenceViewStateFromRawOutput({
    required PatternComparisonPlan plan,
    required String rawModelOutput,
  }) {
    return buildEvidenceViewState(
      plan: plan,
      parsed: parseModelOutput(rawModelOutput),
    );
  }

  /// Formats historical context and current words into the user prompt payload.
  String buildUserPrompt({
    required ArchiveMomentRecord currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('HISTORICAL MOMENTS SUBMITTED BY USER:');
    if (historicalMoments.isEmpty) {
      buffer.writeln('(No prior moments on this thread.)');
    } else {
      for (var i = 0; i < historicalMoments.length; i++) {
        final moment = historicalMoments[i];
        buffer.writeln(
          '- Moment [${moment.createdAt.toIso8601String()}]: "${moment.savedWords}"',
        );
      }
    }

    buffer.writeln('\nNEW MOMENT TO EVALUATE:');
    buffer.writeln('"${currentMoment.savedWords}"');
    buffer.writeln('\nEvaluate the link cautiously based strictly on the provided words.');

    return buffer.toString();
  }
}
