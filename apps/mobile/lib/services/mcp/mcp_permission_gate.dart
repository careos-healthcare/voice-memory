import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/services/mcp/mcp_consent_store.dart';
import 'package:archiveme_mobile/services/mcp/mcp_protocol.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Why an MCP tool call was blocked at the permission gate.
enum McpPermissionBlockReason {
  sandboxViolation,
  userConsentMissing,
  capabilityDisabled,
  osPermissionDenied,
}

/// Result of evaluating whether an MCP tool may execute.
class McpPermissionDecision {
  const McpPermissionDecision({
    required this.permitted,
    this.reason,
    this.domain,
    this.sandboxError,
  });

  const McpPermissionDecision.permitted({McpOsDataDomain? domain})
    : permitted = true,
      reason = null,
      domain = domain,
      sandboxError = null;

  const McpPermissionDecision.denied({
    required this.reason,
    this.domain,
    this.sandboxError,
  }) : permitted = false;

  final bool permitted;
  final McpPermissionBlockReason? reason;
  final McpOsDataDomain? domain;
  final McpJsonRpcError? sandboxError;
}

/// Central gate for MCP OS data reads — consent, capability, and OS permission.
class McpPermissionGate {
  McpPermissionGate({
    required McpOsDataConsentStore consentStore,
    CalendarPermissionGateway? calendarPermission,
    HealthPermissionGateway? healthPermission,
    Map<McpOsDataDomain, bool>? enabledCapabilities,
  }) : _consentStore = consentStore,
       _calendarPermission =
           calendarPermission ?? PermissionHandlerCalendarGateway(),
       _healthPermission = healthPermission ?? HealthPackagePermissionGateway(),
       _enabledCapabilities = enabledCapabilities;

  final McpOsDataConsentStore _consentStore;
  final CalendarPermissionGateway _calendarPermission;
  final HealthPermissionGateway _healthPermission;
  final Map<McpOsDataDomain, bool>? _enabledCapabilities;

  Future<McpPermissionDecision> evaluateTool(String toolName) async {
    final domain = _domainForTool(toolName);
    if (domain == null) {
      return const McpPermissionDecision.denied(
        reason: McpPermissionBlockReason.capabilityDisabled,
      );
    }

    if (!_capabilityEnabled(domain)) {
      return McpPermissionDecision.denied(
        reason: McpPermissionBlockReason.capabilityDisabled,
        domain: domain,
      );
    }

    final consented = await _consentStore.isDomainGrantedNow(domain);
    if (!consented) {
      return McpPermissionDecision.denied(
        reason: McpPermissionBlockReason.userConsentMissing,
        domain: domain,
      );
    }

    final osGranted = await _osPermissionGranted(domain);
    if (!osGranted) {
      return McpPermissionDecision.denied(
        reason: McpPermissionBlockReason.osPermissionDenied,
        domain: domain,
      );
    }

    return McpPermissionDecision.permitted(domain: domain);
  }

  McpJsonRpcError errorFor(McpPermissionDecision decision) {
    final reason = decision.reason;
    if (reason == McpPermissionBlockReason.sandboxViolation &&
        decision.sandboxError != null) {
      return decision.sandboxError!;
    }

    return McpJsonRpcError(
      code: switch (reason) {
        McpPermissionBlockReason.sandboxViolation => McpErrorCodes.sandboxViolation,
        McpPermissionBlockReason.userConsentMissing =>
          McpErrorCodes.permissionDenied,
        McpPermissionBlockReason.capabilityDisabled =>
          McpErrorCodes.capabilityDisabled,
        McpPermissionBlockReason.osPermissionDenied =>
          McpErrorCodes.osPermissionDenied,
        null => McpErrorCodes.internalError,
      },
      message: switch (reason) {
        McpPermissionBlockReason.userConsentMissing =>
          'Explicit MCP consent required for ${decision.domain?.storageKey ?? 'this'} data.',
        McpPermissionBlockReason.capabilityDisabled =>
          'Native capability disabled for ${decision.domain?.storageKey ?? 'this'} data.',
        McpPermissionBlockReason.osPermissionDenied =>
          'OS permission denied for ${decision.domain?.storageKey ?? 'this'} data.',
        McpPermissionBlockReason.sandboxViolation =>
          'Local MCP sandbox violation.',
        null => 'MCP permission denied.',
      },
      data: {
        'localOnly': true,
        if (decision.domain != null) 'domain': decision.domain!.storageKey,
        if (reason != null) 'reason': reason.name,
      },
    );
  }

  static McpOsDataDomain? _domainForTool(String toolName) => switch (toolName) {
    McpToolNames.fetchCalendarEvents => McpOsDataDomain.calendar,
    McpToolNames.fetchLocalHealthMetrics => McpOsDataDomain.health,
    _ => null,
  };

  bool _capabilityEnabled(McpOsDataDomain domain) {
    final override = _enabledCapabilities?[domain];
    if (override != null) return override;
    return switch (domain) {
      McpOsDataDomain.calendar => V1CapabilityRegistry.calendar,
      McpOsDataDomain.health => V1CapabilityRegistry.health,
    };
  }

  Future<bool> _osPermissionGranted(McpOsDataDomain domain) async {
    return switch (domain) {
      McpOsDataDomain.calendar => _calendarPermission.isGranted(),
      McpOsDataDomain.health => _healthPermission.isGranted(),
    };
  }
}

/// Injectable calendar permission probe — mirrors microphone gateway pattern.
abstract class CalendarPermissionGateway {
  Future<bool> isGranted();
  Future<bool> request();
}

class PermissionHandlerCalendarGateway implements CalendarPermissionGateway {
  @override
  Future<bool> isGranted() async {
    if (Platform.isAndroid) {
      // device_calendar requests Android calendar permissions directly.
      return true;
    }
    return (await Permission.calendarFullAccess.status).isGranted;
  }

  @override
  Future<bool> request() async {
    if (Platform.isAndroid) return true;
    return (await Permission.calendarFullAccess.request()).isGranted;
  }
}

/// Injectable health permission probe.
abstract class HealthPermissionGateway {
  Future<bool> isGranted();
  Future<bool> request();
}

class HealthPackagePermissionGateway implements HealthPermissionGateway {
  @override
  Future<bool> isGranted() async {
    // Health authorization is requested per data type at read time.
    // Consent store + capability gate are the primary controls here.
    return true;
  }

  @override
  Future<bool> request() async => true;
}

/// Test double for calendar permission.
class FakeCalendarPermissionGateway implements CalendarPermissionGateway {
  FakeCalendarPermissionGateway({this.granted = false});

  bool granted;
  int requestCallCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCallCount++;
    granted = true;
    return true;
  }
}

/// Test double for health permission.
class FakeHealthPermissionGateway implements HealthPermissionGateway {
  FakeHealthPermissionGateway({this.granted = false});

  bool granted;
  int requestCallCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCallCount++;
    granted = true;
    return true;
  }
}
