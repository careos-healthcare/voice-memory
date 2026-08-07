import 'package:voicememory_mobile/audio/playback_service.dart';

/// Test-only playback with no platform audio I/O.
PlaybackService silentPlaybackService() =>
    PlaybackService.create(testMode: true);
