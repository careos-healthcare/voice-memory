part of 'recording_screen.dart';

class _RecordScreenState extends ConsumerState<RecordScreen>
    with WidgetsBindingObserver {
  RecordNavigationActivityController get _navigationActivity =>
      widget.navigationActivityController ?? recordNavigationActivityController;

  void _setRecordingState(VoidCallback update) {
    setState(update);
    _syncNavigationActivity();
  }

  void _syncNavigationActivity() {
    _recordView.ui = _ui;
    _recordView.errorMessage = _error;
    final phase = _recordView.viewState.phase;
    final activity = switch (phase) {
      RecordViewPhase.requestingPermission =>
        RecordNavigationActivity.requestingPermission,
      RecordViewPhase.recording => RecordNavigationActivity.recording,
      RecordViewPhase.processing => RecordNavigationActivity.processing,
      _ when _stopAndProcessInFlight => RecordNavigationActivity.processing,
      _ => RecordNavigationActivity.idle,
    };
    _navigationActivity.update(activity);
  }

  RecordUiState _ui = RecordUiState.idle;
  bool _showMicPermissionSimulatorHelper = false;
  bool _ignoreStaleMicRefreshAfterGrant = false;
  final GlobalKey _permissionPanelKey = GlobalKey();
  final RecordingSessionController _recordingState =
      RecordingSessionController();
  final MicrophonePermissionController _micPermission =
      MicrophonePermissionController();
  final CaptureProcessingController _captureProcessing =
      CaptureProcessingController();
  final PostSaveResultController _postSaveResult = PostSaveResultController();
  final RecordingRecoveryController _recoveryController =
      RecordingRecoveryController();

  /// Per-State memo for [RecordSurfaceResolver], read by
  /// `assembleRecordBuildContext` in `recording_build_context_resolver.dart`.
  final RecordSurfaceResolutionNotifier _recordSurfaceResolutionNotifier =
      RecordSurfaceResolutionNotifier();
  late final RecordScreenViewModel _recordView = RecordScreenViewModel(
    session: _recordingState,
    microphone: _micPermission,
    capture: _captureProcessing,
    postSave: _postSaveResult,
    recovery: _recoveryController,
  );
  late final V1AccountDependencies _accountDeps =
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  RecordingPhase get _mic => _micPermission.phase;
  set _mic(RecordingPhase value) => _micPermission.phase = value;

  MicrophonePermissionState get _micPermissionState =>
      _micPermission.permissionState;
  set _micPermissionState(MicrophonePermissionState value) =>
      _micPermission.permissionState = value;

  bool get _micPermissionUserDenied => _micPermission.userDeniedThisSession;
  set _micPermissionUserDenied(bool value) =>
      _micPermission.userDeniedThisSession = value;

  bool get _micSessionRequiresOpenSettings =>
      _micPermission.sessionRequiresOpenSettings;
  set _micSessionRequiresOpenSettings(bool value) =>
      _micPermission.sessionRequiresOpenSettings = value;

  String? get _localSaveTitle => _postSaveResult.localSaveTitle;
  set _localSaveTitle(String? value) => _postSaveResult.localSaveTitle = value;
  String? get _syncNote => _captureProcessing.syncNote;
  set _syncNote(String? value) => _captureProcessing.syncNote = value;
  bool get _showPostSaveLoop => _postSaveResult.showPostSave;
  set _showPostSaveLoop(bool value) => _postSaveResult.showPostSave = value;
  bool get _stopAndProcessInFlight => _captureProcessing.processing;
  set _stopAndProcessInFlight(bool value) =>
      _captureProcessing.processing = value;
  String get _stageLabel => _captureProcessing.stageLabel ?? '';
  set _stageLabel(String value) =>
      _captureProcessing.stageLabel = value.isEmpty ? null : value;

  String? _error;
  int _journalEntryCount = 0;
  bool _journalEntryCountLoaded = false;
  ArchiveReturnChangesResult? _archiveReturnChangesResult;
  ArchiveReturnSnapshot? _archiveReturnCurrentSnapshot;
  List<JournalEntry> _journalEntries = const [];
  bool _hasWatchTheme = false;
  bool _betaFeedbackCaptured = false;
  DateTime? _lastReflectionAt;

  /// Saved entry dates for the 2-day activation path; falls back to
  /// count-only cautious copy when empty or unreliable.
  List<DateTime> _entryDates = const [];
  bool _autostartWithPromptAttempted = false;
  bool _yesterdaysSnapshotPresentAttempted = false;
  String? _selectedPromptLine;
  AudienceWedge? _audienceWedge;
  LoopMode? _activeLoop;
  String? _defaultBoundaryPauseLabel;
  String? _postSaveFollowUp;
  bool _savedFromConfirmedRepeatTrigger = false;
  bool _savedFromHelpfulAction = false;
  bool _earlyEvidenceTriggerCaptured = false;
  bool _earlyEvidenceHelpfulCaptured = false;
  bool _earlyReturnReminderOffer = false;
  bool _earlyReturnReminderHidden = false;
  bool _lastCaptureAnalysisSucceeded = true;
  bool _lastCaptureLowQualityTranscript = false;
  bool _lastCaptureLikelySilentInput = false;
  BetaActivationLoopCounts _betaActivationLoopCounts =
      const BetaActivationLoopCounts();
  List<JournalEntry> _entriesAfterSave = [];
  DailyDiscovery? _immediateDiscovery;
  TomorrowReturnLoop? _tomorrowReturnLoop;
  ReturnComparison? _returnComparison;
  ReturnStreak? _returnStreak;
  TomorrowCheckIn? _dueCheckInToday;
  RoutineAnchor? _dueRoutineAnchor;
  TomorrowCheckIn? _missedCheckInForDiagnosis;
  TomorrowCheckIn? _completedCheckInToday;
  PatternMemory? _patternMemory;
  PatternProgressMoment? _patternProgress;
  PatternNextAction? _patternNextAction;
  HabitProofMoment? _habitProof;
  WeeklyPatternRecap? _weeklyRecap;
  PatternShareRecap? _shareRecap;
  WatchForItem? _pendingWatchForToday;
  WatchForItem? _completedWatchForToday;
  WatchForItem? _suggestedWatchForTomorrow;
  int _watchForAlternativeIndex = 0;
  ActivePatternThread? _activePatternThread;
  bool _isFirstSessionPostSave = false;
  int _firstSessionAlternativeIndex = 0;
  bool _returnDayJustClosed = false;
  FirstThreeJourneyModel? _firstThreeJourney;
  bool _watchForAcceptPending = false;
  HookRescueDecision? _hookRescue;
  String? _hookRescueNotUsefulReason;
  ArchiveFeedbackType? _feedbackHint;
  InputQualityResult? _inputQuality;
  String _inputQualityText = '';
  bool _inputQualityResolved = false;
  bool _firstRecordCardTracked = false;
  TomorrowCheckIn? _activeCheckInForTomorrow;
  TomorrowCheckIn? _recentMissedCheckIn;
  bool _retentionNextCheckJustChosen = false;
  bool _retentionDismissed = false;
  SecondSessionComparison? _secondSessionComparison;
  PatternHypothesis? _patternHypothesis;
  bool _patternHypothesisDismissed = false;
  String? _nextEvidencePrompt;
  FirstSessionPattern? _postSavePattern;
  CuriosityHook? _postSaveCuriosityHook;
  List<PostSaveSignalFeedback> _postSaveInsightFeedback = const [];
  SelectedSignalRecord? _postSaveSelectedSignal;
  SignalArchiveSnapshot? _signalArchiveSnapshot;
  SignalJourney? _signalJourney;
  SignalReview? _signalReview;
  bool _journeyCompletionDismissed = false;
  PendingPurchaseIntent? _purchaseIntentCue;
  String? _invitedWelcomeSource;

  /// First-touch invite attribution source, when one exists — used by the
  /// invited Day 2 return copy. Stable id only, never referrer identity.
  String? _inviteSource;
  bool _hasWeeklyReviewForContinuity = false;
  bool _hasConnectedThreadForContinuity = false;
  AhaMomentCandidate? _ahaCandidate;

  /// Active UI language for post-save cards. Defaults to English; updated from
  /// reflection detection (or the screenshot override) and the language chip.
  String _languageCode = ScreenshotMode.languageCode;

  /// The originally detected language, used by the "Use detected language"
  /// override option.
  String _detectedLanguageCode = ScreenshotMode.languageCode;

  late final RecordingService _recording;
  LiveVoiceCaptureService? _liveVoice;
  late final MicrophonePermissionGateway _microphonePermissionGateway;
  late final OnboardingMicStateStore _onboardingMicStateStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CleanSlatePromptStore.noteSessionStart();
    final s = _accountDeps;
    _microphonePermissionGateway =
        widget.microphonePermissionGateway ??
        PermissionHandlerMicrophoneGateway();
    _onboardingMicStateStore =
        widget.onboardingMicStateStore ?? OnboardingMicStateStore(s.prefs);
    _recording = s.recording;
    if (AppConfig.enableLiveVoiceCapture) {
      _liveVoice = widget.liveVoiceCapture ?? s.liveVoiceCapture;
    }
    unawaited(_refreshMic());
    unawaited(_loadMicPermissionSimulatorHelper());
    unawaited(
      _loadJournalEntryCount().then((_) async {
        if (_journalEntryCount >= 2) {
          unawaited(_loadFirstThreeJourney());
          unawaited(_loadActivePatternThread());
          unawaited(_loadSignalArchive());
        }
        if (_journalEntryCount >= 3) {
          await _loadPersonalReturnPrompts();
        }
      }),
    );
    unawaited(_loadRecordReturnProState());
    unawaited(
      ConfirmedRepeatBetaFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      FirstSessionOnboardingStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      TesterMissionStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaTestScriptStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      CoreValueFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaProofFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaInviteLoopDismissStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ConfirmedRepeatWhyMattersStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ConfirmedRepeatThoughtMapStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      RepeatReturnCheckStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      PatternChangedStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      WhatChangedV2Store.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    if (!V1FeatureFlags.enableV1Only) {
      unawaited(
        CurrentRelevanceStore.ensureLoaded().then((_) async {
          await CorrectionMemoryStore.ensureLoaded();
          if (mounted) setState(() {});
        }),
      );
    }
    unawaited(
      HelpedTrackingStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      EntryImportanceStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      PatternNameStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ReturnDayFlowStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      LowFrictionReturnStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      DelayedPaywallProofStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ReturnAfterProofStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      SecondMomentReturnStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ThreeMomentCompletionStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaActivationPathStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaFeedbackCaptureStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ReturnAfterProofLiftV2Store.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ProVisibilityLiftStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ProUnderstandingLiftStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaRepairLabStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    if (!V1FeatureFlags.enableV1Only) {
      unawaited(
        BetaActivationLoopTracker.readCounts().then((counts) {
          if (mounted) setState(() => _betaActivationLoopCounts = counts);
        }),
      );
    }
    unawaited(
      FirstProofTruthStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(_loadFirstLoop());
    unawaited(_loadDefaultBoundaryPause());
    unawaited(_loadReturnTriggerAccepted());
    unawaited(_loadPurchaseIntentCue());
    unawaited(_loadInvitedWelcome());
    // Persisted memory scope drives the "Memory for this entry" control
    // and every save below; refresh the UI once loaded.
    if (AppServices.isInitialized) {
      unawaited(
        MemoryScopeStore.instance().ensureLoaded().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    // Invited funnel mirror: silent unless a first-touch invite
    // attribution exists. Once per session.
    InviteFunnelMetrics.appOpened();
    final seed = widget.initialPrompt?.trim();
    if (seed != null && seed.isNotEmpty) {
      _selectedPromptLine = seed;
      ConfirmedRepeatTriggerCapture.armIfTriggerPrompt(seed);
      ConfirmedRepeatHelpfulActionCapture.armIfHelpfulPrompt(seed);
    }
    if (ScreenshotMode.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyScreenshotRecordPreview();
      });
    } else {
      unawaited(
        _loadReturnDayState().then((_) async {
          final payload = CheckInReminderService.consumeTapPayload();
          if (payload != null &&
              (payload.startsWith('next_evidence') ||
                  payload.contains('reminder'))) {
            await ReturnReasonCaptureCoordinator.markOpenedFromReminder();
          }
          // The day-2 gentle reminder was tapped to open the app.
          if (payload == DayTwoReminder.reminderId) {
            ActivationFunnelAnalytics.track(
              ActivationFunnelAnalytics.day2ReminderOpened,
              oncePerSession: true,
            );
          }
          await _applyAcquisitionIntentPrompt();
        }),
      );
      if (TrialMode.enabled) {
        unawaited(ActivationTracker.trackTrialAppOpened());
        unawaited(_loadHookRescueDecision());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreMicrophoneAccessOnResume());
    }
  }

  Future<void> _restoreMicrophoneAccessOnResume() async {
    final wasBlocked =
        _micPermissionUserDenied ||
        _micSessionRequiresOpenSettings ||
        _mic == RecordingPhase.permissionDenied ||
        _mic == RecordingPhase.permissionPermanentlyDenied;
    final status = await _microphonePermissionGateway.status;
    if (!mounted) return;
    if (status.isGranted) {
      await _onboardingMicStateStore.write(OnboardingMicState.granted);
      _ignoreStaleMicRefreshAfterGrant = false;
      await _refreshMic();
      if (!mounted || !wasBlocked || _mic != RecordingPhase.ready) return;
      unawaited(HapticFeedback.lightImpact());
      return;
    }
    if (status.isPermanentlyDenied || status.isRestricted || status.isLimited) {
      await _onboardingMicStateStore.write(
        OnboardingMicState.permanentlyDenied,
      );
      await _refreshMic();
    }
  }

  Future<void> _loadHookRescueDecision() async {
    try {
      final summary = await const TrialSummaryEngine().build();
      final decision = const HookRescueDecisionEngine().decide(summary);
      String? topReason;
      final reasons = summary.hookDiagnosis.notUsefulReasonCounts;
      if (reasons.isNotEmpty) {
        topReason = reasons.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
      }
      if (mounted) {
        setState(() {
          _hookRescue = decision;
          _hookRescueNotUsefulReason = topReason;
        });
      }
      // ignore: silent_catch_audit — hook-rescue diagnosis is optional; never block the record loop
    } catch (_, stackTrace) {
      // Diagnosis is optional; never block the record loop.
    }
  }

  Future<void> _usePatternMemoryNext(PatternMemory memory) async {
    final checkIn = await PatternMemoryCoordinator.useNextQuestion(memory);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternMemory = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savedForNextCheckIn),
        ),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _usePatternNextAction(PatternNextAction action) async {
    final checkIn = await PatternMemoryCoordinator.useNextAction(action);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternNextAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savedForTomorrowCheck),
        ),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _keepHabitProofGoing(HabitProofMoment proof) async {
    final checkIn = await PatternMemoryCoordinator.useHabitProofNext(proof);
    if (!mounted) return;
    setState(() => _habitProof = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savedForTomorrowCheck),
        ),
      );
    }
  }

  Future<void> _copyShareRecap(PatternShareRecap recap) async {
    await PatternShareService.copyToClipboard(recap);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).recapCopied)),
    );
  }

  Future<void> _useWeeklyRecapNext(WeeklyPatternRecap recap) async {
    final checkIn = await PatternMemoryCoordinator.useWeeklyRecapNext(recap);
    if (!mounted) return;
    setState(() => _weeklyRecap = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savedForTomorrowCheck),
        ),
      );
    }
  }

  @override
  void dispose() {
    _navigationActivity.release();
    WidgetsBinding.instance.removeObserver(this);
    if (TrialMode.enabled) {
      if (_ui == RecordUiState.recording) {
        unawaited(ActivationTracker.trackTrialRecordingCancelled());
      }
      if (_watchForAcceptPending) {
        unawaited(
          ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
        );
      }
    }
    // Leaving with an answer chosen but no recorded moment is a return-day drop.
    unawaited(
      ReturnDayFrictionCoordinator.trackAbandonedAfterAnswerIfPending(),
    );
    unawaited(_recordingState.dispose());
    super.dispose();
  }

  Future<void> _loadActivePatternThread() async {
    final thread = await ActivePatternThreadCoordinator.loadCurrentThread();
    if (!mounted) return;
    setState(() => _activePatternThread = thread);
  }

  Future<void> _loadSignalArchive() async {
    final snapshot = await SignalArchiveCoordinator.load();
    final journey = await SignalJourneyCoordinator.loadActive();
    SignalReview? review;
    if (journey != null && journey.supportingCount >= 3) {
      review = await SignalReviewCoordinator.loadForActiveJourney();
    }
    if (!mounted) return;
    setState(() {
      _signalArchiveSnapshot = snapshot;
      _signalJourney = journey;
      _signalReview = review;
    });
  }

  void _applyScreenshotRecordPreview() {
    if (ArchiveMeDemoState.isActive) {
      final entries = ArchiveMeDemoArchive.journalEntries();
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = entries.length;
        _journalEntryCountLoaded = true;
        _journalEntries = entries;
        _earlyEvidenceTriggerCaptured = true;
        _earlyEvidenceHelpfulCaptured = true;
        _showPostSaveLoop = false;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.objectiveDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveFirstMomentPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.compellingCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 1;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.realReminderPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionCheckSetPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionDueTodayPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionLoopClosedPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanFirstRunPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordCleanDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _patternProgress = ScreenshotSampleData.patternProgressSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _inputQualityResolved = true;
      });
      return;
    }
    if (ScreenshotMode.positioningRescuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueFirstRecordPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueTomorrowCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueUsefulResultPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueNextCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.quickHelpPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _showPostSaveLoop = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showQuickHelpSheet(
          context,
          languageCode: _languageCode,
          onStartRecording: () => _onRecordPressed(source: 'main'),
          initialIntent: QuickHelpIntent.whatToRecord,
        ));
      });
      return;
    }
    final journeyCount = ScreenshotMode.screenshotJourneyReflectionCount;
    if (journeyCount >= 0) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = journeyCount;
        _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(
          journeyCount,
        );
        _showPostSaveLoop = false;
        _pendingWatchForToday = journeyCount >= 2
            ? ScreenshotSampleData.watchForPendingForToday(DateTime.now())
            : null;
        _activePatternThread = journeyCount >= 1
            ? ScreenshotSampleData.activePatternThreadSample
            : null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.recordFirstSessionPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.completedCheckInPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        if (ScreenshotMode.kindnessPreview) {
          _inputQualityText = ScreenshotSampleData.selfBlameReflection;
        }
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.inputQualityCoachPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _inputQuality = assessReflectionQuality('Today was stressful.');
        _inputQualityText = 'Today was stressful.';
        _inputQualityResolved = false;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = ScreenshotSampleData.returnComparisonSample;
        _returnStreak = ScreenshotSampleData.returnStreakSample;
        _completedWatchForToday = ScreenshotSampleData.watchForCompletedSample;
        _suggestedWatchForTomorrow =
            ScreenshotSampleData.watchForPendingForToday(
              DateTime.now().add(const Duration(days: 1)),
            );
        _pendingWatchForToday = null;
        _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      });
      return;
    }
    if (ScreenshotMode.recordCheckInDuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    setState(() {
      _ui = RecordUiState.ready;
      _mic = RecordingPhase.ready;
      _pendingWatchForToday = ScreenshotSampleData.watchForPendingForToday(
        DateTime.now(),
      );
      _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _showPostSaveLoop = false;
    });
  }

  Future<void> _loadReturnDayState() async {
    final due = await TomorrowCheckInCoordinator.loadDueToday();
    final missed = due == null
        ? await TomorrowCheckInCoordinator.loadMissedNeedingReason()
        : null;
    final recentMissed = due == null && missed == null
        ? await TomorrowCheckInCoordinator.loadRecentMissed()
        : null;
    final active = await TomorrowCheckInCoordinator.loadActive();
    final tomorrowKey = _tomorrowDateKey;
    TomorrowCheckIn? activeForTomorrow;
    if (active != null &&
        !active.isCompleted &&
        active.targetDate == tomorrowKey) {
      activeForTomorrow = active;
    }
    WatchForItem? pending;
    if (due == null) {
      pending = await WatchForCoordinator.loadPendingForToday();
    }
    if (due != null || pending != null) {
      await ActivationTracker.trackReturnedNextDayOnce();
    }
    RoutineAnchor? dueAnchor;
    if (due != null) {
      // Seeing yesterday's question is the first return-day step.
      await ReturnDayFrictionCoordinator.markDueShown(due.id);
      dueAnchor = await RoutineAnchorStore.instance().loadForDate(
        due.targetDate,
      );
    }
    ArchiveFeedbackType? feedbackHint;
    try {
      feedbackHint = await ArchiveFeedbackCoordinator.latestDominantIssue();
      // ignore: silent_catch_audit — archive feedback hint is optional; never block the record loop
    } catch (_, stackTrace) {
      // Feedback is optional; never block the record loop.
    }
    if (!mounted) return;
    setState(() {
      _dueCheckInToday = due;
      _dueRoutineAnchor = dueAnchor;
      _missedCheckInForDiagnosis = missed;
      _recentMissedCheckIn = recentMissed;
      _activeCheckInForTomorrow = activeForTomorrow;
      _pendingWatchForToday = pending;
      _feedbackHint = feedbackHint;
    });
  }

  /// ISO date key for tomorrow, matching how check-ins set their targetDate.
  String get _tomorrowDateKey =>
      tomorrowCheckInDateKey(DateTime.now().add(const Duration(days: 1)));

  /// Shows the routine-anchor chooser and stores the chosen moment for the
  /// given target date so the due card can show "Planned for: …".
  Future<void> _promptRoutineAnchorForDate(String targetDate) async {
    if (!mounted) return;
    final anchor = await RoutineAnchorChooser.show(context);
    if (anchor == null) return;
    await RoutineAnchorStore.instance().saveForDate(targetDate, anchor);
  }

  bool get _isFlutterWidgetTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _loadJournalEntryCount() async {
    if (_isFlutterWidgetTest) {
      // Widget tests do not run initState file I/O unless wrapped in runAsync.
      // Use the journal cache so empty-gate UI can render deterministically.
      _applyLoadedJournalEntryCount(
        _accountDeps.journalStore.loadAllSync(),
        hasWatchTheme: false,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
      );
      return;
    }

    final all = await _accountDeps.journal.loadAll();
    await BetaFeedbackStore.ensureLoaded();
    final watchItems = await ArchiveWatchlistStore(
      _accountDeps.prefs,
    ).loadItems();
    if (!mounted) return;
    _applyLoadedJournalEntryCount(
      all,
      hasWatchTheme: watchItems.isNotEmpty,
      betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
    );
    unawaited(_loadEarlyEvidenceMilestones());
  }

  Future<void> _loadEarlyEvidenceMilestones() async {
    final trigger = await EarlyEvidenceMilestoneStore.instance()
        .readTriggerCaptured();
    final helpful = await EarlyEvidenceMilestoneStore.instance()
        .readHelpfulActionCaptured();
    final earlyReturnReminderOffer = V1CapabilityRegistry.notifications
        ? await EarlyArchiveReturnReminderStore.instance().shouldOffer()
        : false;
    if (!mounted) return;
    setState(() {
      _earlyEvidenceTriggerCaptured = trigger;
      _earlyEvidenceHelpfulCaptured = helpful;
      _earlyReturnReminderOffer = earlyReturnReminderOffer;
    });
  }

  void _applyLoadedJournalEntryCount(
    List<JournalEntry> all, {
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
  }) {
    if (!mounted) return;
    setState(() {
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _hasWatchTheme = hasWatchTheme;
      _betaFeedbackCaptured = betaFeedbackCaptured;
      _lastReflectionAt = all.isEmpty ? null : all.last.createdAt;
      _entryDates = all.map((e) => e.createdAt).toList();
      if (ArchiveMeDemoState.isActive) {
        _earlyEvidenceTriggerCaptured = true;
        _earlyEvidenceHelpfulCaptured = true;
      }
    });
    unawaited(_refreshArchiveReturnChanges(all));
    _logRecordEmptyGate('journal_loaded');
    if (!V1FeatureFlags.enableV1Only) {
      unawaited(BetaActivationLoopTracker.trackRecordScreenSeen());
      unawaited(_maybePresentYesterdaysSnapshot());
    }
  }

  Future<void> _refreshArchiveReturnChanges(List<JournalEntry> entries) async {
    final store = ArchiveReturnChangesStore.fromAppPrefs(_accountDeps.prefs);
    final resolved = await resolveArchiveReturnChanges(
      entries: entries,
      store: store,
    );
    if (!mounted) return;
    setState(() {
      _archiveReturnCurrentSnapshot = resolved.current;
      _archiveReturnChangesResult = resolved.result;
    });
  }

  Future<void> _markArchiveReturnChangesSeen() async {
    final snapshot = _archiveReturnCurrentSnapshot;
    if (snapshot == null) return;
    await ArchiveReturnChangesStore.fromAppPrefs(
      _accountDeps.prefs,
    ).markSeen(snapshot);
    if (!mounted) return;
    setState(() => _archiveReturnChangesResult = null);
  }

  bool _returnTriggerAccepted = false;
  PersonalReturnPromptSet? _personalReturnPrompts;
  DailyReturnSuggestionSet _dailyReturnSuggestions =
      DailyReturnSuggestionSet.empty;
  OneSmallRecording _oneSmallRecording = OneSmallRecording.none();

  /// Suggestion-to-Pro funnel state. The pending source is set on tap and
  /// consumed on the next successful save — never blocks recording.
  PaywallSource? _pendingSuggestionSource;
  DailyReturnSuggestion? _pendingTappedSuggestion;
  bool _dailySuggestionsSeenTracked = false;
  PaywallSource? _suggestionProNudgeSource;

  /// Post-save "Saved to your archive" receipt for suggestion-sourced saves.
  StartHereSaveReceipt? _saveReceipt;

  /// Post-save "Done for today" closure receipt — every successful save.
  DoneForTodayReceipt? _doneForTodayReceipt;
  DayTwoReturnPreview? _dayTwoReturnPreview;

  /// One optional day-2 reminder offer — only after the very first save.
  bool _offerDayTwoReminder = false;

  /// Post-save archive proof counter — real evidence counts, never fabricated.
  ArchiveProofCounter? _archiveProofCounter;

  /// Post-save optional context tag prompt — only after a successful save.
  bool _showEvidenceContextTag = false;

  /// Post-save anonymous share card — counts only, never user text.
  ShareableArchiveProof? _shareableProof;

  /// Post-save Pro bridge — only after a real value moment, never blocking.
  ValueMomentBridge? _valueMomentBridge;

  /// Record → Return → Pro loop: true only while the very first save's
  /// post-save view is showing.
  bool _recordReturnProJustSaved = false;

  /// Loop persisted progress (return cue, Pro bridge, change-start seen).
  RecordReturnProState? _recordReturnProState;

  /// Pro users never see the commercial-loop Pro bridge.
  bool _recordReturnProIsPro = false;

  /// The post-save Pro nudge shows at most once per app session.
  static bool _suggestionProNudgeShownThisSession = false;

  SuggestionAttributionStore? get _suggestionAttribution =>
      widget.suggestionAttributionStore ??
      (AppServices.isInitialized
          ? SuggestionAttributionStore.instance()
          : null);

  void _onDailySuggestionTapped(
    DailyReturnSuggestion suggestion,
    bool isPrimary,
  ) {
    final source = isPrimary
        ? PaywallSource.startHereToday
        : PaywallSource.dailySuggestion;
    _pendingSuggestionSource = source;
    _pendingTappedSuggestion = suggestion;
    final store = _suggestionAttribution;
    if (store == null) return;
    unawaited(
      store.record(
        SuggestionAttributionEventType.tappedFor(source),
        suggestionId: suggestion.id,
      ),
    );
  }

  /// Records the saved-from-suggestion event and shows the "Saved to your
  /// archive" receipt for suggestion-sourced saves. Runs only after the save
  /// fully succeeded — generic prompt saves never reach the receipt.
  Future<void> _handleSuggestionAttributionAfterSave(int entryCount) async {
    final source = _pendingSuggestionSource;
    final tapped = _pendingTappedSuggestion;
    if (source == null) return;
    _pendingSuggestionSource = null;
    _pendingTappedSuggestion = null;

    final store = _suggestionAttribution;
    if (store != null) {
      unawaited(store.record(SuggestionAttributionEventType.savedFor(source)));
    }

    final receipt = const StartHereSaveReceiptEngine().build(
      source: source,
      suggestion: tapped,
    );
    if (receipt != null) {
      if (!mounted) return;
      setState(() => _saveReceipt = receipt);
      return;
    }

    // Fallback when no tapped suggestion was retained: the gentle Pro nudge.
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!SuggestionProTrigger.shouldShow(
      isPro: isPro,
      entryCount: entryCount,
      alreadyShownThisSession: _suggestionProNudgeShownThisSession,
    )) {
      return;
    }
    _suggestionProNudgeShownThisSession = true;
    if (!mounted) return;
    setState(() => _suggestionProNudgeSource = source);
  }

  Future<void> _loadReturnTriggerAccepted() async {
    if (!AppServices.isInitialized) return;
    final accepted = await PressureReturnTriggerStore.instance().accepted;
    if (!mounted) return;
    setState(() => _returnTriggerAccepted = accepted);
  }

  /// Builds "Try saying one of these" and "Worth checking today" from the
  /// user's own pressure entries when there is evidence; otherwise the
  /// section keeps generic prompts and no suggestion card is shown.
  Future<void> _loadPersonalReturnPrompts() async {
    if (!_journalEntryCountReady || _journalEntryCount < 3) return;
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final records = await store.loadAll();
    final savedEntryCount = _journalEntryCount;
    if (!mounted) return;
    setState(() {
      _personalReturnPrompts = const PersonalReturnPromptEngine().build(
        records,
      );
      _dailyReturnSuggestions = const DailyReturnSuggestionEngine().build(
        records,
      );
      _oneSmallRecording = const OneSmallRecordingEngine().build(
        records,
        entryCount: savedEntryCount,
      );
      // Day 7 continuity inputs — both from existing engines, never new
      // claims. The loop itself is built at render time with the current
      // entry count.
      _hasWeeklyReviewForContinuity = const WeeklyThreadReviewEngine()
          .build(records)
          .hasReview;
      _hasConnectedThreadForContinuity = const ThreadReturnEvidenceEngine()
          .build(records)
          .hasEvidence;
    });
    await AhaMomentStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _ahaCandidate = const AhaMomentEngine().evaluate(
        records: records,
        entryCount: savedEntryCount,
        hasStrongerMemoryCardVisible: false,
        source: 'record',
        trackAnalytics: false,
      );
    });
    if (_dailyReturnSuggestions.hasSuggestions &&
        !_dailySuggestionsSeenTracked) {
      _dailySuggestionsSeenTracked = true;
      final store = _suggestionAttribution;
      if (store != null) {
        unawaited(
          store.record(SuggestionAttributionEventType.dailySuggestionsSeen),
        );
      }
    }
  }

  /// Return cue is on screen — first save only, until answered once.
  bool get _recordReturnCueVisible =>
      _recordReturnProJustSaved &&
      _recordReturnProState != null &&
      !_recordReturnProState!.returnCueResolved;

  Future<void> _loadRecordReturnProState() async {
    if (!AppServices.isInitialized) return;
    await ProEvidenceValueDismissStore.ensureLoaded();
    await ProLockMomentDismissStore.ensureLoaded();
    await MonthlyPrivateReportDismissStore.ensureLoaded();
    await BetaFeedbackIntelligenceStore.ensureLoaded();
    final state = await RecordReturnProStore.instance().load();
    final isPro =
        await (widget.entitlementReader ??
                ArchiveEntitlementReader.forAccessCheck())
            .isPro;
    if (!mounted) return;
    setState(() {
      _recordReturnProState = state;
      _recordReturnProIsPro = isPro;
    });
  }

  bool get _hasRealChangeInsight => RecordReturnProGates.hasRealChangeInsight(
    hasReturnComparison: _returnComparison != null,
    hasTomorrowReturnLoopContent: _tomorrowReturnLoop?.hasContent ?? false,
    hasThreadReturnEvidence: _hasConnectedThreadForContinuity,
  );

  Future<void> _markChangeStartSeen() async {
    await RecordReturnProStore.instance().markChangeStartSeen();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        changeStartSeen: true,
      );
    });
  }

  void _handleThoughtMapMissingPiece(ThoughtMapResult map) {
    final missing = map.sections.where((section) => !section.isKnown);
    if (missing.isEmpty) return;
    final section = missing.first;
    ConfirmedRepeatThoughtMapAnalytics.recordMissingPieceTapped(
      section: section.id,
      surface: 'record',
      entryCount: _journalEntryCount,
    );
    unawaited(
      ConfirmedRepeatThoughtMapStore.instance().markMissingPieceTarget(
        section.id,
      ),
    );
    if (section.id == ThoughtMapSectionId.trigger) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (section.id == ThoughtMapSectionId.result) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = section.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'thought_map'));
  }

  void _handlePositiveReinforcementRecordAgain(
    PositiveReinforcementResult reinforcement,
  ) {
    PositiveReinforcementAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      helpfulPatternRecorded: true,
    );
    ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    setState(() => _selectedPromptLine = reinforcement.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'positive_reinforcement'));
  }

  void _handlePatternChangedRecord(PatternChangedResult result) {
    PatternChangedAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      changeType: result.type,
    );
    unawaited(_onRecordPressed(source: 'pattern_changed'));
  }

  void _handleArchiveSummaryRecordNext(ArchiveSummaryResult summary) {
    final recordNext = summary.recordNext;
    if (recordNext.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (recordNext.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = recordNext.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'archive_summary'));
  }

  void _handleDailyReturnReason(DailyReturnReasonResult reason) {
    DailyReturnReasonAnalytics.recordTapped(
      kind: reason.kind,
      surface: 'record',
      entryCount: _journalEntryCount,
    );
    if (reason.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (reason.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = reason.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'daily_return_reason'));
  }

  Future<void> _handleFirstProofWatchThisNext() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) {
      _resetPostSaveToReady();
      return;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final phrase = ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible);
    final watch = WatchForCoordinator.buildSuggestedWatchForAfterSave(
      entries: entries,
      loop: _tomorrowReturnLoop,
      signals: phrase != null ? [phrase] : _postSaveSignals(),
    );
    await WatchForCoordinator.acceptSuggestedWatchFor(watch);
    if (!mounted) return;
    if (phrase != null && phrase.trim().isNotEmpty) {
      setState(() => _selectedPromptLine = 'Watch for: $phrase');
    }
    _resetPostSaveToReady();
  }

  void _openPatternDetailFromRecord() {
    final earlyFirstSignal = EarlyFirstSignalEngine.build(
      entries: _journalEntries,
    );
    final earlyEvidenceTimeline = EarlyEvidenceTimelineEngine.build(
      entries: _journalEntries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeat =
        earlyEvidenceTimeline != null ||
        (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final repeatReturnChangeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: _journalEntryCount,
      viewingConfirmedRepeat: viewingConfirmedRepeat,
      isRecording: false,
      isPostSave: false,
      records: RepeatReturnCheckStore.cached,
    );
    final detail = PatternDetailEngine.build(
      entries: _journalEntries,
      confirmedRepeat: earlyFirstSignal,
      changeProof: repeatReturnChangeProof,
      returnChecks: RepeatReturnCheckStore.cached,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    if (detail == null) return;

    final shareCard = ShareCardBuilder.build(
      entries: _journalEntries,
      detail: detail,
      confirmedRepeat: earlyFirstSignal,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    unawaited(
      PatternDetailSheet.show(
        context,
        detail: detail,
        buildInput: PatternDetailBuildInput(
          entries: _journalEntries,
          confirmedRepeat: earlyFirstSignal,
          changeProof: repeatReturnChangeProof,
          returnChecks: RepeatReturnCheckStore.cached,
          triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
        ),
        entryCount: _journalEntryCount,
        isPro: _recordReturnProIsPro,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                '/subscription',
                extra: PaywallRouteArgs(
                  source: PaywallSource.valueMoment,
                  sourceRoute: '/record',
                ),
              ),
        shareCard: shareCard,
      ),
    );
  }

  void _openFirstProofPatternDetail() {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: entries);
    final earlyEvidenceTimeline = EarlyEvidenceTimelineEngine.build(
      entries: entries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeat =
        earlyEvidenceTimeline != null ||
        (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final repeatReturnChangeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeat,
      isRecording: false,
      isPostSave: true,
      records: RepeatReturnCheckStore.cached,
    );
    final detail = PatternDetailEngine.build(
      entries: entries,
      confirmedRepeat: earlyFirstSignal,
      changeProof: repeatReturnChangeProof,
      returnChecks: RepeatReturnCheckStore.cached,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    if (detail == null) return;

    final shareCard = ShareCardBuilder.build(
      entries: entries,
      detail: detail,
      confirmedRepeat: earlyFirstSignal,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    unawaited(
      PatternDetailSheet.show(
        context,
        detail: detail,
        buildInput: PatternDetailBuildInput(
          entries: entries,
          confirmedRepeat: earlyFirstSignal,
          changeProof: repeatReturnChangeProof,
          returnChecks: RepeatReturnCheckStore.cached,
          triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
        ),
        entryCount: entries.length,
        isPro: _recordReturnProIsPro,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                '/subscription',
                extra: PaywallRouteArgs(
                  source: PaywallSource.valueMoment,
                  sourceRoute: '/record',
                ),
              ),
        shareCard: shareCard,
      ),
    );
  }

  Future<void> _openFirstProofRenamePattern() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final prompt = PatternNameEngine.buildPrompt(entries: entries);
    final payoff = FirstProofPayoffEngine.build(entries: entries);
    final groundedPhrase =
        prompt?.groundedPhrase ?? payoff?.groundedPhrase ?? '';
    if (groundedPhrase.trim().isEmpty) return;

    final patternKey = PatternNameEngine.patternKey(groundedPhrase);
    final initialName = PatternNameEngine.displayLabelForGroundedPhrase(
      groundedPhrase,
    );
    final saved = await RenamePatternSheet.show(
      context,
      initialName: initialName,
      onSave: (name) async {
        await PatternNameStore.setCustomName(patternKey, name);
        PatternNameAnalytics.renamed(
          source: 'first_proof_action_loop',
          entryCount: entries.length,
          hasCustomName: true,
        );
      },
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _excludeLatestFromFirstProofPattern() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
      entries,
    );
    final entryId = entries.last.id;
    if (patternKey == null || entryId.isEmpty) return;

    await ArchivePatternExclusionActions.excludeFromPattern(
      context: context,
      entryId: entryId,
      patternKey: patternKey,
      source: 'first_proof_action_loop',
    );
  }

  Future<void> _openFirstProofPatternCorrection() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final payoff = FirstProofPayoffEngine.build(entries: entries);
    if (payoff == null) return;
    if (!PatternCorrectionGates.shouldShowForFirstProofNo(
      entries: entries,
      payoff: payoff,
    )) {
      return;
    }

    await PatternCorrectionSheet.show(
      context,
      contextData: PatternCorrectionGates.buildForFirstProofNo(
        entries: entries,
        payoff: payoff,
        onKeepRecording: _keepRecording,
      ),
    );
  }

  void _openWeeklyArchiveReview(WeeklyArchiveReviewResult review) {
    WeeklyArchiveWeekReviewAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      hasRepeat: review.whatRepeated?.isSupported ?? false,
      hasChange: review.whatChanged?.isSupported ?? false,
      hasPositivePattern: review.whatHelped?.isSupported ?? false,
    );
    unawaited(
      WeeklyArchiveReviewSheet.show(
        context,
        review: review,
        isPro: _recordReturnProIsPro,
        entryCount: _journalEntryCount,
        entries: _journalEntries,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                '/subscription',
                extra: PaywallRouteArgs(
                  source: PaywallSource.valueMoment,
                  sourceRoute: '/record',
                ),
              ),
      ),
    );
  }

  /// Resolves the commercial-loop Pro bridge once.
  Future<void> _resolveRecordReturnProBridge({required bool seePro}) async {
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        proBridgeResolved: true,
      );
    });
    if (seePro) {
      await context.push(
        '/subscription',
        extra: PaywallRouteArgs(
          source: PaywallSource.valueMoment,
          sourceRoute: '/record',
        ),
      );
    }
  }

  Future<void> _dismissProEvidenceValueBridge() async {
    await ProEvidenceValueEngine.dismissForSession();
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (mounted) setState(() {});
  }

  Future<void> _dismissBetaInviteLoop() async {
    await BetaInviteLoopEngine.dismissForSession();
    if (mounted) setState(() {});
  }

  void _openProEvidenceValueSubscription({required String analyticsSource}) {
    EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
      source: analyticsSource,
    );
    unawaited(context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        source: PaywallSource.valueMoment,
        sourceRoute: '/record',
      ),
    ));
  }

  void _handleBetaActivationPathPrimaryCta(BetaActivationPathResult result) {
    switch (result.primaryActionType) {
      case BetaActivationPathActionType.saveFirstMoment:
      case BetaActivationPathActionType.saveAnotherMoment:
      case BetaActivationPathActionType.saveOneMoreMoment:
        unawaited(
          navigateToTypeInsteadCapture(
            context,
            prompt: _selectedPromptLine,
            onSaved: _finishSuccessfulCapture,
          ),
        );
      case BetaActivationPathActionType.viewTimelineProof:
        context.go('/archive-belief');
      case BetaActivationPathActionType.seeWhatProKeeps:
      case BetaActivationPathActionType.reviewProValue:
        _openProEvidenceValueSubscription(
          analyticsSource: 'record_beta_activation_path',
        );
      case BetaActivationPathActionType.notNow:
      case BetaActivationPathActionType.notToday:
        break;
    }
  }

  /// Builds the "Done for today" closure receipt — only ever called after a
  /// save succeeded, so a failed save can never surface it.
  Future<void> _buildDoneForTodayReceipt() async {
    List<PressureCheckInRecord> records = const [];
    if (widget.pressureCheckInStore != null || AppServices.isInitialized) {
      final store =
          widget.pressureCheckInStore ?? PressureCheckInStore.instance();
      records = await store.loadAll();
    }
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    // Day 2 gentle reminder: offered once, only right after the very first
    // successful save — value exists before anything is asked.
    final offerDayTwoReminder = await DayTwoReminderCoordinator().shouldOffer(
      entryCount: _journalEntryCount,
    );
    // First 60 Seconds: load the persisted return-cue / Pro-bridge answers
    // so neither card ever re-asks after being resolved.
    final recordReturnProState = await RecordReturnProStore.instance().load();
    if (!mounted) return;
    setState(() {
      _offerDayTwoReminder = offerDayTwoReminder;
      _recordReturnProState = recordReturnProState;
      _recordReturnProIsPro = isPro;
      _doneForTodayReceipt = const DoneForTodayReceiptEngine().build(
        saved: true,
        entryCount: _journalEntryCount,
        records: records,
      );
      // Same evidence, one more honest count: the save that just happened.
      _archiveProofCounter = const ArchiveProofCounterEngine().build(
        records,
        savedToday: true,
      );
      // Anonymous share card built from the same counts — never user text.
      _shareableProof = const ShareableArchiveProofEngine().build(
        records,
        savedToday: true,
        entryCount: _journalEntryCount,
      );
      // Pro bridge only after a real value moment — and the save is already
      // done, so it can never block recording or saving.
      _valueMomentBridge = const ValueMomentPaywallTrigger().build(
        records,
        isPro: isPro,
      );
      // Optional, skippable context tag — only reachable after a real save.
      _showEvidenceContextTag = _entriesAfterSave.isNotEmpty;
      // Tomorrow's-check preview — safe labels only, never user text.
      _dayTwoReturnPreview = const DayTwoReturnPreviewEngine().build(
        entryCount: _journalEntryCount,
        contextTagIds: [for (final r in records) ...r.contextIds],
        entryDates: [for (final r in records) r.createdAt],
      );
    });
  }

  /// Persists a one-tap low-effort check-in as a real lightweight evidence
  /// record. The card only confirms "Saved" after this completes.
  Future<void> _saveLowEffortCheckIn(LowEffortCheckInOption option) async {
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final existing = await store.loadAll();
    await store.save(
      const LowEffortCheckInEngine().buildRecord(option, existing),
    );
  }

  Future<void> _saveEvidenceContextTag(String tagId) async {
    setState(() => _showEvidenceContextTag = false);
    final entry = _lastSavedEntry;
    if (entry == null) return;
    if (!AppServices.isInitialized) return;
    final tagged = CaptureContextTags.applyTag(entry, tagId);
    await _accountDeps.journalStore.save(
      tagged,
      first25Source: 'capture_context_tag',
    );
    if (!mounted) return;
    setState(() {
      if (_entriesAfterSave.isNotEmpty &&
          _entriesAfterSave.first.id == tagged.id) {
        _entriesAfterSave = [tagged, ..._entriesAfterSave.skip(1)];
      }
    });
  }

  Future<void> _saveCuriosityHookResponse({
    required CuriosityHook hook,
    required String responseText,
    required bool wasGrounded,
  }) async {
    final trimmed = responseText.trim();
    if (trimmed.isEmpty || !AppServices.isInitialized) return;

    final entry = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: (trimmed.length / 15).ceil().clamp(1, 120),
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: trimmed,
        concreteObservation: trimmed,
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
      parentHookId: hook.id,
      wasGrounded: wasGrounded,
    );

    await _accountDeps.journalStore.save(
      entry,
      first25Source: 'curiosity_hook_response',
    );
    unawaited(CuriosityHookCoordinator.instance().markConsumed(hook.id));

    if (!mounted) return;
    setState(() {
      _postSaveCuriosityHook = null;
      _entriesAfterSave = [entry, ..._entriesAfterSave];
      _journalEntryCount += 1;
    });
  }

  Future<void> _loadFirstThreeJourney() async {
    if (!_journalEntryCountReady || _journalEntryCount < 2) return;
    final model = await FirstThreeJourneyCoordinator.load();
    if (!mounted) return;
    setState(() => _firstThreeJourney = model);
  }

  /// Purchase Intent Return Cue: a previous purchase start without a
  /// completion, surfaced calmly on a later visit. Loaded once at init —
  /// the session that started the purchase never shows it.
  Future<void> _loadPurchaseIntentCue() async {
    if (widget.purchaseIntentStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.purchaseIntentStore ?? PurchaseIntentStore();
    final intent = await store.pendingIntent();
    if (intent == null) return;
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!mounted) return;
    if (!PurchaseIntentReturnCue.shouldShow(
      isPro: isPro,
      hasPendingIntent: true,
    )) {
      return;
    }
    PurchaseIntentReturnCue.shownThisSession = true;
    setState(() => _purchaseIntentCue = intent);
  }

  /// Invited User Welcome: a locally persisted first-touch invite
  /// attribution tailors the pre-first-save welcome. Loaded once at init;
  /// the render gate also requires a still-empty archive.
  Future<void> _loadInvitedWelcome() async {
    if (widget.inviteAttributionStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.inviteAttributionStore ?? InviteAttributionStore();
    final attribution = await store.firstTouch();
    if (attribution == null || !mounted) return;
    // Any invited surface (welcome, Day 2 return copy) can use the source.
    setState(() => _inviteSource = attribution.source);
    if (!InvitedUserWelcome.shouldShow(entryCount: _journalEntryCount)) return;
    InvitedUserWelcome.shownThisSession = true;
    InvitedUserWelcome.sessionSource = attribution.source;
    setState(() => _invitedWelcomeSource = attribution.source);
  }

  Future<void> _loadFirstLoop() async {
    // Opening the Record tab is the first step of the compressed loop.
    if (ScreenshotMode.enabled) {
      await FirstLoopActivationCoordinator.load();
    } else {
      await FirstLoopActivationCoordinator.markOpenedRecord();
    }
  }

  Future<void> _loadDefaultBoundaryPause() async {
    if (ScreenshotMode.enabled || !AppServices.isInitialized) return;
    await CapacityBoundaryResponseStore.ensureLoaded();
    final loop = _activeLoop ?? await LoopModeCoordinator.loadActive();
    final selection = CapacityBoundaryResponseStore.cached;
    final text = selection != null && selection.hasSelection
        ? CapacityBoundaryResponseCopy.textForId(selection.responseId)
        : null;
    if (!mounted) return;
    setState(() {
      _defaultBoundaryPauseLabel =
          text != null && (loop?.isCapacityYes ?? false)
          ? CapacityBoundaryResponseCopy.recordDefaultPauseLabel(text)
          : null;
    });
  }

  String? _lastCtaPolicyLogLine;

  @override
  Widget build(BuildContext context) {
    attachRecordingServiceListener(ref);
    final ctx = assembleRecordBuildContext(context);
    return _buildRecordScreenScaffold(context, ctx);
  }
}