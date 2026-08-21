import 'dart:async';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';

/// Predictable failure states surfaced to UI and background workers.
sealed class ExecutionFailureState {
  const ExecutionFailureState();

  String get code;
  String get userMessage;
  bool get isRetryable;
}

/// Local on-device LLM / STT failures.
sealed class LlmExecutionFailure extends ExecutionFailureState {
  const LlmExecutionFailure();
}

final class LlmFailureConstraints extends LlmExecutionFailure {
  const LlmFailureConstraints();

  @override
  String get code => 'LLM_CONSTRAINTS';

  @override
  String get userMessage =>
      'On-device analysis is paused to save battery. It will resume automatically.';

  @override
  bool get isRetryable => true;
}

final class LlmFailureModelMissing extends LlmExecutionFailure {
  const LlmFailureModelMissing();

  @override
  String get code => 'LLM_MODEL_MISSING';

  @override
  String get userMessage =>
      'On-device model is not installed yet. Analysis will retry later.';

  @override
  bool get isRetryable => true;
}

final class LlmFailureTimeout extends LlmExecutionFailure {
  const LlmFailureTimeout({this.operationLabel});

  final String? operationLabel;

  @override
  String get code => 'LLM_TIMEOUT';

  @override
  String get userMessage =>
      'On-device analysis took too long and was stopped safely.';

  @override
  bool get isRetryable => true;
}

final class LlmFailureCancelled extends LlmExecutionFailure {
  const LlmFailureCancelled();

  @override
  String get code => 'LLM_CANCELLED';

  @override
  String get userMessage => 'Analysis was cancelled.';

  @override
  bool get isRetryable => false;
}

final class LlmFailureUnsupported extends LlmExecutionFailure {
  const LlmFailureUnsupported({this.detail});

  final String? detail;

  @override
  String get code => 'LLM_UNSUPPORTED';

  @override
  String get userMessage =>
      detail ?? 'On-device analysis is not available on this device.';

  @override
  bool get isRetryable => false;
}

final class LlmFailureRuntime extends LlmExecutionFailure {
  const LlmFailureRuntime({required this.detail});

  final String detail;

  @override
  String get code => 'LLM_RUNTIME';

  @override
  String get userMessage => 'On-device analysis did not complete.';

  @override
  bool get isRetryable => true;
}

/// Offline sync / outbox failures.
sealed class SyncExecutionFailure extends ExecutionFailureState {
  const SyncExecutionFailure();
}

final class SyncFailureOffline extends SyncExecutionFailure {
  const SyncFailureOffline({this.detail});

  final String? detail;

  @override
  String get code => 'SYNC_OFFLINE';

  @override
  String get userMessage =>
      detail ?? 'You appear to be offline. Your moments stay saved on this device.';

  @override
  bool get isRetryable => true;
}

final class SyncFailureAuthRequired extends SyncExecutionFailure {
  const SyncFailureAuthRequired();

  @override
  String get code => 'SYNC_AUTH_REQUIRED';

  @override
  String get userMessage => 'Sign in to sync your archive to the server.';

  @override
  bool get isRetryable => false;
}

final class SyncFailureConflict extends SyncExecutionFailure {
  const SyncFailureConflict({required this.blobId});

  final String blobId;

  @override
  String get code => 'SYNC_CONFLICT';

  @override
  String get userMessage =>
      'A newer copy exists on the server. Your local changes were preserved.';

  @override
  bool get isRetryable => false;
}

final class SyncFailureExhausted extends SyncExecutionFailure {
  const SyncFailureExhausted({required this.attempts, this.detail});

  final int attempts;
  final String? detail;

  @override
  String get code => 'SYNC_RETRIES_EXHAUSTED';

  @override
  String get userMessage =>
      'Sync did not complete after several tries. It will retry automatically.';

  @override
  bool get isRetryable => true;
}

final class SyncFailureTimeout extends SyncExecutionFailure {
  const SyncFailureTimeout();

  @override
  String get code => 'SYNC_TIMEOUT';

  @override
  String get userMessage => 'Sync timed out. It will retry automatically.';

  @override
  bool get isRetryable => true;
}

final class SyncFailureRuntime extends SyncExecutionFailure {
  const SyncFailureRuntime({required this.detail});

  final String detail;

  @override
  String get code => 'SYNC_RUNTIME';

  @override
  String get userMessage => 'Sync did not complete.';

  @override
  bool get isRetryable => true;
}

/// Maps arbitrary errors into typed LLM failures.
LlmExecutionFailure mapErrorToLlmFailure(Object error, [StackTrace? _]) {
  if (error is LlmExecutionFailure) return error;
  if (error is ExecutionCancelledException) {
    return const LlmFailureCancelled();
  }
  final message = '$error';
  if (message.contains('GEMMA_MODEL_NOT_INSTALLED')) {
    return const LlmFailureModelMissing();
  }
  if (message.contains('low battery') ||
      message.contains('thermal throttling') ||
      message.contains('On-device AI paused')) {
    return const LlmFailureConstraints();
  }
  if (error is UnsupportedError) {
    return LlmFailureUnsupported(detail: error.message);
  }
  if (error is TimeoutException) {
    return const LlmFailureTimeout();
  }
  return LlmFailureRuntime(detail: message);
}

/// Maps [ApiFailure] and runtime errors into typed sync failures.
SyncExecutionFailure mapApiFailureToSyncFailure(ApiFailure failure) {
  if (failure.code == 'TIMEOUT') {
    return const SyncFailureTimeout();
  }
  return switch (failure) {
    ApiFailureOffline(:final detail) => SyncFailureOffline(detail: detail),
    ApiFailureAuthRequired() => const SyncFailureAuthRequired(),
    ApiFailureRateLimited(:final message) =>
      SyncFailureRuntime(detail: message),
    _ when failure.code == 'NETWORK_ERROR' ||
        failure.code == 'NETWORK_DISCONNECTED' =>
      SyncFailureOffline(detail: failure.message),
    _ => SyncFailureRuntime(detail: failure.message),
  };
}

SyncExecutionFailure mapErrorToSyncFailure(Object error, [StackTrace? _]) {
  if (error is SyncExecutionFailure) return error;
  if (error is ApiFailure) return mapApiFailureToSyncFailure(error);
  if (error is TimeoutException) return const SyncFailureTimeout();
  return SyncFailureRuntime(detail: '$error');
}

extension LlmExecutionFailureUi on LlmExecutionFailure {
  LlmAnalysisStatus get analysisStatus => switch (this) {
        LlmFailureCancelled() => LlmAnalysisStatus.pendingAnalysis,
        LlmFailureConstraints() ||
        LlmFailureModelMissing() ||
        LlmFailureTimeout() =>
          LlmAnalysisStatus.pendingAnalysis,
        _ => LlmAnalysisStatus.error,
      };

  bool get shouldQueueForRetry => isRetryable && this is! LlmFailureCancelled;
}

extension SyncExecutionFailureUi on SyncExecutionFailure {
  BackgroundSyncPhase get suggestedPhase => switch (this) {
        SyncFailureOffline() => BackgroundSyncPhase.waitingForNetwork,
        SyncFailureExhausted() ||
        SyncFailureTimeout() ||
        SyncFailureRuntime() =>
          BackgroundSyncPhase.waitingForRetry,
        SyncFailureAuthRequired() || SyncFailureConflict() =>
          BackgroundSyncPhase.failed,
      };
}
