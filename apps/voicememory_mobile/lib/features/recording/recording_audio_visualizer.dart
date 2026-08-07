part of '../../screens/record_screen.dart';

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
    final semanticsLabel = l10n?.recordingInProgressSeconds(seconds) ??
        _recordingInProgressSecondsFallback(seconds);
    final statusText = stageLabel.isEmpty
        ? (l10n?.recordingStatus ?? _recordingStatusFallback)
        : stageLabel;
    final stopHint =
        l10n?.recordingStopAndSaveHint ?? _recordingStopAndSaveHintFallback;

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 44, color: VoiceMemoryColors.primaryIndigo),
            const SizedBox(height: 14),
            RecordingTranscriptionView(
              text: statusText,
              isLive: true,
            ),
            const SizedBox(height: 8),
            Text(
              timer,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stopHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
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
    } on RecordingException catch (e) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed ${e.message}');
      if (!mounted) return;
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    } catch (e, st) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed $e');
      if (kDebugMode) {
        debugPrint('$st');
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
