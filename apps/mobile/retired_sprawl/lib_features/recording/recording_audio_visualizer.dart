part of 'recording_screen.dart';

const _recordingStatusFallback = 'Recording';
const _recordingReadyStatusFallback = 'Ready to record';
const _recordingProcessingStatusFallback = 'Processing';
const _recordingSavedStatusFallback = 'Saved';
const _recordingStopAndSaveHintFallback =
    'Tap Stop and save when you are finished.';

String _recordingInProgressSecondsFallback(int seconds) {
  if (seconds == 1) return 'Recording in progress, 1 second';
  return 'Recording in progress, $seconds seconds';
}

AppLocalizations? _appLocalizations(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations);

class _RecordingStatusCard extends ConsumerWidget {
  const _RecordingStatusCard({required this.stageLabel});

  final String stageLabel;

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
    final stopHint =
        l10n?.recordingStopAndSaveHint ?? _recordingStopAndSaveHintFallback;

    final transcript = ref.watch(streamingTranscriptProvider);
    final ink = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: semanticsLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RecordingWaveform(
            controller: ref.read(recordingWaveformControllerProvider),
            height: 88,
          ),
          const SizedBox(height: 16),
          StreamingTranscriptText(
            text: transcript.isEmpty ? statusText : transcript,
          ),
          const SizedBox(height: 8),
          Text(
            timer,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: ink.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stopHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: ink.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen actions owned by the audio responsibility.
extension _RecordingAudioStateActions on _RecordScreenState {
  Future<void> _beginRecording() async {
    if (AppConfig.enableLiveVoiceCapture && _liveVoice != null) {
      await _openLiveVoiceSession();
      return;
    }
    _recordLog('start requested');
    _stopAndProcessInFlight = false;
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
