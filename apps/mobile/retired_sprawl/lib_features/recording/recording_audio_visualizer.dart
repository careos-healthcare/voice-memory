part of 'recording_screen.dart';

const _recordingStatusFallback = 'Recording';
const _recordingReadyStatusFallback = 'Ready to record';
const _recordingProcessingStatusFallback = 'Processing';
const _recordingSavedStatusFallback = 'Saved';

String _recordingInProgressSecondsFallback(int seconds) {
  if (seconds == 1) return 'Recording in progress, 1 second';
  return 'Recording in progress, $seconds seconds';
}

AppLocalizations? _appLocalizations(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations);

class _RecordingStatusCard extends ConsumerWidget {
  const _RecordingStatusCard({
    required this.stageLabel,
    required this.onStop,
    required this.onPause,
    required this.paused,
    required this.showResurfacing,
  });

  final String stageLabel;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final bool paused;
  final bool showResurfacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(recordingDurationSecondsProvider);
    final l10n = _appLocalizations(context);
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timer =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final semanticsLabel =
        l10n?.recordingInProgressSeconds(seconds) ??
        _recordingInProgressSecondsFallback(seconds);
    final statusText = stageLabel.isEmpty
        ? (l10n?.recordingStatus ?? _recordingStatusFallback)
        : stageLabel;
    final height = MediaQuery.sizeOf(context).height;
    final thumbInset = MediaQuery.paddingOf(context).bottom + 24;

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        key: const Key('recording_fullscreen'),
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: const Color(0xFF0F1419),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, thumbInset),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: showResurfacing
                      ? const IdleResurfacingPrompt(onDark: true)
                      : Text(
                          statusText,
                          style: const TextStyle(
                            color: Color(0xFFB7C0CC),
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  timer,
                  key: const Key('recording_duration_timer'),
                  style: const TextStyle(
                    color: Color(0xFFF8F6F1),
                    fontSize: 56,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: RecordingWaveform(
                    controller: ref.read(recordingWaveformControllerProvider),
                    height: 96,
                    color: const Color(0xFFE7E1D6),
                    ambientWhenIdle: true,
                  ),
                ),
                const SizedBox(height: 16),
                const Expanded(child: _LiveDraftTranscriptSlot()),
                Row(
                  key: const Key('recording_thumb_zone'),
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 64,
                        child: OutlinedButton.icon(
                          key: const Key('recording_pause'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF8F6F1),
                            side: const BorderSide(color: Color(0xFFF8F6F1)),
                          ),
                          onPressed: onPause,
                          icon: Icon(
                            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            size: 28,
                          ),
                          label: Text(
                            paused ? 'Resume' : 'Pause',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 64,
                        child: FilledButton.icon(
                          key: const Key('recording_stop'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF8F6F1),
                            foregroundColor: const Color(0xFF0F1419),
                          ),
                          onPressed: onStop,
                          icon: const Icon(Icons.stop_rounded, size: 28),
                          label: Text(
                            ConsumerUiCopy.stopRecordingCta,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Labeled draft area. Hidden unless the live-draft flag is on.
class _LiveDraftTranscriptSlot extends StatefulWidget {
  const _LiveDraftTranscriptSlot();

  @override
  State<_LiveDraftTranscriptSlot> createState() =>
      _LiveDraftTranscriptSlotState();
}

class _LiveDraftTranscriptSlotState extends State<_LiveDraftTranscriptSlot> {
  StreamSubscription<String>? _partials;
  String _text = '';

  @override
  void initState() {
    super.initState();
    if (!V1CapabilityRegistry.liveDraftTranscript ||
        !LiveDraftTranscript.supportsOnDeviceStreaming) {
      return;
    }
    _partials = LiveDraftTranscript.partials().listen((text) {
      if (!mounted || text.trim().isEmpty) return;
      setState(() => _text = text);
    });
    unawaited(LiveDraftTranscript.start());
  }

  @override
  void dispose() {
    unawaited(_partials?.cancel());
    if (V1CapabilityRegistry.liveDraftTranscript) {
      unawaited(LiveDraftTranscript.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.liveDraftTranscript) {
      return const SizedBox.shrink();
    }
    final waiting = _text.trim().isEmpty;
    return SizedBox(
      key: const Key('recording_live_draft'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live draft transcript',
            style: TextStyle(
              color: Color(0xFF8E99A8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                waiting ? 'Words appear here as you speak.' : _text,
                key: const Key('recording_live_draft_text'),
                style: TextStyle(
                  color: waiting
                      ? const Color(0xFF8E99A8)
                      : const Color(0xFFF8F6F1),
                  fontSize: 16,
                  height: 1.4,
                  fontFamily: 'Newsreader',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen actions owned by the audio responsibility.
extension _RecordingAudioStateActions on _RecordScreenState {
  Future<void> _toggleCapturePause() async {
    if (_capturePaused) {
      await _recording.resumeActiveRecording();
    } else {
      await _recording.pauseActiveRecording();
    }
    if (!mounted) return;
    _setRecordingState(() => _capturePaused = !_capturePaused);
  }

  Future<void> _beginRecording() async {
    if (AppConfig.enableLiveVoiceCapture && _liveVoice != null) {
      await _openLiveVoiceSession();
      return;
    }
    _recordLog('start requested');
    _stopAndProcessInFlight = false;
    _capturePaused = false;
    _navigationActivity.update(RecordNavigationActivity.recording);
    try {
      await _recording.startRecording(permissionVerified: true);
      if (!mounted) return;
      _setRecordingState(() {
        _ui = RecordUiState.recording;
        _stageLabel = 'Recording…';
        _mic = RecordingPhase.ready;
      });
      if (TrialMode.enabled) {
        await ActivationTracker.trackTrialRecordingStarted();
      }
      unawaited(FirstLoopActivationCoordinator.markRecordingStarted());
      if (_dueCheckInToday != null) {
        unawaited(
          ReturnDayFrictionCoordinator.markRecordingStarted(
            _dueCheckInToday!.id,
          ),
        );
      }
      _recordLog('start success');
      _recordLog('state ui=$_ui (recording)');
    } on RecordingException catch (e, stackTrace) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed ${e.message}');
      if (!mounted) return;
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    } catch (e, stackTrace) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed $e');
      if (kDebugMode) {
        AppLogger.debug('$stackTrace');
      }
      if (!mounted) return;
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    }
  }

  bool get _showReadyToRecordStatus =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showReadyToRecordStatus(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  String _statusTextFor(RecordUiState ui, String? localSaveTitle) {
    final l10n = _appLocalizations(context);
    if (l10n == null) {
      switch (ui) {
        case RecordUiState.permissionBlocked:
          return MicrophonePermissionCopy.statusBlocked;
        case RecordUiState.requestingPermission:
          return MicrophonePermissionCopy.statusRequesting;
        case RecordUiState.ready:
          return _recordingReadyStatusFallback;
        case RecordUiState.recording:
          return _recordingStatusFallback;
        case RecordUiState.processing:
          return _recordingProcessingStatusFallback;
        case RecordUiState.done:
          return localSaveTitle ?? _recordingSavedStatusFallback;
        default:
          return _recordingStatusFallback;
      }
    }
    switch (ui) {
      case RecordUiState.permissionBlocked:
        return MicrophonePermissionCopy.statusBlocked;
      case RecordUiState.requestingPermission:
        return MicrophonePermissionCopy.statusRequesting;
      case RecordUiState.ready:
        return l10n.recordingReadyStatus;
      case RecordUiState.recording:
        return l10n.recordingStatus;
      case RecordUiState.processing:
        return l10n.recordingProcessingStatus;
      case RecordUiState.done:
        return localSaveTitle ?? l10n.recordingSavedStatus;
      default:
        return l10n.recordingStatus;
    }
  }
}