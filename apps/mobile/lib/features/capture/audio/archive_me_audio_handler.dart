import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Background [AudioHandler] that records via `record` while the device is locked.
class ArchiveMeAudioHandler extends BaseAudioHandler {
  ArchiveMeAudioHandler();

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  String? _activeCaptureId;
  String? _activeCapturePath;
  StreamSubscription<RecordState>? _recordStateSubscription;

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'startCapture':
        return _startCapture();
      case 'stopCapture':
        return _stopCapture();
      default:
        return super.customAction(name, extras);
    }
  }

  @override
  Future<void> stop() async {
    await _stopCapture();
    await super.stop();
  }

  Future<void> _startCapture() async {
    if (await _recorder.isRecording()) return;

    final config = CaptureModuleRuntimeConfig.instance;
    if (config == null) {
      throw StateError('CaptureModuleRuntimeConfig is not bound');
    }

    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.record,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
    await session.setActive(true);

    final captureId = _uuid.v4();
    final directory = await AppStoragePaths.applicationDocumentsDirectory();
    final captureDir = Directory(p.join(directory.path, 'pending_audio'));
    if (!captureDir.existsSync()) {
      captureDir.createSync(recursive: true);
    }
    final capturePath = p.join(
      captureDir.path,
      '$captureId.m4a',
    );

    final metadataStore = CaptureAudioMetadataStore(
      sqliteFilePath: config.sqliteFilePath,
      encryptionPassword: config.encryptionPassword,
      keyAlias: config.keyAlias,
    );
    await metadataStore.insertPendingOptimistic(
      id: captureId,
      filePath: capturePath,
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
      ),
      path: capturePath,
    );

    _activeCaptureId = captureId;
    _activeCapturePath = capturePath;
    _recordStateSubscription ??= _recorder.onStateChanged().listen(
      _handleRecordState,
    );

    mediaItem.add(
      MediaItem(
        id: captureId,
        title: 'Recording reflection',
        artist: 'ArchiveMe',
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        controls: [MediaControl.stop],
      ),
    );
    customEvent.add({
      'type': 'capture_started',
      'id': captureId,
      'path': capturePath,
    });
  }

  Future<void> _stopCapture() async {
    if (!await _recorder.isRecording()) return;

    final captureId = _activeCaptureId;
    final capturePath = await _recorder.stop();
    final resolvedPath = capturePath ?? _activeCapturePath;

    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: const [],
      ),
    );
    customEvent.add({
      'type': 'capture_stopped',
      'id': captureId,
      'path': resolvedPath,
    });

    _activeCaptureId = null;
    _activeCapturePath = null;
  }

  void _handleRecordState(RecordState state) {
    if (state == RecordState.stop && _activeCaptureId != null) {
      unawaited(_stopCapture());
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await _stopCapture();
    await super.onTaskRemoved();
  }
}
