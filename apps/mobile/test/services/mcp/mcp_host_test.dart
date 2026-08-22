import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/services/mcp/mcp.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('McpLocalSandbox', () {
    const sandbox = McpLocalSandbox();

    test('allows local tool calls without network hints', () {
      final violation = sandbox.validateRequest(
        McpJsonRpcRequest.fromJson({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchCalendarEvents,
          'params': {
            'start': '2026-01-01T00:00:00.000Z',
            'end': '2026-01-07T00:00:00.000Z',
          },
          'id': 1,
        }),
      );
      expect(violation, isNull);
    });

    test('blocks remote URLs in params', () {
      final violation = sandbox.validateRequest(
        McpJsonRpcRequest.fromJson({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchCalendarEvents,
          'params': {'endpoint': 'https://example.com/events'},
          'id': 1,
        }),
      );
      expect(violation, McpSandboxViolation.externalUrl);
    });

    test('blocks unknown tools', () {
      final violation = sandbox.validateRequest(
        McpJsonRpcRequest.fromJson({
          'jsonrpc': '2.0',
          'method': 'uploadToRemote',
          'id': 1,
        }),
      );
      expect(violation, McpSandboxViolation.disallowedTool);
    });
  });

  group('McpPermissionGate', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late McpOsDataConsentStore consentStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_gate_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      consentStore = McpOsDataConsentStore(prefs);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('denies calendar tool when capability disabled', () async {
      final gate = McpPermissionGate(consentStore: consentStore);
      final decision = await gate.evaluateTool(McpToolNames.fetchCalendarEvents);
      expect(decision.permitted, isFalse);
      expect(decision.reason, McpPermissionBlockReason.capabilityDisabled);
    });

    test('denies when user consent missing', () async {
      final gate = McpPermissionGate(
        consentStore: consentStore,
        calendarPermission: FakeCalendarPermissionGateway(granted: true),
        enabledCapabilities: {McpOsDataDomain.calendar: true},
      );
      final decision = await gate.evaluateTool(McpToolNames.fetchCalendarEvents);
      expect(decision.permitted, isFalse);
      expect(decision.reason, McpPermissionBlockReason.userConsentMissing);
    });

    test('denies when OS permission missing', () async {
      await consentStore.grant(domains: {McpOsDataDomain.calendar});
      final gate = McpPermissionGate(
        consentStore: consentStore,
        calendarPermission: FakeCalendarPermissionGateway(granted: false),
        enabledCapabilities: {McpOsDataDomain.calendar: true},
      );
      final decision = await gate.evaluateTool(McpToolNames.fetchCalendarEvents);
      expect(decision.permitted, isFalse);
      expect(decision.reason, McpPermissionBlockReason.osPermissionDenied);
    });

    test('permits when consent, capability, and OS permission satisfied', () async {
      await consentStore.grant(domains: {McpOsDataDomain.health});
      final gate = McpPermissionGate(
        consentStore: consentStore,
        healthPermission: FakeHealthPermissionGateway(granted: true),
        enabledCapabilities: {McpOsDataDomain.health: true},
      );
      final decision = await gate.evaluateTool(
        McpToolNames.fetchLocalHealthMetrics,
      );
      expect(decision.permitted, isTrue);
      expect(decision.domain, McpOsDataDomain.health);
    });
  });

  group('McpHost tools', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late FakeCalendarDataGateway calendarGateway;
    late FakeHealthDataGateway healthGateway;
    late McpHost host;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_host_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      calendarGateway = FakeCalendarDataGateway(
        events: [
          McpCalendarEvent(
            id: 'evt-1',
            title: 'Team sync',
            start: DateTime.utc(2026, 1, 10, 14),
            end: DateTime.utc(2026, 1, 10, 15),
            calendarName: 'Work',
          ),
        ],
      );
      healthGateway = FakeHealthDataGateway(
        samples: [
          McpHealthMetricSample(
            type: 'steps',
            value: 8421,
            unit: 'count',
            recordedAt: DateTime.utc(2026, 1, 10, 23, 59),
          ),
        ],
      );
      host = McpHost.fromPrefs(
        prefs,
        calendarGateway: calendarGateway,
        healthGateway: healthGateway,
        calendarPermission: FakeCalendarPermissionGateway(granted: true),
        healthPermission: FakeHealthPermissionGateway(granted: true),
        enabledCapabilities: {
          McpOsDataDomain.calendar: true,
          McpOsDataDomain.health: true,
        },
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('lists read-only tools', () {
      final tools = host.listTools();
      expect(tools.map((tool) => tool.name), contains(McpToolNames.fetchCalendarEvents));
      expect(tools.map((tool) => tool.name), contains(McpToolNames.fetchLocalHealthMetrics));
    });

    test('fetchCalendarEvents requires consent', () async {
      final raw = await host.handleJson(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchCalendarEvents,
          'params': {
            'start': '2026-01-01T00:00:00.000Z',
            'end': '2026-01-31T00:00:00.000Z',
          },
          'id': 'calendar-1',
        }),
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
      expect(decoded['error']['code'], McpErrorCodes.permissionDenied);
      expect(calendarGateway.fetchCallCount, 0);
    });

    test('fetchCalendarEvents returns local events after consent', () async {
      await McpOsDataConsentStore(prefs).grant(
        domains: {McpOsDataDomain.calendar},
      );

      final raw = await host.handleJson(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchCalendarEvents,
          'params': {
            'start': '2026-01-01T00:00:00.000Z',
            'end': '2026-01-31T00:00:00.000Z',
          },
          'id': 'calendar-2',
        }),
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['error'], isNull);
      final result = decoded['result'] as Map<String, dynamic>;
      expect(result['localOnly'], isTrue);
      expect(result['count'], 1);
      expect(calendarGateway.fetchCallCount, 1);
    });

    test('fetchLocalHealthMetrics returns local metrics after consent', () async {
      await McpOsDataConsentStore(prefs).grant(
        domains: {McpOsDataDomain.health},
      );

      final raw = await host.handleJson(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchLocalHealthMetrics,
          'params': {
            'start': '2026-01-01T00:00:00.000Z',
            'end': '2026-01-31T00:00:00.000Z',
            'metricTypes': ['steps'],
          },
          'id': 'health-1',
        }),
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['error'], isNull);
      final result = decoded['result'] as Map<String, dynamic>;
      expect(result['localOnly'], isTrue);
      expect(result['count'], 1);
      expect(healthGateway.fetchCallCount, 1);
    });

    test('sandbox blocks network-like params before permission gate', () async {
      await McpOsDataConsentStore(prefs).grant(
        domains: {McpOsDataDomain.calendar},
      );

      final raw = await host.handleJson(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': McpToolNames.fetchCalendarEvents,
          'params': {'remoteUrl': 'https://evil.example/calendar'},
          'id': 'sandbox-1',
        }),
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['error']['code'], McpErrorCodes.sandboxViolation);
      expect(calendarGateway.fetchCallCount, 0);
    });
  });

  group('McpInProcessChannel', () {
    test('routes initialize over in-process IPC', () async {
      final tempDir = await Directory.systemTemp.createTemp('mcp_ipc_');
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final host = McpHost.fromPrefs(prefs);
      final channel = McpInProcessChannel(host);

      final raw = await channel.send(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'id': 1,
        }),
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['result']['serverInfo']['localOnly'], isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}
