part of 'recording_screen.dart';

extension RecordingStateHandlers on _RecordScreenState {
  bool _showBeforeYesCardOnRecord(RecordUiState ui) =>
      !_shouldHideCompetingRecordCtas(ui) &&
      _activeLoop?.isCapacityYes == true &&
      CapacityLoopGates.showRecordPrompt(
        capacityWedgeActive: true,
        sampleMode: ScreenshotMode.enabled,
      ) &&
      ui == RecordUiState.ready &&
      _mic == RecordingPhase.ready &&
      _postSavePattern == null;

  bool _showDefaultBoundaryPauseOnRecord(RecordUiState ui) =>
      _defaultBoundaryPauseLabel != null &&
      _activeLoop?.isCapacityYes == true &&
      ui == RecordUiState.ready &&
      _postSavePattern == null &&
      !_shouldHideCompetingRecordCtas(ui) &&
      !_showBeforeYesCardOnRecord(ui);

  bool get _showAdvancedRetentionPostSave {
    if (_isFirstSessionPostSave) return false;
    final count = _entriesAfterSave.isNotEmpty
        ? _entriesAfterSave.length
        : _journalEntryCount;
    return count >= 3;
  }

  void _onStartHereSelected(String prompt) {
    setState(() => _selectedPromptLine = prompt);
    if (_ui == RecordUiState.ready && _mic == RecordingPhase.ready) {
      unawaited(_onRecordPressed(source: 'moment'));
    }
  }

  RecordUiState _uiForMicPhase(RecordingPhase cap) {
    return RecordMicrophonePermissionUi.uiForMicPhase(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
    );
  }

  Future<void> _loadMicPermissionSimulatorHelper() async {
    final showHelper = await MicrophonePermissionEnvironment.isIosSimulator();
    if (!mounted) return;
    if (_showMicPermissionSimulatorHelper != showHelper) {
      setState(() => _showMicPermissionSimulatorHelper = showHelper);
    }
  }

  Future<void> _openMicSettings() async {
    _ignoreStaleMicRefreshAfterGrant = false;
    final openSettings = widget.openAppSettings ?? openMicrophoneSettings;
    await openSettings();
  }

  Future<bool> _acceptSoftPromptBeforeNativeRequest() async {
    final currentStatus = await _microphonePermissionGateway.status;
    if (currentStatus.isGranted) {
      await _onboardingMicStateStore.write(OnboardingMicState.granted);
      return true;
    }
    if (currentStatus.isPermanentlyDenied ||
        currentStatus.isRestricted ||
        currentStatus.isLimited) {
      await _onboardingMicStateStore.write(
        OnboardingMicState.permanentlyDenied,
      );
      if (mounted) await _routeToPermissionPanel();
      return false;
    }

    final funnelState = await _onboardingMicStateStore.read();
    if (funnelState == OnboardingMicState.denied ||
        funnelState == OnboardingMicState.permanentlyDenied) {
      if (mounted) await _routeToPermissionPanel();
      return false;
    }
    return true;
  }

  RecordCtaPolicyResolution _recordCtaPolicy(
    RecordUiState ui, {
    RecordingPhase? micPhase,
    MicrophonePermissionState? micPermissionState,
    bool? userDeniedThisSession,
  }) {
    final phase = micPhase ?? _mic;
    final permission = micPermissionState ?? _micPermissionState;
    // Recorder access (e.g. iOS simulator mismatch) wins over a stale denied phase.
    final effectiveMicPhase =
        permission == MicrophonePermissionState.granted ||
            permission ==
                MicrophonePermissionState.grantedWithPermissionHandlerMismatch
        ? RecordingPhase.ready
        : phase;
    final userDenied = userDeniedThisSession ?? _micPermissionUserDenied;
    return RecordCtaPolicy.resolve(
      ui: ui,
      entryCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountLoaded,
      showPostSaveLoop: _showPostSaveLoop,
      isDegradedVoiceSave: _lastSavedEntryIsDegraded,
      lastSavedEntry: _lastSavedEntry,
      micPhase: effectiveMicPhase,
      micPermissionState: permission,
      userDeniedThisSession: userDenied,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
  }

  String? _recordEntryCtaLabel(RecordCtaPolicyResolution policy) {
    if (AppConfig.enableLiveVoiceCapture &&
        policy.action == RecordCtaAction.startRecording) {
      return LiveVoiceSessionCopy.recordEntryCta;
    }
    return policy.primaryLabel;
  }

  void _maybeLogRecordCtaPolicy(RecordCtaPolicyResolution resolution) {
    if (!kDebugMode) return;
    final secondary = resolution.secondaryLabels.isEmpty
        ? 'none'
        : resolution.secondaryLabels.join(',');
    final action = resolution.action?.logLabel ?? 'none';
    final line =
        'state=${resolution.state.logLabel} '
        'mic=${resolution.micPermissionState.name} '
        'primary=${resolution.primaryLabel ?? 'none'} '
        'action=$action '
        'secondary=$secondary';
    if (_lastCtaPolicyLogLine == line) return;
    _lastCtaPolicyLogLine = line;
    RecordCtaPolicy.log(resolution);
  }

  void _logMicRefreshApply(RecordMicRefreshApplyResult applied) {
    if (applied.initialDeniedCanAskAgain) {
      _recordPermissionUiLog(
        'initial deniedCanAskAgain treated_as=requestable',
      );
    }
    if (applied.userDeniedBlocked) {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    if (applied.permanentDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    }
  }

  Future<void> _refreshMic({bool fromUserRequest = false}) async {
    final resolution = await _recording.evaluateMicrophonePermission();
    final cap = resolution.phase;
    if (!mounted) return;

    if (MicrophonePermissionResolver.isRecordable(resolution.state)) {
      unawaited(_onboardingMicStateStore.write(OnboardingMicState.granted));
      setState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = resolution.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
        if (resolution.state == MicrophonePermissionState.granted) {
          _ignoreStaleMicRefreshAfterGrant = true;
        }
      });
      _recordLog(
        'state ui=$_ui mic=$cap recordable=${resolution.state.name} (refresh)',
      );
      _maybeAutostartWithPrompt();
      return;
    }

    final applied = RecordMicrophonePermissionUi.applyMicRefresh(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
      currentUi: _ui,
      ignoreAfterGrant: _ignoreStaleMicRefreshAfterGrant,
      fromUserRequest: fromUserRequest,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
    if (applied.ignored) {
      _recordPermissionUiLog('stale refresh ignored after granted=true');
      return;
    }
    if (resolution.state == MicrophonePermissionState.deniedOpenSettings) {
      unawaited(
        _onboardingMicStateStore.write(OnboardingMicState.permanentlyDenied),
      );
    } else if (fromUserRequest) {
      unawaited(_onboardingMicStateStore.write(OnboardingMicState.denied));
    }
    _logMicRefreshApply(applied);
    setState(() {
      _mic = applied.mic!;
      _micPermissionState = resolution.state;
      _micPermissionUserDenied = applied.userDenied!;
      _micSessionRequiresOpenSettings = applied.sessionRequiresOpenSettings;
      _ui = applied.ui!;
    });
    _recordLog('state ui=$_ui mic=$cap (refresh)');
    _maybeAutostartWithPrompt();
    if (!V1FeatureFlags.enableV1Only) {
      unawaited(_maybePresentYesterdaysSnapshot());
    }
  }

  Future<void> _maybePresentYesterdaysSnapshot() async {
    if (V1FeatureFlags.enableV1Only) return;
    if (_yesterdaysSnapshotPresentAttempted) return;
    if (!mounted) return;
    if (ScreenshotMode.enabled) return;
    if (_isFlutterWidgetTest) return;
    if (!_journalEntryCountLoaded) return;
    if (_ui != RecordUiState.ready) return;
    if (_mic != RecordingPhase.ready) return;
    if (_isPostSaveSurface) return;

    final hook = await YesterdaysSnapshotCoordinator.resolveReturnDayHook(
      entries: _journalEntries,
    );
    if (!mounted || hook == null) return;

    _yesterdaysSnapshotPresentAttempted = true;
    await YesterdaysSnapshotCoordinator.markPresented(hook);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.push(YesterdaysSnapshotCopy.route, extra: hook));
    });
  }

  void _maybeAutostartWithPrompt() {
    if (_autostartWithPromptAttempted) return;
    if (!widget.autostartWithPrompt) return;
    if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) return;
    if (_ui != RecordUiState.ready || _mic != RecordingPhase.ready) return;
    _autostartWithPromptAttempted = true;
    unawaited(_onRecordPressed(source: 'main'));
  }

  bool _shouldHideCompetingRecordCtas(RecordUiState ui) =>
      RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
        ui: ui,
        micPhase: _mic,
        userDeniedThisSession: _micPermissionUserDenied,
      );

  bool _shouldHideCardRecordButtons(RecordUiState ui) {
    if (_shouldHideCompetingRecordCtas(ui)) return true;
    return RecordCtaPolicy.shouldHideCardRecordCtas(_recordCtaPolicy(ui));
  }

  bool _shouldPromoteMicCaptureActions(RecordCtaPolicyResolution policy) {
    return policy.showMainBottomCta &&
        policy.action != null &&
        policy.action != RecordCtaAction.startRecording;
  }

  Future<void> _dismissReturningWatchTargetPrompt() async {
    if (_pendingWatchForToday != null) {
      await WatchForCoordinator.skipPendingForToday();
      _pendingWatchForToday = null;
      await LowFrictionReturnStore.instance().dismissForDay();
    } else if (ComeBackTomorrowV2Store.hasActive) {
      await ComeBackTomorrowV2Store.instance().recordAnswer(
        answer: ComeBackTomorrowAnswerType.notToday,
      );
    } else {
      await LowFrictionReturnStore.instance().dismissForDay();
    }
    if (!mounted) return;
    setState(() {});
  }

  void _trackRecordCtaPressed() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.recordCtaTapped,
      entryCount: _journalEntryCount,
    );
    InviteFunnelMetrics.recordCtaTapped(entryCount: _journalEntryCount);
    if (_journalEntryCount == 0 && _dueCheckInToday == null) {
      unawaited(ActivationTracker.trackActivationFirstRecordCtaTapped());
    }
    _recordLog('button pressed');
  }

  RecordCtaPolicyResolution _recordCtaPolicyForSession() {
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        return _recordCtaPolicy(
          audit.ui,
          micPhase: audit.micPhase ?? _mic,
          userDeniedThisSession:
              audit.userDeniedThisSession ?? _micPermissionUserDenied,
        );
      }
    }
    return _recordCtaPolicy(_ui);
  }

  Future<void> _onRecordPressed({required String source}) async {
    _recordCtaLog('tapped source=$source');
    final policy = _recordCtaPolicyForSession();
    final action =
        policy.action ??
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
    switch (action) {
      case RecordCtaAction.startRecording:
        _recordCtaLog('start_recording=true');
        _trackRecordCtaPressed();
        setState(() {
          _error = null;
          _localSaveTitle = null;
          _syncNote = null;
          _recordingState.resetTimer();
          _showPostSaveLoop = false;
          _postSaveFollowUp = null;
          EntryAboutnessSession.clearSaveReceipt();
          MemorySurfacingSession.clearSaveReceipts();
          PreserveOriginalSession.clearSaveReceipt();
          ConfirmedRepeatTriggerCapture.clearSaveReceipt();
          ConfirmedRepeatHelpfulActionCapture.clearSaveReceipt();
        });
        await _beginRecording();
      case RecordCtaAction.requestPermission:
        _trackRecordCtaPressed();
        await _requestPermissionAndRecord();
      case RecordCtaAction.openSettings:
        _recordCtaLog('open_settings=true');
        await _openMicSettings();
      case RecordCtaAction.routeToBlockedPanel:
        final stateLabel = RecordMicrophonePermissionUi.micBlockedStateLabel(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
        _recordCtaLog('blocked_by_permission state=$stateLabel');
        if (policy.micPermissionState ==
                MicrophonePermissionState.deniedOpenSettings ||
            _mic == RecordingPhase.permissionPermanentlyDenied ||
            _micSessionRequiresOpenSettings ||
            _micPermissionUserDenied) {
          await _openMicSettings();
        } else {
          await _routeToPermissionPanel();
        }
    }
  }

  Future<void> _routeToPermissionPanel() async {
    if (_ui != RecordUiState.permissionBlocked) {
      _setRecordingState(() {
        _ignoreStaleMicRefreshAfterGrant = false;
        _ui = RecordUiState.permissionBlocked;
        if (_mic == RecordingPhase.permissionPermanentlyDenied) {
          _micPermissionUserDenied = true;
        }
        _error = null;
      });
    }
    _recordCtaLog('routed_to_permission_panel=true');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final panelContext = _permissionPanelKey.currentContext;
      if (panelContext != null) {
        unawaited(Scrollable.ensureVisible(
          panelContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        ));
      }
    });
  }

  Future<void> _requestMic() async {
    _recordLog('button pressed (allow microphone)');
    final existing = await _recording.evaluateMicrophonePermission();
    if (existing.isRecordable) {
      if (!mounted) return;
      _setRecordingState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = existing.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
      });
      _recordPermissionUiLog(
        'recorder_verified=${existing.state.name} start_recording=true',
      );
      await _beginRecording();
      return;
    }
    if (!await _acceptSoftPromptBeforeNativeRequest()) {
      if (mounted && _ui != RecordUiState.permissionBlocked) {
        _setRecordingState(() => _ui = _uiForMicPhase(_mic));
      }
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionRequested();
    }
    _recordPermissionUiLog('request started');
    _setRecordingState(() => _ui = RecordUiState.requestingPermission);
    await _recording.requestMicrophone();
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    if (_ui != RecordUiState.permissionBlocked) {
      _setRecordingState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  Future<void> _requestPermissionAndRecord() async {
    _setRecordingState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _recordingState.resetTimer();
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      EntryAboutnessSession.clearSaveReceipt();
      MemorySurfacingSession.clearSaveReceipts();
      PreserveOriginalSession.clearSaveReceipt();
      _ui = RecordUiState.requestingPermission;
    });
    _recordPermissionUiLog('request started');

    var cap = await _recording.checkMicrophone();
    _recordLog('permission result $cap');
    if (cap != RecordingPhase.ready) {
      final resolution = await _recording.evaluateMicrophonePermission();
      if (resolution.isRecordable) {
        cap = RecordingPhase.ready;
        if (!mounted) return;
        _setRecordingState(() {
          _mic = RecordingPhase.ready;
          _micPermissionState = resolution.state;
          _micPermissionUserDenied = false;
          _micSessionRequiresOpenSettings = false;
          _ui = RecordUiState.ready;
        });
      } else if (!await MicrophonePermissionEnvironment.shouldSkipPermissionRequest(
        status: resolution.permissionHandlerStatus ?? PermissionStatus.denied,
        hasRecorder: resolution.hasRecorder,
      )) {
        if (!await _acceptSoftPromptBeforeNativeRequest()) {
          if (mounted && _ui != RecordUiState.permissionBlocked) {
            _setRecordingState(() => _ui = _uiForMicPhase(_mic));
          }
          return;
        }
        if (TrialMode.enabled) {
          await ActivationTracker.trackTrialMicPermissionRequested();
        }
        await _recording.requestMicrophone();
        _recordLog('permission result after request');
      } else {
        cap = await _recording.checkMicrophone();
        _recordLog('permission result after skip-request $cap');
      }
    }
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordCtaLog('start_recording=true');
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    _recordLog('start failed — permission not granted');
    RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    if (_ui != RecordUiState.permissionBlocked) {
      _setRecordingState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  /// True when the just-saved reflection is weak and the user has not yet
  /// added a sentence or chosen to use it anyway. Gates the pattern/result so
  /// the coach is the first thing shown. One sharpening prompt per reflection.

  bool get _applyEmptyArchiveGates => !ScreenshotMode.enabled;

  bool get _journalEntryCountReady =>
      _journalEntryCountLoaded || ScreenshotMode.enabled;

  void _logRecordEmptyGate([String reason = 'build']) {
    if (kDebugMode) {
      AppLogger.debug(
        'record_empty_gate entryCount=$_journalEntryCount '
        'loaded=$_journalEntryCountLoaded reason=$reason',
      );
    }
  }

  bool get _canShowArchiveProgressCards =>
      RecordEmptyArchiveGates.showArchiveProgressUi(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      ) ||
      !_applyEmptyArchiveGates;

  DailyMirrorResult get _dailyMirror {
    if (!_journalEntryCountReady) return DailyMirrorResult.empty;
    return const DailyMirrorEngine().build(_journalEntries);
  }

  bool get _isPostSaveSurface => _ui == RecordUiState.done || _showPostSaveLoop;

  bool get _showFirstRunPrivacyReassurance {
    if (CreatorDemoMode.isActive) return false;
    if (ScreenshotMode.enabled) {
      return ScreenshotMode.recordCleanFirstRunPreview &&
          _journalEntryCount == 0 &&
          !_isPostSaveSurface;
    }
    return RecordEmptyArchiveGates.showFirstRunPrivacyReassurance(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isPostSave: _isPostSaveSurface,
    );
  }

  bool get _showFirstThreeJourneyOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showFirstThreeJourneyCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showRetentionJourneyCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showRetentionJourneyCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showTwoDayActivationCard =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showTwoDayActivationCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showLegacyEmptyOnboarding =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showLegacyEmptyOnboarding(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showCurrentObjectiveOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showCurrentObjectiveCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _suppressRecordRetentionForEarlyProof {
    if (!_journalEntryCountReady || _isPostSaveSurface) return false;
    if (!RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isPostSave: false,
    )) {
      return false;
    }
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_journalEntries);
  }

  bool get _showBottomRetentionCards =>
      !_suppressRecordRetentionForEarlyProof &&
      (!_applyEmptyArchiveGates ||
          RecordEmptyArchiveGates.showBottomRetentionCards(
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
          ));

  bool get _showAhaMomentCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showAhaMomentCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  RecordStackDecision _recordStackDecision(RecordUiState ui) {
    final hasDueCheck =
        _dueCheckInToday != null &&
        (ui == RecordUiState.ready || ui == RecordUiState.recording);
    final hasSavedReflection =
        ui == RecordUiState.done && _entriesAfterSave.isNotEmpty;
    final hasCompletedResult =
        _completedCheckInToday != null && !_returnDayJustClosed;
    final hasResultNextCheck = hasCompletedResult && !_showInputQualityCoach;
    final hasArchiveProof =
        _patternMemory != null ||
        _patternProgress != null ||
        _patternNextAction != null ||
        _habitProof != null ||
        _weeklyRecap != null ||
        _shareRecap != null;
    final readyNotPostSave =
        ui == RecordUiState.ready || ui == RecordUiState.recording;
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final hasRetentionCard = _shouldShowRetentionOnRecord(
      retentionState,
      readyNotPostSave: readyNotPostSave,
      hasDueCheck: hasDueCheck,
      hasResultNextCheck: hasResultNextCheck,
    );

    final returnDay = const ReturnDayJourneyEngine().evaluate(
      journey: _signalJourney,
      reflectionCount: _journalEntryCount,
      now: DateTime.now(),
      lastReflectionAt: _lastReflectionAt,
    );

    return decideRecordStack(
      hasDueCheck: hasDueCheck,
      isFirstRun: _journalEntryCountReady && _journalEntryCount == 0,
      reflectionCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountReady,
      isTrialMode: TrialMode.enabled,
      isRecording: ui == RecordUiState.recording,
      hasSavedReflection: hasSavedReflection,
      inputQualityNeedsCoach: _showInputQualityCoach,
      hasCompletedResult: hasCompletedResult,
      hasResultNextCheck: hasResultNextCheck,
      hasRoutineAnchorOffer: hasResultNextCheck,
      hasArchiveProof: hasArchiveProof,
      archiveMemoryDemoEligible: !TrialMode.enabled,
      hasRetentionStateCard: hasRetentionCard,
      suppressRetentionForFirstRunDemo:
          retentionState.type == RetentionStateType.noCheckSet,
      suppressRetentionForPostSaveNextCheck:
          retentionState.type == RetentionStateType.loopClosed &&
          hasResultNextCheck,
      showReturnDayJourney:
          returnDay.showCard && readyNotPostSave && !hasDueCheck,
    );
  }

  CurrentObjective _buildCurrentObjective({required bool readyNotPostSave}) {
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildCurrentObjective(
      retentionState: retentionState,
      activeCheckIn: _dueCheckInToday ?? _activeCheckInForTomorrow,
      hasAnyMoment: _journalEntryCount > 0,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasNextCheckChosen: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
    );
  }

  void _onCurrentObjectivePrimary(CurrentObjective objective) {
    switch (objective.type) {
      case CurrentObjectiveType.recordFirstMoment:
      case CurrentObjectiveType.recordAnyMoment:
      case CurrentObjectiveType.answerTodayCheck:
      case CurrentObjectiveType.chooseNextCheck:
        unawaited(_onRecordPressed(source: 'moment'));
      case CurrentObjectiveType.doneForToday:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _currentObjectiveWidget(RecordStackDecision stack) {
    if (ScreenshotMode.enabled) {
      if (ScreenshotMode.objectiveDueCheckPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveDueCheckSample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveFirstMomentPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveFirstMomentSample,
          onPrimaryTap: () => unawaited(_onRecordPressed(source: 'moment')),
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveNextReadyPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveNextReadySample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
    }
    if (!stack.showCurrentObjectiveCard) return null;
    final objective = _buildCurrentObjective(
      readyNotPostSave:
          _ui == RecordUiState.ready || _ui == RecordUiState.recording,
    );
    return CurrentObjectiveCard(
      objective: objective,
      onPrimaryTap: () => _onCurrentObjectivePrimary(objective),
      persistSnapshot: !ScreenshotMode.enabled,
      showRecordCta: !_shouldHideCardRecordButtons(_ui),
    );
  }

  RetentionState _buildRetentionState({required bool readyNotPostSave}) {
    final active = _dueCheckInToday ?? _activeCheckInForTomorrow;
    final missed = _missedCheckInForDiagnosis == null
        ? _recentMissedCheckIn
        : null;
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildRetentionState(
      now: DateTime.now(),
      activeCheckIn: active,
      missedCheckIn: missed,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasChosenNextCheck: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
      compact:
          _retentionNextCheckJustChosen ||
          (_activeCheckInForTomorrow != null && _dueCheckInToday == null),
    );
  }

  bool _shouldShowRetentionOnRecord(
    RetentionState state, {
    required bool readyNotPostSave,
    required bool hasDueCheck,
    required bool hasResultNextCheck,
  }) {
    if (_retentionDismissed &&
        state.type == RetentionStateType.nextCheckChosen) {
      return false;
    }
    if (state.type == RetentionStateType.checkDueToday && hasDueCheck) {
      return false;
    }
    if (state.type == RetentionStateType.checkMissed &&
        _missedCheckInForDiagnosis != null) {
      return false;
    }
    if (state.type == RetentionStateType.loopClosed && hasResultNextCheck) {
      return false;
    }
    if (state.type == RetentionStateType.nextCheckChosen &&
        _retentionNextCheckJustChosen) {
      return true;
    }
    return readyNotPostSave;
  }

  void _onRetentionPrimaryTap(RetentionState state) {
    switch (state.type) {
      case RetentionStateType.noCheckSet:
      case RetentionStateType.checkMissed:
        unawaited(_onRecordPressed(source: 'moment'));
      case RetentionStateType.checkDueToday:
      case RetentionStateType.checkSetForTomorrow:
        break;
      case RetentionStateType.loopClosed:
        break;
      case RetentionStateType.nextCheckChosen:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _retentionCardWidget(RecordStackDecision stack) {
    if (!stack.showRetentionStateCard) return null;
    final state = _buildRetentionState(
      readyNotPostSave:
          _ui == RecordUiState.ready ||
          _ui == RecordUiState.recording ||
          _retentionNextCheckJustChosen,
    );
    final compelling = state.checkQuestion != null
        ? buildCompellingCheck(
            baseQuestion: state.checkQuestion!,
            patternTitle: state.patternTitle,
          )
        : null;
    return RetentionStateCard(
      state: state,
      checkWhyThisCheck: compelling?.whyThisCheck,
      checkExampleAnswer: compelling?.exampleAnswer,
      onPrimaryTap: () => _onRetentionPrimaryTap(state),
      onDismiss: () => setState(() => _retentionDismissed = true),
    );
  }

  Future<void> _saveNextEvidencePrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    final selected = await SelectedSignalCoordinator.loadCurrent();
    final objective = CurrentObjective(
      type: CurrentObjectiveType.recordAnyMoment,
      title: ConsumerUiCopy.postSaveInsightRecordThisNext,
      body: trimmed,
      checkQuestion: trimmed,
      patternTitle: selected?.title,
      primaryCtaLabel: ConsumerUiCopy.postSaveInsightUseThisPrompt,
      route: '/record',
    );
    await CurrentObjectiveSnapshotStore.instance().saveSnapshot(objective);
    if (!mounted) return;
    setState(() => _nextEvidencePrompt = trimmed);
  }

  void _keepRecording({String? nextEvidencePrompt}) {
    setState(() {
      _showPostSaveLoop = false;
      _returnDayJustClosed = false;
      _inputQuality = null;
      _inputQualityText = '';
      _inputQualityResolved = false;
      _languageCode = ScreenshotMode.languageCode;
      _detectedLanguageCode = ScreenshotMode.languageCode;
      _immediateDiscovery = null;
      if (_postSaveFollowUp != null) {
        _selectedPromptLine = _postSaveFollowUp;
      }
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _postSavePattern = null;
      _postSaveCuriosityHook = null;
      _secondSessionComparison = null;
      _patternHypothesis = null;
      _patternHypothesisDismissed = false;
      _firstSessionAlternativeIndex = 0;
      _localSaveTitle = null;
      _syncNote = null;
      _nextEvidencePrompt = nextEvidencePrompt?.trim().isNotEmpty == true
          ? nextEvidencePrompt!.trim()
          : null;
      _ui = _uiForMicPhase(_mic);
    });
  }

  Future<void> _applyAcquisitionIntentPrompt() async {
    if (widget.initialPrompt?.trim().isNotEmpty == true) return;
    if (_journalEntryCount > 0) return;
    final store = AudienceWedgeStore.instance();
    final wedge = await store.load();
    final loop = await LoopModeCoordinator.loadActive();
    final prompt = loop?.activePrompt.isNotEmpty == true
        ? loop!.activePrompt
        : await store.firstRecordingPrompt();
    if (!mounted) return;
    setState(() {
      _audienceWedge = wedge;
      _activeLoop = loop;
      if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) {
        _selectedPromptLine = prompt;
      }
    });
    if (prompt.isNotEmpty) {
      unawaited(FirstInsightSpecificityStore.markFirstPromptUsed());
      if (loop != null) {
        unawaited(LoopModeCoordinator.markFirstPromptUsed());
      }
    }
  }

  Future<void> _onSecondSessionEvidence(String prompt) async {
    _keepRecording(nextEvidencePrompt: prompt);
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null) {
      unawaited(
        NextEvidenceReminderService.schedule(
          journeyId: journey.id,
          prompt: prompt,
        ),
      );
    }
    if (mounted) {
      unawaited(
        maybeOfferReminderPrePrompt(
          context,
          trigger: ReminderPrePromptTrigger.secondRecordingComparison,
        ),
      );
    }
  }

  List<String> _postSaveSignals() {
    if (_entriesAfterSave.isEmpty) return const [];
    return ArchiveBeliefsPresenter.potentialSignalsFromEntry(_lastSavedEntry!);
  }

  bool _postSaveShowsPossiblePattern() {
    if (_immediateDiscovery != null) return true;
    if (_postSaveSignals().isNotEmpty) return true;
    final noticed = _tomorrowReturnLoop?.noticedToday.toLowerCase() ?? '';
    return noticed.contains('pattern') || noticed.contains('forming');
  }

  void _enoughForNow() {
    if (TrialMode.enabled && _watchForAcceptPending) {
      unawaited(
        ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
      );
      _watchForAcceptPending = false;
    }
    setState(() {
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _localSaveTitle = null;
      _syncNote = null;
      _ui = _uiForMicPhase(_mic);
    });
    context.go('/archive-belief');
  }

  void _goToRecordTab() {
    _resetPostSaveToReady();
    context.go('/record');
  }

  void _handleReturningUserTodayAction(ReturningUserTodayAction action) {
    switch (action) {
      case ReturningUserTodayAction.addMoment:
        _goToRecordTab();
      case ReturningUserTodayAction.viewArchive:
        context.go('/archive-belief');
      case ReturningUserTodayAction.viewEvidence:
        unawaited(context.push(BeliefEvidenceNavigation.route));
      case ReturningUserTodayAction.viewReview:
        unawaited(context.push(WeeklyArchiveReviewNavigation.route));
    }
  }

  void _handleNextMomentPromptAction(NextMomentPromptAction action) {
    switch (action) {
      case NextMomentPromptAction.addMoment:
        _goToRecordTab();
      case NextMomentPromptAction.viewEvidence:
        unawaited(context.push(BeliefEvidenceNavigation.route));
      case NextMomentPromptAction.viewReview:
        unawaited(context.push(WeeklyArchiveReviewNavigation.route));
    }
  }

  void _handleDailyArchiveExerciseAction(String route) {
    if (route == DailyArchiveExerciseCopy.recordRoute) {
      unawaited(_onRecordPressed(source: 'daily_archive_exercise'));
      return;
    }
    unawaited(context.push(route));
  }

  void _handleTodaysOneQuestionAction(TodaysQuestionResult question) {
    if (question.primaryRoute == TodaysQuestionCopy.recordRoute) {
      setState(() => _selectedPromptLine = question.questionText);
      unawaited(_onRecordPressed(source: 'todays_one_question'));
      return;
    }
    unawaited(context.push(question.primaryRoute));
  }

  Future<void> _openTodaysOneQuestionScreen() async {
    final action = await context.push<TodaysQuestionScreenAction>(
      TodaysQuestionCopy.route,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TodaysQuestionScreenAction.record:
        unawaited(_onRecordPressed(source: 'todays_one_question'));
      case TodaysQuestionScreenAction.type:
        await navigateToTypeInsteadCapture(
          context,
          prompt: _selectedPromptLine,
          onSaved: _finishSuccessfulCapture,
        );
    }
  }

  bool _compactLayout(RecordUiState ui) =>
      ui == RecordUiState.recording || ui == RecordUiState.processing;
  Future<void> _dismissFirstSessionOnboarding() async {
    await FirstSessionOnboardingStore.instance().markDismissed();
    if (mounted) setState(() {});
  }

  void _resetPostSaveToReady() {
    setState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _showPostSaveLoop = false;
      _immediateDiscovery = null;
      _savedFromConfirmedRepeatTrigger = false;
      _savedFromHelpfulAction = false;
      ConfirmedRepeatTriggerCapture.clearSaveReceipt();
      ConfirmedRepeatHelpfulActionCapture.clearSaveReceipt();
      _ui = _uiForMicPhase(_mic);
    });
  }
}
