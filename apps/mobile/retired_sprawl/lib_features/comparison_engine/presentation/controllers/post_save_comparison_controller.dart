import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/pattern_evidence_view_state.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/local_text_comparison_engine.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/pattern_comparison_executor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

sealed class PostSaveComparisonUiState {
  const PostSaveComparisonUiState();
}

class ComparisonLoading extends PostSaveComparisonUiState {
  const ComparisonLoading();
}

class ComparisonSuccess extends PostSaveComparisonUiState {
  const ComparisonSuccess(this.viewState);
  final PatternEvidenceViewState viewState;
}

class ComparisonFailure extends PostSaveComparisonUiState {
  const ComparisonFailure(this.errorMessage);
  final String errorMessage;
}

abstract class ModelApiClient {
  Future<String> evaluatePrompts({
    required String systemPrompt,
    required String userPrompt,
  });
}

abstract class PreferenceStore {
  bool getHasDismissedProPrompt();
  Future<void> setHasDismissedProPrompt(bool value);
}

class PostSaveComparisonController extends ChangeNotifier {

  PostSaveComparisonController({
    required this._apiClient,
    required this._prefs,
    this._executor = const PatternComparisonExecutor(),
    this._localEngine = const LocalTextComparisonEngine(),
  });
  final PatternComparisonExecutor _executor;
  final ModelApiClient _apiClient;
  final PreferenceStore _prefs;
  final LocalTextComparisonEngine _localEngine;

  PostSaveComparisonUiState _uiState = const ComparisonLoading();
  PostSaveComparisonUiState get uiState => _uiState;

  /// Runs the full end-to-end evaluation flow when a new moment is submitted.
  Future<void> processMomentComparison({
    required ArchiveMomentRecord currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
    required bool isProUser,
    String? systemPromptAddendum,
  }) async {
    _uiState = const ComparisonLoading();
    notifyListeners();

    final prunedHistory = _executor.pruneHistoricalContext(historicalMoments);
    final hasDismissed = _prefs.getHasDismissedProPrompt();
    final plan = _executor.buildComparisonPlan(
      currentMoment: currentMoment,
      historicalMoments: prunedHistory,
      isPro: isProUser,
      hasDismissedProTrailPrompt: hasDismissed,
      totalMomentCount: historicalMoments.length + 1,
    );

    try {
      final systemPrompt = systemPromptAddendum == null ||
              systemPromptAddendum.trim().isEmpty
          ? plan.systemPrompt
          : '${plan.systemPrompt}\n\n$systemPromptAddendum';
      final rawModelOutput = await _apiClient.evaluatePrompts(
        systemPrompt: systemPrompt,
        userPrompt: plan.userPrompt,
      );

      if (rawModelOutput.trim().isEmpty) {
        throw const FormatException(
          'Remote engine returned an empty response payload.',
        );
      }

      final finalViewState = _executor.buildEvidenceViewStateFromRawOutput(
        plan: plan,
        rawModelOutput: rawModelOutput,
      );

      if (finalViewState.state != PatternState.notEnoughEvidence &&
          (finalViewState.pastQuote.isEmpty ||
              finalViewState.currentQuote.isEmpty)) {
        throw const FormatException(
          'Remote engine response was unparseable into concrete evidence.',
        );
      }

      _uiState = ComparisonSuccess(finalViewState);
    } catch (networkOrParsingError, stackTrace) {
      _logRemoteFallback(networkOrParsingError);

      try {
        final localResult = _localEngine.buildFromRawTextHistory(
          current: currentMoment,
          history: prunedHistory,
        );

        final fallbackViewState = _executor.buildEvidenceViewStateFromFields(
          plan: plan,
          state: localResult.alignmentState,
          connectionText: localResult.connectionSummary,
          pastQuote: localResult.matchedPastQuote,
          currentQuote: localResult.matchedCurrentQuote,
          whatChangedText:
              'Evaluated locally. ${localResult.evolutionAnalysis}',
        );

        _uiState = ComparisonSuccess(fallbackViewState);
      } catch (_, stackTrace) {
        _uiState = const ComparisonFailure(
          'Unable to compute connection analysis.',
        );
      }
    } finally {
      notifyListeners();
    }
  }

  /// Saves user dismissal choice and updates the current state flags.
  Future<void> dismissProPrompt() async {
    await _prefs.setHasDismissedProPrompt(true);
    if (_uiState is ComparisonSuccess) {
      final currentSuccess = _uiState as ComparisonSuccess;
      final updatedViewState = PatternEvidenceViewState(
        state: currentSuccess.viewState.state,
        connectionText: currentSuccess.viewState.connectionText,
        pastQuote: currentSuccess.viewState.pastQuote,
        currentQuote: currentSuccess.viewState.currentQuote,
        whatChangedText: currentSuccess.viewState.whatChangedText,
        showProTrailPrompt: false,
      );
      _uiState = ComparisonSuccess(updatedViewState);
      notifyListeners();
    }
  }

  static void _logRemoteFallback(Object networkOrParsingError) {
    AppLogger.debug(
      'COMPARISON_ENGINE: Remote evaluation unviable, engaging local deterministic fallback: $networkOrParsingError',
    );
  }
}