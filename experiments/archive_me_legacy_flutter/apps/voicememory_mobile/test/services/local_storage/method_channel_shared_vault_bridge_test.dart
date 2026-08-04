import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/local_storage/shared_vault_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const iosChannel = MethodChannel('test/os-integration-ios');
  const androidChannel = MethodChannel('test/os-integration-android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(androidChannel, null);
    messenger.setMockMethodCallHandler(iosChannel, null);
  });

  test('parses Android handoffs and reports native status', () async {
    const handoffId = '123e4567-e89b-42d3-a456-426614174000';
    messenger.setMockMethodCallHandler(androidChannel, (call) async {
      switch (call.method) {
        case 'listShareHandoffs':
          return [
            {
              'id': handoffId,
              'createdAt': DateTime.utc(2026, 7, 28).millisecondsSinceEpoch,
              'items': [
                {
                  'index': 0,
                  'kind': 'url',
                  'mimeType': 'text/plain',
                  'size': 27,
                },
              ],
            },
          ];
        case 'readShareItem':
          return Uint8List.fromList('https://example.com/private'.codeUnits);
        case 'extensionStatus':
          return {
            'shareExtensionAvailable': true,
            'widgetExtensionAvailable': true,
            'sharedContainerAvailable': true,
            'lockScreenWidgetsSupported': true,
            'pendingShareCount': 1,
          };
      }
      return null;
    });
    final bridge = MethodChannelSharedVaultPlatformBridge(
      channel: iosChannel,
      androidChannel: androidChannel,
      isAndroid: true,
    );

    final payload = (await bridge.drainNativeInbox()).single;
    expect(payload.kind, SharedPayloadKind.url);
    expect(payload.text, 'https://example.com/private');
    expect(payload.metadata['nativeHandoffId'], handoffId);
    expect((await bridge.extensionStatus())['pendingShareCount'], 1);
  });

  test('deletes malformed Android handoffs', () async {
    const handoffId = '123e4567-e89b-42d3-a456-426614174001';
    final deleted = <String>[];
    messenger.setMockMethodCallHandler(androidChannel, (call) async {
      switch (call.method) {
        case 'listShareHandoffs':
          return [
            {
              'id': handoffId,
              'createdAt': DateTime.utc(2026, 7, 28).millisecondsSinceEpoch,
              'items': [
                {'index': 0, 'kind': 'text', 'size': -1},
              ],
            },
          ];
        case 'deleteShareHandoff':
          deleted.add((call.arguments as Map)['id'] as String);
          return true;
      }
      return null;
    });
    final bridge = MethodChannelSharedVaultPlatformBridge(
      channel: iosChannel,
      androidChannel: androidChannel,
      isAndroid: true,
    );

    expect(await bridge.drainNativeInbox(), isEmpty);
    expect(deleted, [handoffId]);
  });

  test('emits foreground Android handoff events', () async {
    final bridge = MethodChannelSharedVaultPlatformBridge(
      channel: iosChannel,
      androidChannel: androidChannel,
      isAndroid: true,
    );
    final event = bridge.events.first;

    await messenger.handlePlatformMessage(
      androidChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('shareHandoffReady', {'id': 'handoff-ready'}),
      ),
      (_) {},
    );

    expect(
      await event.timeout(const Duration(seconds: 1)),
      isA<SharedVaultPlatformEvent>()
          .having(
            (value) => value.type,
            'type',
            SharedVaultPlatformEventType.shareReady,
          )
          .having((value) => value.handoffId, 'handoffId', 'handoff-ready'),
    );
  });
}
