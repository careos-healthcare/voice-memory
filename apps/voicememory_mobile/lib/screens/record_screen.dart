import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_exceptions.dart';
import '../audio/recording_service.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scaffold_shell.dart';

enum RecordUiState {
  idle,
  permissionBlocked,
  ready,
  recording,
  processing,
  done,
  error,
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  RecordUiState _ui = RecordUiState.idle;
  RecordingPhase _mic = RecordingPhase.idle;
  int _seconds = 0;
  String? _error;
  String _stageLabel = '';
  PipelineStage? _pipelineStage;

  late final RecordingService _recording;
  late final CapturePipelineService _pipeline;

  @override
  void initState() {
    super.initState();
    final s = AppServices.instance;
    _recording = s.recording;
    _pipeline = s.pipeline;
    _recording.durationSeconds.listen((s) {
      if (mounted) setState(() => _seconds = s);
    });
    _refreshMic();
  }

  Future<void> _refreshMic() async {
    final cap = await _recording.checkMicrophone();
    setState(() {
      _mic = cap;
      _ui = cap == RecordingPhase.ready
          ? RecordUiState.ready
          : cap == RecordingPhase.permissionPermanentlyDenied ||
                  cap == RecordingPhase.permissionDenied
              ? RecordUiState.permissionBlocked
              : RecordUiState.idle;
    });
  }

  Future<void> _requestMic() async {
    final cap = await _recording.requestMicrophone();
    setState(() {
      _mic = cap;
      _ui = cap == RecordingPhase.ready
          ? RecordUiState.ready
          : RecordUiState.permissionBlocked;
    });
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _seconds = 0;
    });
    try {
      await _recording.startRecording();
      setState(() {
        _ui = RecordUiState.recording;
        _stageLabel = 'Recording…';
      });
    } on RecordingException catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = e.message;
      });
    }
  }

  Future<void> _stopAndProcess() async {
    setState(() {
      _ui = RecordUiState.processing;
      _stageLabel = 'Stopping…';
    });
    try {
      final result = await _recording.stopRecording();
      setState(() => _stageLabel = 'Attesting device…');
      final pipelineResult = await _pipeline.run(
        audioFile: result.file,
        durationSeconds: result.durationSeconds,
        onStage: (stage) {
          if (!mounted) return;
          setState(() {
            _pipelineStage = stage;
            _stageLabel = switch (stage) {
              PipelineStage.attesting => 'Securing capture…',
              PipelineStage.transcribing => 'Transcribing…',
              PipelineStage.analyzing => 'Reflecting…',
              PipelineStage.saving => 'Saving…',
              PipelineStage.done => 'Done',
            };
          });
        },
      );
      if (!mounted) return;
      setState(() => _ui = RecordUiState.done);
      context.go('/entry/${pipelineResult.entry.id}');
    } on ApiException catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = _friendlyApiError(e);
      });
    } on RecordingException catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = 'Something went wrong. Check API URL and that the web server is running.';
      });
    }
  }

  String _friendlyApiError(ApiException e) {
    if (e.statusCode == 413) {
      return 'Recording is too large. Try a shorter reflection.';
    }
    if (e.statusCode == 429) {
      return e.message;
    }
    if (e.statusCode == 401) {
      return 'Capture authorization failed. Try again.';
    }
    if (e.statusCode == 422) {
      return 'No speech detected. Try speaking a little longer.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = _ui == RecordUiState.ready || _ui == RecordUiState.recording;
    return ScaffoldShell(
      title: 'Record',
      showTrustBanner: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Recording status',
              child: Text(
                _stageLabel.isEmpty ? _statusText() : _stageLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_ui == RecordUiState.recording || _ui == RecordUiState.processing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _ui == RecordUiState.recording
                      ? '$_seconds s'
                      : _pipelineStage?.name ?? '',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Spacer(),
            if (_ui == RecordUiState.permissionBlocked) ...[
              const Text(
                'Microphone access is required to record.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _requestMic,
                child: const Text('Allow microphone'),
              ),
            ],
            if (_ui == RecordUiState.ready)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic),
                label: const Text('Start recording'),
              ),
            if (_ui == RecordUiState.recording)
              FilledButton.icon(
                onPressed: _stopAndProcess,
                icon: const Icon(Icons.stop),
                label: const Text('Stop and save'),
              ),
            if (_ui == RecordUiState.error || _ui == RecordUiState.done) ...[
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _ui = _mic == RecordingPhase.ready
                        ? RecordUiState.ready
                        : RecordUiState.permissionBlocked;
                  });
                },
                child: const Text('Try again'),
              ),
            ],
            if (!canRecord && _ui == RecordUiState.idle)
              OutlinedButton(
                onPressed: _requestMic,
                child: const Text('Set up microphone'),
              ),
          ],
        ),
      ),
    );
  }

  String _statusText() {
    switch (_ui) {
      case RecordUiState.permissionBlocked:
        return 'Microphone blocked';
      case RecordUiState.ready:
        return 'Ready to record';
      case RecordUiState.recording:
        return 'Recording';
      case RecordUiState.processing:
        return 'Processing';
      case RecordUiState.done:
        return 'Saved';
      default:
        return 'Voice reflection';
    }
  }
}
