import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_voice_playback_player.dart';

void main() {
  group('LiveVoicePlaybackPlayer', () {
    test('loadSession resets position and state', () {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(seconds: 30));

      expect(player.state, PlaybackState.stopped);
      expect(player.position, Duration.zero);
      expect(player.totalDuration, const Duration(seconds: 30));
      expect(player.isPlaying, isFalse);
    });

    test('play advances position until end then pauses', () async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(milliseconds: 120));
      player.play();

      expect(player.isPlaying, isTrue);

      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (player.state == PlaybackState.playing &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(player.state, PlaybackState.paused);
      expect(player.position, const Duration(milliseconds: 120));
      expect(player.isPlaying, isFalse);
    });

    test('seek clamps position within total duration', () {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(seconds: 10));
      player.seek(const Duration(seconds: 20));

      expect(player.position, const Duration(seconds: 10));

      player.seek(const Duration(seconds: -1));

      expect(player.position, Duration.zero);
    });

    test('stop resets position and cancels playback', () async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(seconds: 5));
      player.play();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      player.stop();

      expect(player.state, PlaybackState.stopped);
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isFalse);
    });
    test('updateTotalDuration extends active session bounds', () {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(seconds: 2));
      player.updateTotalDuration(const Duration(seconds: 5));

      expect(player.totalDuration, const Duration(seconds: 5));
    });

    test('durationForPcm16LeBytes estimates output chunk length', () {
      final duration = LiveVoicePlaybackPlayer.durationForPcm16LeBytes(
        List<int>.filled(4800, 0),
        sampleRateHz: 24000,
        numChannels: 1,
      );

      expect(duration, const Duration(milliseconds: 100));
    });
  });
}
