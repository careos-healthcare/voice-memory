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
  const _RecordingStatusCard({required this.stageLabel, required this.onStop});

  final String stageLabel;
  final VoidCallback onStop;

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
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        key: const Key('recording_fullscreen'),
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1419),
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                Text(
                  statusText,
                  style: const TextStyle(color: Color(0xFFB7C0CC), fontSize: 14),
                ),
                const Spacer(),
                Text(
                  timer,
                  style: const TextStyle(
                    color: Color(0xFFF8F6F1),
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 28),
                RecordingWaveform(
                  controller: ref.read(recordingWaveformControllerProvider),
                  height: 96,
                  color: const Color(0xFFE7E1D6),
                  ambientWhenIdle: true,
                ),
                const Spacer(),
                Text(
                  stopHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E99A8)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
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
              ],
            ),
          ),
        ),
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