import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_vault_service.dart';

/// Plays one encrypted-vault object through a bounded decrypted lease.
///
/// The lease is created only for playback and is deleted on stop, completion,
/// error, account change, or controller disposal.
final class EncryptedAudioPlaybackController extends ChangeNotifier {
  EncryptedAudioPlaybackController({
    required AudioVaultService vault,
    AudioPlayer? player,
  }) : // Public constructor cannot expose the private field name.
       // ignore: prefer_initializing_formals
       _vault = vault,
       _player = player ?? AudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(stop());
      }
      notifyListeners();
    });
    _positionSubscription = _player.positionStream.listen((_) {
      notifyListeners();
    });
  }

  final AudioVaultService _vault;
  final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  AudioVaultLease? _lease;
  bool _disposed = false;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Future<void> play(
    String vaultReference, {
    Duration initialPosition = Duration.zero,
  }) async {
    await stop();
    final lease = await _vault.openDecryptedLease(vaultReference);
    _lease = lease;
    try {
      await _player.setFilePath(lease.file.path);
      if (initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }
      await _player.play();
    } on Object {
      await _releaseLease();
      rethrow;
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    await _releaseLease();
    if (!_disposed) notifyListeners();
  }

  Future<void> _releaseLease() async {
    final lease = _lease;
    _lease = null;
    await lease?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_playerStateSubscription.cancel());
    unawaited(_positionSubscription.cancel());
    unawaited(_player.dispose());
    unawaited(_releaseLease());
    super.dispose();
  }
}
