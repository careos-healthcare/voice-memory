import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Local guard against API abuse, retry storms, and token drain.
class ApiUsageGuard {
  ApiUsageGuard({
    this.maxAttemptsPerScope = 3,
    this.cooldownBetweenRetries = const Duration(seconds: 30),
    this.dailyExpensiveOperationCap = 50,
    this.baseBackoff = const Duration(seconds: 2),
  });

  final int maxAttemptsPerScope;
  final Duration cooldownBetweenRetries;
  final int dailyExpensiveOperationCap;
  final Duration baseBackoff;

  final Map<String, _ScopeUsage> _scopes = {};
  int _dailyCount = 0;
  String _dailyKey = _todayKey();

  static ApiUsageGuard? _shared;

  static ApiUsageGuard get shared => _shared ??= ApiUsageGuard();

  @visibleForTesting
  static void resetForTest({ApiUsageGuard? replacement}) {
    _shared = replacement ?? ApiUsageGuard();
  }

  ApiUsageCheckResult checkAttempt({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) {
    _rollDailyIfNeeded();
    if (_dailyCount >= dailyExpensiveOperationCap) {
      return ApiUsageCheckResult.blocked(
        reason: 'Daily API cap reached ($dailyExpensiveOperationCap).',
      );
    }

    final key = _scopeOperationKey(scopeKey, operation);
    final usage = _scopes.putIfAbsent(key, _ScopeUsage.new);

    if (usage.attemptCount >= maxAttemptsPerScope) {
      return ApiUsageCheckResult.blocked(
        reason:
            'Max $operation attempts reached for this capture ($maxAttemptsPerScope).',
      );
    }

    if (usage.lastAttemptAt != null) {
      final elapsed = DateTime.now().difference(usage.lastAttemptAt!);
      final requiredDelay = exponentialBackoffDelay(usage.attemptCount);
      if (elapsed < requiredDelay) {
        return ApiUsageCheckResult.blocked(
          reason: 'Retry cooldown active for $operation.',
          retryAfter: requiredDelay - elapsed,
        );
      }
      if (elapsed < cooldownBetweenRetries && usage.attemptCount > 0) {
        return ApiUsageCheckResult.blocked(
          reason: 'Please wait before retrying $operation.',
          retryAfter: cooldownBetweenRetries - elapsed,
        );
      }
    }

    return const ApiUsageCheckResult.allowed();
  }

  void recordAttempt({
    required String scopeKey,
    required ApiUsageOperation operation,
    required bool success,
  }) {
    _rollDailyIfNeeded();
    _dailyCount++;

    final key = _scopeOperationKey(scopeKey, operation);
    final usage = _scopes.putIfAbsent(key, _ScopeUsage.new);
    usage.attemptCount++;
    usage.lastAttemptAt = DateTime.now();
    if (success) usage.succeeded = true;
  }

  String idempotencyKey({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) {
    final digest = base64Url
        .encode(utf8.encode('$scopeKey:${operation.name}'))
        .replaceAll('=', '');
    if (digest.length >= 24) return digest.substring(0, 24);
    return digest.padRight(24, '0');
  }

  Duration exponentialBackoffDelay(int attemptCount) {
    if (attemptCount <= 0) return Duration.zero;
    final multiplier = 1 << (attemptCount - 1).clamp(0, 6);
    return Duration(milliseconds: baseBackoff.inMilliseconds * multiplier);
  }

  void _rollDailyIfNeeded() {
    final today = _todayKey();
    if (today != _dailyKey) {
      _dailyKey = today;
      _dailyCount = 0;
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  static String _scopeOperationKey(
    String scopeKey,
    ApiUsageOperation operation,
  ) {
    return '$scopeKey:${operation.name}';
  }
}

enum ApiUsageOperation {
  transcribe,
  analyze,
  archiveSynthesis,
  liveAudioSession,
}

class ApiUsageCheckResult {
  const ApiUsageCheckResult._({
    required this.allowed,
    this.reason,
    this.retryAfter,
  });

  const ApiUsageCheckResult.allowed() : this._(allowed: true);

  factory ApiUsageCheckResult.blocked({
    required String reason,
    Duration? retryAfter,
  }) => ApiUsageCheckResult._(
    allowed: false,
    reason: reason,
    retryAfter: retryAfter,
  );

  final bool allowed;
  final String? reason;
  final Duration? retryAfter;
}

class _ScopeUsage {
  int attemptCount = 0;
  DateTime? lastAttemptAt;
  bool succeeded = false;
}