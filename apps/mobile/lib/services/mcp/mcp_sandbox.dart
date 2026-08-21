import 'package:archiveme_mobile/services/mcp/mcp_protocol.dart';

/// Reasons a request fails local-only sandbox validation.
enum McpSandboxViolation {
  remoteEndpoint,
  networkTransport,
  disallowedTool,
  externalUrl,
}

/// Validates MCP requests stay on-device with no network egress.
class McpLocalSandbox {
  const McpLocalSandbox({
    this.allowedTools = McpToolNames.all,
  });

  final Set<String> allowedTools;

  static const _networkMethodHints = {
    'http',
    'https',
    'fetch',
    'socket',
    'websocket',
    'upload',
    'download',
    'sync',
    'remote',
  };

  static final RegExp _urlPattern = RegExp(
    r'https?://|wss?://|ftp://',
    caseSensitive: false,
  );

  McpSandboxViolation? validateRequest(McpJsonRpcRequest request) {
    if (!allowedTools.contains(request.method) &&
        request.method != 'initialize' &&
        request.method != 'tools/list') {
      return McpSandboxViolation.disallowedTool;
    }

    final params = request.params;
    if (params == null) return null;

    final serialized = params.toString().toLowerCase();
    if (_urlPattern.hasMatch(serialized)) {
      return McpSandboxViolation.externalUrl;
    }

    for (final hint in _networkMethodHints) {
      if (serialized.contains(hint)) {
        return McpSandboxViolation.networkTransport;
      }
    }

    if (params is Map) {
      for (final entry in params.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('url') ||
            key.contains('endpoint') ||
            key.contains('host') ||
            key.contains('remote')) {
          return McpSandboxViolation.remoteEndpoint;
        }
      }
    }

    return null;
  }

  McpJsonRpcError errorFor(McpSandboxViolation violation) {
    return McpJsonRpcError(
      code: McpErrorCodes.sandboxViolation,
      message: 'Local MCP sandbox violation: ${violation.name}',
      data: {
        'localOnly': true,
        'violation': violation.name,
      },
    );
  }
}
