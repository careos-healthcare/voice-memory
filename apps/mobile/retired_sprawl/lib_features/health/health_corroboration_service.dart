/// Compliance-ready permission model for future Apple Health / Google Fit
/// corroboration. No platform health APIs are called in V1.
abstract final class HealthCorroborationService {
  HealthCorroborationService._();

  static const HealthCorroborationPolicy policy = HealthCorroborationPolicy(
    enabled: false,
    requestOnLaunch: false,
    requestOnFirstInsight: false,
    allowedMetrics: [],
    retentionDays: 0,
    crossDeviceSync: false,
    userVisiblePurpose:
        'Optional health context to corroborate archive patterns — never shared without explicit consent.',
  );

  /// Returns whether the app may request health permissions on this device.
  static HealthPermissionDecision evaluateRequest({
    required HealthCorroborationScope scope,
    required bool userInitiated,
  }) {
    if (!policy.enabled) {
      return const HealthPermissionDecision(
        allowed: false,
        reason: HealthPermissionBlockReason.featureDisabled,
      );
    }
    if (!userInitiated && !policy.requestOnLaunch) {
      return const HealthPermissionDecision(
        allowed: false,
        reason: HealthPermissionBlockReason.requiresExplicitUserAction,
      );
    }
    if (scope.metricKeys.any((key) => !policy.allowedMetrics.contains(key))) {
      return const HealthPermissionDecision(
        allowed: false,
        reason: HealthPermissionBlockReason.metricNotAllowlisted,
      );
    }
    return const HealthPermissionDecision(allowed: true);
  }

  /// Placeholder — real HealthKit / Health Connect wiring lands in a future phase.
  static Future<HealthCorroborationSnapshot?> readSnapshot({
    required HealthCorroborationScope scope,
  }) async {
    final decision = evaluateRequest(scope: scope, userInitiated: true);
    if (!decision.allowed) return null;
    return null;
  }
}

class HealthCorroborationPolicy {
  const HealthCorroborationPolicy({
    required this.enabled,
    required this.requestOnLaunch,
    required this.requestOnFirstInsight,
    required this.allowedMetrics,
    required this.retentionDays,
    required this.crossDeviceSync,
    required this.userVisiblePurpose,
  });

  final bool enabled;
  final bool requestOnLaunch;
  final bool requestOnFirstInsight;
  final List<String> allowedMetrics;
  final int retentionDays;
  final bool crossDeviceSync;
  final String userVisiblePurpose;
}

class HealthCorroborationScope {
  const HealthCorroborationScope({required this.metricKeys});

  final List<String> metricKeys;
}

class HealthPermissionDecision {
  const HealthPermissionDecision({
    required this.allowed,
    this.reason,
  });

  final bool allowed;
  final HealthPermissionBlockReason? reason;
}

enum HealthPermissionBlockReason {
  featureDisabled,
  requiresExplicitUserAction,
  metricNotAllowlisted,
}

/// Normalized health readout — populated only after explicit user consent.
class HealthCorroborationSnapshot {
  const HealthCorroborationSnapshot({
    required this.capturedAt,
    required this.metrics,
  });

  final DateTime capturedAt;
  final Map<String, num> metrics;
}