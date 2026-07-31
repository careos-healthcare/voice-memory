part of '../../screens/record_screen.dart';

class _RecordingStatusCard extends StatelessWidget {
  const _RecordingStatusCard({
    required this.seconds,
    required this.stageLabel,
    required this.audioDecibels,
  });

  final int seconds;
  final String stageLabel;
  final Stream<double> audioDecibels;

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timer =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Semantics(
      label: l10n.recordingInProgressSeconds(seconds),
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
            AudioVisualizer(decibels: audioDecibels),
            const SizedBox(height: 12),
            RecordingTranscriptionView(
              text: stageLabel.isEmpty ? l10n.recordingStatus : stageLabel,
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
              l10n.recordingStopAndSaveHint,
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
  Future<bool> _hasRecordingSubscriptionAccess() async {
    final service =
        widget.subscriptionService ??
        (AppServices.isInitialized
            ? AppServices.instance.subscriptionService
            : null);
    if (service == null || !service.canOfferWebCheckout) return true;

    try {
      if (await service.hasActiveSubscription()) return true;
    } on Object {
      if (AppServices.isInitialized &&
          AppServices.instance.subscriptionRepository.currentState?.isPro ==
              true) {
        return true;
      }
    }

    if (!mounted) return false;
    await context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        source: PaywallSource.generalPro,
        sourceRoute: '/record',
      ),
    );
    return false;
  }

  Future<void> _beginRecording() async {
    if (AppConfig.enableLiveVoiceCapture && _liveVoice != null) {
      await _openLiveVoiceSession();
      return;
    }
    _recordLog('start requested');
    _stopAndProcessInFlight = false;
    _navigationActivity.update(RecordNavigationActivity.recording);
    try {
      var isPro = false;
      try {
        isPro = await ArchiveEntitlementReader.forAccessCheck().isPro;
      } on Object {
        // Fail closed to the free duration when billing is unavailable.
      }
      _activeRecordingMaxSeconds = RecordingDurationPolicy.maxSecondsFor(
        isPro: isPro,
      );
      await _recording.startRecording(
        permissionVerified: true,
        maxDurationSeconds: _activeRecordingMaxSeconds,
      );
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
    final l10n = appLocalizationsOf(context);
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
