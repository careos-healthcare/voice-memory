import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/capture/vad/record_pcm_stream_factory.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_streaming_service.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

/// Segments an active capture session into smaller WAV thought chunks.
///
/// Runs a lightweight PCM16 sidecar stream so the primary m4a/caf container
/// stays intact while VAD emits bounded WAV segments for local processing.
class VadSegmentedRecordingCoordinator {
  VadSegmentedRecordingCoordinator({
    VadStreamingService? vad,
    RecordPcmStreamFactory? pcmStreamFactory,
  }) : _vad = vad,
       _pcmStreamFactory = pcmStreamFactory ?? defaultRecordPcmStreamFactory;

  VadStreamingService? _vad;
  final RecordPcmStreamFactory _pcmStreamFactory;
  AudioRecorder? _pcmRecorder;
  StreamSubscription<VadSegmentEvent>? _segmentSubscription;
  var _active = false;

  final List<VoiceThoughtSegment> _segments = [];

  List<VoiceThoughtSegment> get segments => List.unmodifiable(_segments);

  Stream<VadSegmentEvent>? get segmentEvents => _vad?.segments;

  bool get isActive => _active;

  Future<void> start({VadStreamConfig config = const VadStreamConfig()}) async {
    if (_active) return;
    _segments.clear();

    final tempDir = await AppStoragePaths.temporaryDirectory();
    final segmentDir = p.join(
      tempDir.path,
      'vad_segments',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _vad ??= await VadStreamingService.create(
      outputDirectory: segmentDir,
      config: config,
    );

    _segmentSubscription = _vad!.segments.listen((event) {
      _segments.add(event.segment);
    });

    await _startPcmSidecar(config);
    _active = true;
  }

  Future<void> _startPcmSidecar(VadStreamConfig config) async {
    _pcmRecorder = AudioRecorder();
    final stream = await _pcmStreamFactory(_pcmRecorder!, config);
    await _vad!.startPcmStream(stream);
  }

  Future<List<VoiceThoughtSegment>> stop() async {
    if (!_active) return List.unmodifiable(_segments);
    _active = false;

    await _segmentSubscription?.cancel();
    _segmentSubscription = null;

    final closing = await _vad?.stop(reason: VadSegmentCloseReason.manualStop);
    if (closing != null) {
      for (final segment in closing) {
        if (!_segments.any((s) => s.filePath == segment.filePath)) {
          _segments.add(segment);
        }
      }
    }

    try {
      await _pcmRecorder?.cancel();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
    await _pcmRecorder?.dispose();
    _pcmRecorder = null;

    return List.unmodifiable(_segments);
  }

  Future<void> dispose() async {
    await stop();
    await _vad?.dispose();
    _vad = null;
  }

  /// Deletes segment files after they have been enqueued for processing.
  Future<void> discardSegmentFiles() async {
    for (final segment in _segments) {
      try {
        final file = File(segment.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } on Object catch (error, stackTrace) {
        AppLogger.error('Unhandled error caught', error: error, stackTrace: stackTrace);
        AppLogger.debug('VAD segment cleanup failed: $error');
      }
    }
    _segments.clear();
  }
}