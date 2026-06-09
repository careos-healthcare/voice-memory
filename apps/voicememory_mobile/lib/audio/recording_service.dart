import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

enum RecordingPhase {
  idle,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  recording,
  error,
}

class RecordingResult {
  const RecordingResult({
    required this.file,
    required this.durationSeconds,
  });

  final File file;
  final int durationSeconds;
}

/// Real microphone capture via `record` package.
class RecordingService {
  RecordingService({AudioRecorder? recorder, bool testMode = false})
      : _testMode = testMode,
        _recorder = testMode ? null : (recorder ?? AudioRecorder());

  final bool _testMode;
  final AudioRecorder? _recorder;

  AudioRecorder get _activeRecorder {
    final r = _recorder;
    if (r == null) throw RecordingException('Recorder not available in test mode.');
    return r;
  }
  DateTime? _startedAt;
  String? _activePath;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();

  Stream<int> get durationSeconds => _durationController.stream;

  Future<RecordingPhase> checkMicrophone() async {
    if (_testMode) {
      _recordLog('permission result ready (test mode)');
      return RecordingPhase.ready;
    }
    final hasRecorder = await _activeRecorder.hasPermission();
    final status = await Permission.microphone.status;
    _recordLog(
      'permission result hasRecorder=$hasRecorder status=$status',
    );
    if (!hasRecorder) {
      if (status.isPermanentlyDenied) {
        return RecordingPhase.permissionPermanentlyDenied;
      }
      return RecordingPhase.permissionDenied;
    }
    return RecordingPhase.ready;
  }

  Future<RecordingPhase> requestMicrophone() async {
    if (_testMode) {
      _recordLog('permission result ready (test mode)');
      return RecordingPhase.ready;
    }
    final result = await Permission.microphone.request();
    _recordLog('permission result request=$result');
    if (result.isGranted) {
      final has = await _activeRecorder.hasPermission();
      _recordLog('permission result hasRecorder=$has after grant');
      return has ? RecordingPhase.ready : RecordingPhase.permissionDenied;
    }
    if (result.isPermanentlyDenied) {
      return RecordingPhase.permissionPermanentlyDenied;
    }
    return RecordingPhase.permissionDenied;
  }

  Future<void> startRecording() async {
    _recordLog('start requested');
    final phase = await checkMicrophone();
    if (phase != RecordingPhase.ready) {
      _recordLog('start failed — microphone phase=$phase');
      throw RecordingException('Microphone not available: $phase');
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/vm_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _activePath = path;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _durationController.add(0);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _durationController.add(_elapsedSeconds);
    });
    try {
      await _activeRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _recordLog('start success path=$path');
    } catch (e, st) {
      _durationTimer?.cancel();
      _durationTimer = null;
      _startedAt = null;
      _activePath = null;
      _recordLog('start failed $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      throw RecordingException('Could not start recording: $e');
    }
  }

  Future<RecordingResult> stopRecording() async {
    final path = await _activeRecorder.stop();
    _durationTimer?.cancel();
    _durationTimer = null;
    final finalPath = path ?? _activePath;
    if (finalPath == null || !File(finalPath).existsSync()) {
      throw RecordingException('Recording file missing after stop.');
    }
    final duration = _startedAt == null
        ? _elapsedSeconds
        : DateTime.now().difference(_startedAt!).inSeconds;
    _startedAt = null;
    _activePath = null;
    return RecordingResult(
      file: File(finalPath),
      durationSeconds: duration < 1 ? 1 : duration,
    );
  }

  Future<bool> get isRecording =>
      _testMode ? Future.value(false) : _activeRecorder.isRecording();

  void dispose() {
    _durationTimer?.cancel();
    if (!_durationController.isClosed) {
      _durationController.close();
    }
    _recorder?.dispose();
  }
}

class RecordingException implements Exception {
  RecordingException(this.message);
  final String message;
  @override
  String toString() => message;
}
