import 'package:archiveme_mobile/features/capture/audio/archive_me_audio_handler.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:audio_service/audio_service.dart';

/// Initializes and controls the background capture [ArchiveMeAudioHandler].
class BackgroundCaptureService {
  BackgroundCaptureService({required this.config});

  final CaptureModuleRuntimeConfig config;
  ArchiveMeAudioHandler? _handler;

  Future<void> ensureInitialized() async {
    if (_handler != null) return;
    CaptureModuleRuntimeConfig.instance = config;
    _handler = await AudioService.init(
      builder: ArchiveMeAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.voicememory.mobile.capture',
        androidNotificationChannelName: 'ArchiveMe recording',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  Future<void> startBackgroundCapture() async {
    await ensureInitialized();
    await _handler!.customAction('startCapture');
  }

  Future<void> stopBackgroundCapture() async {
    final handler = _handler;
    if (handler == null) return;
    await handler.customAction('stopCapture');
  }

  Stream<dynamic> get captureEvents =>
      _handler?.customEvent ?? const Stream<dynamic>.empty();
}
