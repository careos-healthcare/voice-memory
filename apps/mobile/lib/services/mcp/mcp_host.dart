import 'dart:convert';

import 'package:archiveme_mobile/services/mcp/mcp_consent_store.dart';
import 'package:archiveme_mobile/services/mcp/mcp_permission_gate.dart';
import 'package:archiveme_mobile/services/mcp/mcp_protocol.dart';
import 'package:archiveme_mobile/services/mcp/mcp_sandbox.dart';
import 'package:archiveme_mobile/services/mcp/mcp_tools.dart';
import 'package:archiveme_mobile/services/mcp/platform/calendar_data_gateway.dart';
import 'package:archiveme_mobile/services/mcp/platform/health_data_gateway.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local MCP host — JSON-RPC 2.0 over in-process or isolate IPC channels.
///
/// Exposes read-only tools for on-device agents. All calls are gated by
/// [McpPermissionGate] and validated by [McpLocalSandbox] before execution.
class McpHost {
  McpHost({
    required McpPermissionGate permissionGate,
    McpLocalSandbox? sandbox,
    FetchCalendarEventsTool? fetchCalendarEvents,
    FetchLocalHealthMetricsTool? fetchLocalHealthMetrics,
  }) : _permissionGate = permissionGate,
       _sandbox = sandbox ?? const McpLocalSandbox(),
       _fetchCalendarEvents =
           fetchCalendarEvents ??
           FetchCalendarEventsTool(permissionGate: permissionGate),
       _fetchLocalHealthMetrics =
           fetchLocalHealthMetrics ??
           FetchLocalHealthMetricsTool(permissionGate: permissionGate);

  final McpPermissionGate _permissionGate;
  final McpLocalSandbox _sandbox;
  final FetchCalendarEventsTool _fetchCalendarEvents;
  final FetchLocalHealthMetricsTool _fetchLocalHealthMetrics;

  static const protocolVersion = '2024-11-05';
  static const serverInfo = {
    'name': 'archiveme-local-mcp',
    'version': '1.0.0',
    'localOnly': true,
  };

  /// Factory wiring consent store, permission gateways, and platform gateways.
  factory McpHost.fromPrefs(
    MobilePrefsStore prefs, {
    CalendarDataGateway? calendarGateway,
    HealthDataGateway? healthGateway,
    CalendarPermissionGateway? calendarPermission,
    HealthPermissionGateway? healthPermission,
    McpLocalSandbox? sandbox,
    @visibleForTesting Map<McpOsDataDomain, bool>? enabledCapabilities,
  }) {
    final consentStore = McpOsDataConsentStore(prefs);
    final gate = McpPermissionGate(
      consentStore: consentStore,
      calendarPermission: calendarPermission,
      healthPermission: healthPermission,
      enabledCapabilities: enabledCapabilities,
    );
    return McpHost(
      permissionGate: gate,
      sandbox: sandbox,
      fetchCalendarEvents: FetchCalendarEventsTool(
        permissionGate: gate,
        calendarGateway: calendarGateway,
      ),
      fetchLocalHealthMetrics: FetchLocalHealthMetricsTool(
        permissionGate: gate,
        healthGateway: healthGateway,
      ),
    );
  }

  List<McpToolDefinition> listTools() => [
    FetchCalendarEventsTool.definition,
    FetchLocalHealthMetricsTool.definition,
  ];

  /// Handles a raw JSON-RPC request string and returns a JSON response string.
  Future<String> handleJson(String rawRequest) async {
    final response = await handleRequestString(rawRequest);
    return jsonEncode(response.toJson());
  }

  Future<McpJsonRpcResponse> handleRequestString(String rawRequest) async {
    try {
      final decoded = jsonDecode(rawRequest);
      if (decoded is! Map<String, dynamic>) {
        return McpJsonRpcResponse.failure(
          id: null,
          error: const McpJsonRpcError(
            code: McpErrorCodes.parseError,
            message: 'Request must be a JSON object.',
          ),
        );
      }
      return handleRequest(McpJsonRpcRequest.fromJson(decoded));
    } on FormatException {
      return McpJsonRpcResponse.failure(
        id: null,
        error: const McpJsonRpcError(
          code: McpErrorCodes.parseError,
          message: 'Invalid JSON payload.',
        ),
      );
    }
  }

  Future<McpJsonRpcResponse> handleRequest(McpJsonRpcRequest request) async {
    if (request.jsonrpc != '2.0') {
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: const McpJsonRpcError(
          code: McpErrorCodes.invalidRequest,
          message: 'jsonrpc must be "2.0".',
        ),
      );
    }

    final sandboxViolation = _sandbox.validateRequest(request);
    if (sandboxViolation != null) {
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: _sandbox.errorFor(sandboxViolation),
      );
    }

    try {
      final result = await _dispatch(request);
      return McpJsonRpcResponse.success(id: request.id, result: result);
    } on McpToolExecutionException catch (error) {
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: error.error,
      );
    } catch (error) {
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: McpJsonRpcError(
          code: McpErrorCodes.internalError,
          message: 'MCP host internal error.',
          data: {'detail': error.toString()},
        ),
      );
    }
  }

  Future<Object?> _dispatch(McpJsonRpcRequest request) async {
    switch (request.method) {
      case 'initialize':
        return {
          'protocolVersion': protocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': serverInfo,
        };
      case 'tools/list':
        return {
          'tools': listTools().map((tool) => tool.toJson()).toList(),
        };
      case McpToolNames.fetchCalendarEvents:
        return _fetchCalendarEvents.invoke(_toolArguments(request.params));
      case McpToolNames.fetchLocalHealthMetrics:
        return _fetchLocalHealthMetrics.invoke(_toolArguments(request.params));
      default:
        throw McpToolExecutionException(
          McpJsonRpcError(
            code: McpErrorCodes.methodNotFound,
            message: 'Unknown MCP method: ${request.method}',
          ),
        );
    }
  }

  Object? _toolArguments(Object? params) {
    if (params == null) return null;
    if (params is Map && params.containsKey('arguments')) {
      return params['arguments'];
    }
    return params;
  }

  McpPermissionGate get permissionGateForTest => _permissionGate;
}
