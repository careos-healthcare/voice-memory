import 'dart:convert';

import 'package:archiveme_mobile/services/mcp/mcp_permission_gate.dart';
import 'package:archiveme_mobile/services/mcp/mcp_protocol.dart';
import 'package:archiveme_mobile/services/mcp/platform/calendar_data_gateway.dart';
import 'package:archiveme_mobile/services/mcp/platform/health_data_gateway.dart';

/// Read-only MCP tool: fetch calendar events from the OS calendar store.
class FetchCalendarEventsTool {
  FetchCalendarEventsTool({
    required McpPermissionGate permissionGate,
    CalendarDataGateway? calendarGateway,
  }) : _permissionGate = permissionGate,
       _calendarGateway = calendarGateway ?? DeviceCalendarGateway();

  final McpPermissionGate _permissionGate;
  final CalendarDataGateway _calendarGateway;

  static const definition = McpToolDefinition(
    name: McpToolNames.fetchCalendarEvents,
    description:
        'Read calendar events from the on-device calendar store. Local-only; never leaves the device.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'start': {
          'type': 'string',
          'format': 'date-time',
          'description': 'Inclusive range start (ISO-8601 UTC).',
        },
        'end': {
          'type': 'string',
          'format': 'date-time',
          'description': 'Inclusive range end (ISO-8601 UTC).',
        },
        'calendarIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Optional subset of calendar identifiers.',
        },
      },
    },
  );

  Future<Object?> invoke(Object? rawParams) async {
    final decision = await _permissionGate.evaluateTool(definition.name);
    if (!decision.permitted) {
      throw McpToolExecutionException(_permissionGate.errorFor(decision));
    }

    final params = _paramsMap(rawParams);
    final query = McpCalendarQuery.fromJson(params);
    final events = await _calendarGateway.fetchEvents(query);

    return {
      'events': events.map((event) => event.toJson()).toList(),
      'count': events.length,
      'localOnly': true,
    };
  }
}

/// Read-only MCP tool: fetch local health metrics from HealthKit / Health Connect.
class FetchLocalHealthMetricsTool {
  FetchLocalHealthMetricsTool({
    required McpPermissionGate permissionGate,
    HealthDataGateway? healthGateway,
  }) : _permissionGate = permissionGate,
       _healthGateway = healthGateway ?? HealthKitGateway();

  final McpPermissionGate _permissionGate;
  final HealthDataGateway _healthGateway;

  static const definition = McpToolDefinition(
    name: McpToolNames.fetchLocalHealthMetrics,
    description:
        'Read local health metrics from HealthKit (iOS) or Health Connect (Android). Local-only.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'start': {
          'type': 'string',
          'format': 'date-time',
          'description': 'Inclusive range start (ISO-8601 UTC).',
        },
        'end': {
          'type': 'string',
          'format': 'date-time',
          'description': 'Inclusive range end (ISO-8601 UTC).',
        },
        'metricTypes': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Optional metric keys: steps, heart_rate, sleep_asleep, active_energy.',
        },
      },
    },
  );

  Future<Object?> invoke(Object? rawParams) async {
    final decision = await _permissionGate.evaluateTool(definition.name);
    if (!decision.permitted) {
      throw McpToolExecutionException(_permissionGate.errorFor(decision));
    }

    final params = _paramsMap(rawParams);
    final query = McpHealthQuery.fromJson(params);
    final samples = await _healthGateway.fetchMetrics(query);

    return {
      'metrics': samples.map((sample) => sample.toJson()).toList(),
      'count': samples.length,
      'localOnly': true,
    };
  }
}

class McpToolExecutionException implements Exception {
  McpToolExecutionException(this.error);

  final McpJsonRpcError error;

  @override
  String toString() => 'McpToolExecutionException(${error.message})';
}

Map<String, dynamic> _paramsMap(Object? rawParams) {
  if (rawParams == null) return const {};
  if (rawParams is Map<String, dynamic>) return rawParams;
  if (rawParams is Map) {
    return rawParams.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  throw McpToolExecutionException(
    const McpJsonRpcError(
      code: McpErrorCodes.invalidParams,
      message: 'Tool params must be a JSON object.',
    ),
  );
}

String encodeMcpJson(Object? value) => jsonEncode(value);

Object? decodeMcpJson(String raw) => jsonDecode(raw);
