/// JSON-RPC 2.0 message types for the local MCP host layer.
library;

/// Supported MCP tool names exposed to on-device agents.
abstract final class McpToolNames {
  McpToolNames._();

  static const fetchCalendarEvents = 'fetchCalendarEvents';
  static const fetchLocalHealthMetrics = 'fetchLocalHealthMetrics';

  static const all = {
    fetchCalendarEvents,
    fetchLocalHealthMetrics,
  };
}

/// Standard JSON-RPC error codes used by the local MCP host.
abstract final class McpErrorCodes {
  McpErrorCodes._();

  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  static const int sandboxViolation = -32001;
  static const int permissionDenied = -32002;
  static const int capabilityDisabled = -32003;
  static const int osPermissionDenied = -32004;
}

class McpJsonRpcRequest {
  const McpJsonRpcRequest({
    required this.jsonrpc,
    required this.method,
    this.params,
    this.id,
  });

  factory McpJsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return McpJsonRpcRequest(
      jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      method: json['method'] as String? ?? '',
      params: json['params'],
      id: json['id'],
    );
  }

  final String jsonrpc;
  final String method;
  final Object? params;
  final Object? id;

  Map<String, dynamic> toJson() => {
    'jsonrpc': jsonrpc,
    'method': method,
    if (params != null) 'params': params,
    if (id != null) 'id': id,
  };
}

class McpJsonRpcError {
  const McpJsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final Object? data;

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (data != null) 'data': data,
  };
}

class McpJsonRpcResponse {
  const McpJsonRpcResponse({
    required this.jsonrpc,
    this.result,
    this.error,
    this.id,
  });

  factory McpJsonRpcResponse.success({
    required Object? id,
    required Object? result,
  }) {
    return McpJsonRpcResponse(
      jsonrpc: '2.0',
      id: id,
      result: result,
    );
  }

  factory McpJsonRpcResponse.failure({
    required Object? id,
    required McpJsonRpcError error,
  }) {
    return McpJsonRpcResponse(
      jsonrpc: '2.0',
      id: id,
      error: error,
    );
  }

  final String jsonrpc;
  final Object? result;
  final McpJsonRpcError? error;
  final Object? id;

  Map<String, dynamic> toJson() => {
    'jsonrpc': jsonrpc,
    if (result != null) 'result': result,
    if (error != null) 'error': error!.toJson(),
    if (id != null) 'id': id,
  };

  bool get isSuccess => error == null;
}

class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}
