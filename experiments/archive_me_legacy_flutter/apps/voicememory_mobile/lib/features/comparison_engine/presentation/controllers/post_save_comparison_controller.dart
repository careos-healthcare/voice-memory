import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/archive_moment_record.dart';
import '../../domain/models/pattern_evidence_view_state.dart';
import '../../domain/services/comparison_output_parser.dart';
import '../../domain/services/comparison_output_validator.dart';
import '../../domain/services/local_text_comparison_engine.dart';
import '../../domain/services/pattern_comparison_executor.dart';

sealed class PostSaveComparisonUiState {
  const PostSaveComparisonUiState();
}

class ComparisonLoading extends PostSaveComparisonUiState {
  const ComparisonLoading();
}

class ComparisonSuccess extends PostSaveComparisonUiState {
  final PatternEvidenceViewState viewState;
  const ComparisonSuccess(this.viewState);
}

class ComparisonFailure extends PostSaveComparisonUiState {
  final String errorMessage;
  const ComparisonFailure(this.errorMessage);
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

enum ComparisonExecutionEvent {
  parserSuccess,
  validationSuccess,
  validationWarnings,
  validationFailure,
  remoteSuccess,
  remoteFailure,
  fallbackInvoked,
  fallbackValidationSuccess,
  fallbackValidationFailure,
  fallbackSuccess,
  fallbackFailure,
}

abstract interface class ComparisonExecutionLogger {
  void log(ComparisonExecutionEvent event, {Object? error});
}

final class DebugComparisonExecutionLogger
    implements ComparisonExecutionLogger {
  const DebugComparisonExecutionLogger();

  @override
  void log(ComparisonExecutionEvent event, {Object? error}) {
    if (!kDebugMode) return;
    final errorType = error == null ? 'none' : error.runtimeType;
    debugPrint('COMPARISON_ENGINE event=${event.name} error_type=$errorType');
  }
}

class PostSaveComparisonController extends ChangeNotifier {
  final PatternComparisonExecutor _executor;
  final ModelApiClient _apiClient;
  final PreferenceStore _prefs;
  final LocalTextComparisonEngine _localEngine;
  final ComparisonOutputValidator _validator;
  final ComparisonExecutionLogger _logger;
  final Duration _remoteTimeout;

  PostSaveComparisonUiState _uiState = const ComparisonLoading();
  PostSaveComparisonUiState get uiState => _uiState;
  int _operationGeneration = 0;
  bool _disposed = false;

  PostSaveComparisonController({
    required this._apiClient,
    required this._prefs,
    this._executor = const PatternComparisonExecutor(),
    this._localEngine = const LocalTextComparisonEngine(),
    this._validator = const ComparisonOutputValidator(),
    this._logger = const DebugComparisonExecutionLogger(),
    Duration remoteTimeout = const Duration(seconds: 12),
  }) : _remoteTimeout = remoteTimeout {
    if (remoteTimeout.isNegative) {
      throw ArgumentError.value(
        remoteTimeout,
        'remoteTimeout',
        'must not be negative',
      );
    }
  }

  /// Runs the full end-to-end evaluation flow when a new moment is submitted.
  Future<void> processMomentComparison({
    required ArchiveMomentRecord currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
    required bool isProUser,
  }) async {
    final operation = ++_operationGeneration;
    _publishLoading(operation);

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
      final rawModelOutput = await _apiClient
          .evaluatePrompts(
            systemPrompt: plan.systemPrompt,
            userPrompt: plan.userPrompt,
          )
          .timeout(_remoteTimeout);

      if (rawModelOutput.trim().isEmpty) {
        throw const FormatException(
          'Remote engine returned an empty response payload.',
        );
      }

      final parsedOutput = _executor.parseModelOutput(rawModelOutput);
      _logger.log(ComparisonExecutionEvent.parserSuccess);
      final validation = _validator.validate(
        parsedOutput,
        currentMoment: currentMoment,
        historicalMoments: prunedHistory,
      );
      if (!validation.isValid) {
        _logger.log(ComparisonExecutionEvent.validationFailure);
        throw const _ComparisonValidationException();
      }
      if (validation.severity == ComparisonValidationSeverity.warning) {
        _logger.log(ComparisonExecutionEvent.validationWarnings);
      }
      _logger.log(ComparisonExecutionEvent.validationSuccess);
      final finalViewState = _executor.buildEvidenceViewState(
        plan: plan,
        parsed: validation.sanitizedOutput!,
      );

      _logger.log(ComparisonExecutionEvent.remoteSuccess);
      _publish(ComparisonSuccess(finalViewState), operation);
      return;
    } catch (remoteError) {
      _logger.log(ComparisonExecutionEvent.remoteFailure, error: remoteError);
      if (!_canPublish(operation)) return;
      _logger.log(ComparisonExecutionEvent.fallbackInvoked);

      try {
        final localResult = _localEngine.buildFromRawTextHistory(
          current: currentMoment,
          history: prunedHistory,
        );
        final localParsedOutput = ParsedComparisonOutput(
          state: localResult.alignmentState,
          connectionText: localResult.connectionSummary,
          pastQuote: localResult.matchedPastQuote,
          currentQuote: localResult.matchedCurrentQuote,
          whatChangedText:
              'Evaluated locally. ${localResult.evolutionAnalysis}',
          sourceLabel: ComparisonOutputValidator.canonicalLabelFor(
            localResult.alignmentState,
          ),
          sourceHadConnection: true,
          sourceHadWhatChanged: true,
          sourceHadEvidence: true,
        );
        final fallbackValidation = _validator.validate(
          localParsedOutput,
          currentMoment: currentMoment,
          historicalMoments: prunedHistory,
        );
        if (!fallbackValidation.isValid) {
          _logger.log(ComparisonExecutionEvent.fallbackValidationFailure);
          throw const _ComparisonValidationException();
        }
        if (fallbackValidation.severity ==
            ComparisonValidationSeverity.warning) {
          _logger.log(ComparisonExecutionEvent.validationWarnings);
        }
        _logger.log(ComparisonExecutionEvent.fallbackValidationSuccess);
        final fallbackViewState = _executor.buildEvidenceViewState(
          plan: plan,
          parsed: fallbackValidation.sanitizedOutput!,
        );

        _logger.log(ComparisonExecutionEvent.fallbackSuccess);
        _publish(ComparisonSuccess(fallbackViewState), operation);
      } catch (fallbackError) {
        _logger.log(
          ComparisonExecutionEvent.fallbackFailure,
          error: fallbackError,
        );
        _publish(
          const ComparisonFailure('Unable to compute connection analysis.'),
          operation,
        );
      }
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
        conversionHeadline: null,
      );
      _uiState = ComparisonSuccess(updatedViewState);
      notifyListeners();
    }
  }

  void _publishLoading(int operation) {
    if (!_canPublish(operation) || _uiState is ComparisonLoading) return;
    _uiState = const ComparisonLoading();
    notifyListeners();
  }

  void _publish(PostSaveComparisonUiState state, int operation) {
    if (!_canPublish(operation)) return;
    _uiState = state;
    notifyListeners();
  }

  bool _canPublish(int operation) =>
      !_disposed && operation == _operationGeneration;

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration += 1;
    super.dispose();
  }
}

final class _ComparisonValidationException implements Exception {
  const _ComparisonValidationException();
}
