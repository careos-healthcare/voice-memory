import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../audio_digest_speaker.dart';

abstract interface class MorningBriefingAudioController {
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  });

  Future<void> play({required String narration, Uint8List? encryptedAudio});
  Future<void> stop();
  Future<void> dispose();
}

class PlatformMorningBriefingAudioController
    implements MorningBriefingAudioController {
  PlatformMorningBriefingAudioController({
    AudioPlayer? player,
    AudioDigestSpeaker? speaker,
  }) : _player = player ?? AudioPlayer(),
       _speaker = speaker ?? FlutterTtsAudioDigestSpeaker();

  final AudioPlayer _player;
  final AudioDigestSpeaker _speaker;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VoidCallback? _onStarted;
  VoidCallback? _onCompleted;
  ValueChanged<String>? _onError;
  bool _playingBytes = false;

  @override
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _onStarted = onStarted;
    _onCompleted = onCompleted;
    _onError = onError;
    _subscriptions.add(
      _player.onPlayerStateChanged.listen((state) {
        if (!_playingBytes) return;
        if (state == PlayerState.playing) _onStarted?.call();
      }),
    );
    _subscriptions.add(
      _player.onPlayerComplete.listen((_) {
        if (_playingBytes) _onCompleted?.call();
      }),
    );
    await _speaker.initialize(
      onStarted: onStarted,
      onCompleted: onCompleted,
      onError: onError,
    );
  }

  @override
  Future<void> play({
    required String narration,
    Uint8List? encryptedAudio,
  }) async {
    await stop();
    if (encryptedAudio != null && encryptedAudio.isNotEmpty) {
      _playingBytes = true;
      try {
        await _player.play(BytesSource(encryptedAudio));
      } on Object catch (error) {
        _playingBytes = false;
        _onError?.call(error.toString());
      }
      return;
    }
    _playingBytes = false;
    await _speaker.speak(narration);
  }

  @override
  Future<void> stop() async {
    if (_playingBytes) {
      await _player.stop();
    }
    await _speaker.stop();
    _playingBytes = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _speaker.dispose();
    await _player.dispose();
  }
}
