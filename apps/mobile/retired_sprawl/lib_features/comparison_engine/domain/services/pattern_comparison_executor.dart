import 'package:archiveme_mobile/features/comparison_engine/comparison_engine_config.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/pattern_comparison_plan.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/pattern_evidence_view_state.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/comparison_output_parser.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/historical_context_pruner.dart' as historical_context_pruner;
import 'package:archiveme_mobile/features/comparison_engine/domain/services/pro_trail_gate.dart';

class PatternComparisonExecutor {

  const PatternComparisonExecutor({
    this._config = const ComparisonEngineConfig(),
    this._parser = const ComparisonOutputParser(),
    this.maxHistoricalContextItems = 30,
  });
  final ComparisonEngineConfig _config;
  final ComparisonOutputParser _parser;
  final int maxHistoricalContextItems;

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
    final prunedHistoricalMoments = historical_context_pruner
        .pruneHistoricalContext(
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
      currentMoment: currentMoment,
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
    return (systemPrompt: plan.systemPrompt, userPrompt: plan.userPrompt);
  }

  /// Parses the raw LLM response into structured comparison output.
  ParsedComparisonOutput parseModelOutput(String rawOutput) =>
      _parser.parse(rawOutput);

  /// Maps parsed comparison output plus plan context into passive UI state.
  PatternEvidenceViewState _buildVerifiedEvidenceViewState({
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
      conversionHeadline: showProTrailPrompt
          ? ProTrailGate.conversionHeadline
          : null,
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
    _verifyExactComparisonEvidence(
      plan: plan,
      pastQuote: pastQuote,
      currentQuote: currentQuote,
      state: state,
    );
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
      conversionHeadline: showProTrailPrompt
          ? ProTrailGate.conversionHeadline
          : null,
    );
  }

  /// End-to-end: parse raw model output and build passive UI state.
  PatternEvidenceViewState buildEvidenceViewStateFromRawOutput({
    required PatternComparisonPlan plan,
    required String rawModelOutput,
  }) {
    final parsed = parseModelOutput(rawModelOutput);
    _verifyExactComparisonEvidence(
      plan: plan,
      pastQuote: parsed.pastQuote,
      currentQuote: parsed.currentQuote,
      state: parsed.state,
    );
    return _buildVerifiedEvidenceViewState(plan: plan, parsed: parsed);
  }

  void _verifyExactComparisonEvidence({
    required PatternComparisonPlan plan,
    required String pastQuote,
    required String currentQuote,
    required PatternState state,
  }) {
    if (state == PatternState.notEnoughEvidence) return;
    if (pastQuote.isEmpty || currentQuote.isEmpty) {
      throw const FormatException('Comparison evidence is missing.');
    }
    final pastMatches = plan.visibleHistoricalMoments
        .where((moment) => _hasOneExactMatch(moment.savedWords, pastQuote))
        .toList();
    if (pastMatches.length != 1 ||
        !_hasOneExactMatch(plan.currentMoment.savedWords, currentQuote)) {
      throw const FormatException(
        'Comparison quotes do not match canonical source words exactly.',
      );
    }
    final past = pastMatches.single;
    if (past.id == plan.currentMoment.id ||
        !past.createdAt.isBefore(plan.currentMoment.createdAt) ||
        pastQuote == currentQuote) {
      throw const FormatException(
        'Comparison requires distinct chronological evidence.',
      );
    }
  }

  bool _hasOneExactMatch(String source, String quote) =>
      RegExp(RegExp.escape(quote)).allMatches(source).length == 1;

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
    buffer.writeln(
      '\nEvaluate the link cautiously based strictly on the provided words.',
    );

    return buffer.toString();
  }
}