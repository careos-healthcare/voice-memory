import 'dart:async';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/execution_failure.dart';
import 'package:archiveme_mobile/core/execution/execution_result.dart';
import 'package:archiveme_mobile/core/execution/execution_strategy.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';

/// Resilience wrapper for on-device LLM / STT workloads.
final class LlmExecutionStrategy extends ExecutionStrategy {
  LlmExecutionStrategy({
    ResourceGuard? resourceGuard,
    this.defaultInferenceTimeout = const Duration(seconds: 90),
    this.backgroundInferenceTimeout = const Duration(minutes: 2),
  }) : _resourceGuard = resourceGuard ?? ResourceGuard.shared;

  static final LlmExecutionStrategy shared = LlmExecutionStrategy();

  final ResourceGuard _resourceGuard;
  final Duration defaultInferenceTimeout;
  final Duration backgroundInferenceTimeout;

  /// Runs [action] after resource checks, with timeout/cancellation/fallback.
  Future<ExecutionResult<T>> runInference<T>({
    required String operationLabel,
    required Future<T> Function() action,
    Duration? timeout,
    ExecutionCancelToken? cancelToken,
    T? fallbackValue,
    bool requireCanExecute = true,
    bool allowDeferredQueue = true,
    int maxAttempts = 1,
  }) async {
    final profile = await _resourceGuard.buildInferenceProfile();
    if (requireCanExecute && !profile.canExecute) {
      return const ExecutionDeferred(LlmFailureConstraints());
    }
    if (allowDeferredQueue && profile.shouldQueueLlmJobs) {
      return const ExecutionDeferred(LlmFailureConstraints());
    }

    return execute(
      operationLabel: operationLabel,
      action: action,
      fallbackValue: fallbackValue,
      mapFailure: mapErrorToLlmFailure,
      policy: ExecutionPolicy(
        timeout: timeout ?? defaultInferenceTimeout,
        cancelToken: cancelToken,
        maxAttempts: maxAttempts,
      ),
    );
  }

  /// Headless background tasks use a longer budget and queue on constraints.
  Future<ExecutionResult<T>> runBackgroundInference<T>({
    required String operationLabel,
    required Future<T> Function() action,
    T? fallbackValue,
    bool requireInstalledModel = false,
    Future<bool> Function()? modelInstalled,
  }) async {
    if (requireInstalledModel) {
      final installed = modelInstalled == null ? true : await modelInstalled();
      if (!installed) {
        return const ExecutionDeferred(LlmFailureModelMissing());
      }
    }

    return runInference(
      operationLabel: operationLabel,
      action: action,
      timeout: backgroundInferenceTimeout,
      fallbackValue: fallbackValue,
      allowDeferredQueue: true,
    );
  }

  /// Enqueues [action] on the resource guard queue when constraints block now.
  Future<ExecutionResult<T>> runOrQueue<T>({
    required String operationLabel,
    required Future<T> Function() action,
    ExecutionCancelToken? cancelToken,
  }) async {
    final profile = await _resourceGuard.buildInferenceProfile();
    if (profile.shouldQueueLlmJobs) {
      _resourceGuard.llmJobQueue.enqueue(
        () async {
          await runInference(
            operationLabel: operationLabel,
            action: action,
            cancelToken: cancelToken,
          );
        },
      );
      return const ExecutionDeferred(LlmFailureConstraints());
    }

    return runInference(
      operationLabel: operationLabel,
      action: action,
      cancelToken: cancelToken,
    );
  }
}
