import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _globalChannel = MethodChannel('xyz.luan/audioplayers.global');
const _playerChannel = MethodChannel('xyz.luan/audioplayers');
const _globalEventsChannel = MethodChannel(
  'xyz.luan/audioplayers.global/events',
);

final Set<String> _playerEventChannelNames = <String>{};
bool _installed = false;

/// Installs a deterministic no-audio platform boundary for widget tests.
///
/// `audioplayers` creates per-player event channels dynamically, so this
/// registers those channels when the plugin's `create` call exposes a player
/// id. Position and duration queries return zero; mutating calls return null.
void installMockAudioplayers() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_installed) return;
  _installed = true;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_globalChannel, (_) async => null);
  messenger.setMockMethodCallHandler(_globalEventsChannel, (_) async => null);
  messenger.setMockMethodCallHandler(_playerChannel, (call) async {
    if (call.method == 'create') {
      final arguments = call.arguments;
      if (arguments is Map) {
        final playerId = arguments['playerId'];
        if (playerId is String && playerId.isNotEmpty) {
          _registerPlayerEventChannel(playerId);
        }
      }
    }
    return switch (call.method) {
      'getCurrentPosition' || 'getDuration' => 0,
      _ => null,
    };
  });
}

/// Removes all handlers installed by [installMockAudioplayers].
///
/// Dispose app services and audio players before calling this function.
void uninstallMockAudioplayers() {
  if (!_installed) return;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_globalChannel, null);
  messenger.setMockMethodCallHandler(_globalEventsChannel, null);
  messenger.setMockMethodCallHandler(_playerChannel, null);
  for (final name in _playerEventChannelNames) {
    messenger.setMockMethodCallHandler(MethodChannel(name), null);
  }
  _playerEventChannelNames.clear();
  _installed = false;
}

void _registerPlayerEventChannel(String playerId) {
  final name = 'xyz.luan/audioplayers/events/$playerId';
  if (!_playerEventChannelNames.add(name)) return;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
}