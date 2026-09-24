import 'package:audioplayers/audioplayers.dart';

/// Playback rates that keep the speaking pitch in place.
///
/// `AudioPlayer.setPlaybackRate` maps to the platform time-stretch:
/// Android `PlaybackParams.setSpeed` and Apple `AVPlayer.rate` both keep
/// pitch at [preservedPitch] for these rates.
abstract final class PitchPreservingPlayback {
  static const preservedPitch = 1.0;
  static const speeds = <double>[1, 1.25, 1.5, 2];

  static String label(double speed) {
    if (speed == 1 || speed == 2) return '${speed.toStringAsFixed(1)}x';
    return '${speed}x';
  }
}

/// Applies a speed change without shifting pitch, then seeks by fraction.
class PitchPreservingTransport {
  const PitchPreservingTransport({
    required this.setRate,
    required this.seekTo,
  });

  factory PitchPreservingTransport.audioplayers(
    AudioPlayer player, {
    required Duration duration,
  }) {
    return PitchPreservingTransport(
      setRate: player.setPlaybackRate,
      seekTo: (fraction) {
        final bounded = fraction.clamp(0, 1).toDouble();
        return player.seek(duration * bounded);
      },
    );
  }

  final Future<void> Function(double speed) setRate;
  final Future<void> Function(double fraction) seekTo;

  Future<void> setSpeed(double speed) {
    if (!PitchPreservingPlayback.speeds.contains(speed)) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Use 1.0x, 1.25x, 1.5x, or 2.0x',
      );
    }
    return setRate(speed);
  }
}
