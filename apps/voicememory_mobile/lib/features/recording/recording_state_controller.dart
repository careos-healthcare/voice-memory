part of '../../screens/record_screen.dart';

/// Owns recording-duration state and its stream lifecycle independently from
/// the screen's presentation state.
class RecordingStateController {
  int _seconds = 0;
  StreamSubscription<int>? _durationSubscription;

  int get seconds => _seconds;

  void bindDuration(Stream<int> duration, {required ValueChanged<int> onTick}) {
    unawaited(_durationSubscription?.cancel());
    _durationSubscription = duration.listen((value) {
      _seconds = value;
      onTick(value);
    });
  }

  void resetTimer() {
    _seconds = 0;
  }

  Future<void> dispose() async {
    await _durationSubscription?.cancel();
    _durationSubscription = null;
  }
}

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  RecordNavigationActivityController get _navigationActivity =>
      widget.navigationActivityController ?? recordNavigationActivityController;

  void _setRecordingState(VoidCallback update) {
    setState(update);
    _syncNavigationActivity();
  }

  void _syncNavigationActivity() {
    final activity = switch (_ui) {
      RecordUiState.requestingPermission =>
        RecordNavigationActivity.requestingPermission,
      RecordUiState.recording => RecordNavigationActivity.recording,
      RecordUiState.processing => RecordNavigationActivity.processing,
      _ when _stopAndProcessInFlight => RecordNavigationActivity.processing,
      _ => RecordNavigationActivity.idle,
    };
    _navigationActivity.update(activity);
  }

  RecordUiState _ui = RecordUiState.idle;
  RecordingPhase _mic = RecordingPhase.idle;
  MicrophonePermissionState _micPermissionState =
      MicrophonePermissionState.unknown;
  bool _micPermissionUserDenied = false;
  bool _micSessionRequiresOpenSettings = false;
  bool _showMicPermissionSimulatorHelper = false;
  bool _ignoreStaleMicRefreshAfterGrant = false;
  final GlobalKey _permissionPanelKey = GlobalKey();
  final RecordingStateController _recordingState = RecordingStateController();
  int get _seconds => _recordingState.seconds;
  String? _error;
  String? _localSaveTitle;
  String? _syncNote;
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
  String _stageLabel = '';
  String? _selectedPromptLine;
  AudienceWedge? _audienceWedge;
  LoopMode? _activeLoop;
  String? _defaultBoundaryPauseLabel;
  String? _postSaveFollowUp;
  bool _showPostSaveLoop = false;
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
  PostSaveComparisonController? _postSaveComparisonController;
  final _logger = const _RecordScreenLogger();
  late final RevenueCatPaywallPresenter _paywallPresenter;
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
  bool _stopAndProcessInFlight = false;
  LiveVoiceCaptureService? _liveVoice;
  late final MicrophonePermissionGateway _microphonePermissionGateway;
  late final OnboardingMicStateStore _onboardingMicStateStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paywallPresenter =
        widget.paywallPresenter ?? const RevenueCatPaywallPresenter();
    CleanSlatePromptStore.noteSessionStart();
    final s = AppServices.instance;
    _microphonePermissionGateway =
        widget.microphonePermissionGateway ??
        PermissionHandlerMicrophoneGateway();
    _onboardingMicStateStore =
        widget.onboardingMicStateStore ?? OnboardingMicStateStore(s.prefs);
    _recording = s.recording;
    if (AppConfig.enableLiveVoiceCapture) {
      _liveVoice = widget.liveVoiceCapture ?? s.liveVoiceCapture;
    }
    _recordingState.bindDuration(
      _recording.durationSeconds,
      onTick: (seconds) {
        if (!mounted) return;
        setState(() {});
        if (_ui == RecordUiState.recording &&
            RecordingDurationPolicy.shouldAutoStop(seconds)) {
          unawaited(_stopAndProcess(reachedDurationLimit: true));
        }
      },
    );
    _refreshMic();
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
    _loadRecordReturnProState();
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
    unawaited(
      CurrentRelevanceStore.ensureLoaded().then((_) async {
        await CorrectionMemoryStore.ensureLoaded();
        if (mounted) setState(() {});
      }),
    );
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
    unawaited(
      BetaActivationLoopTracker.readCounts().then((counts) {
        if (mounted) setState(() => _betaActivationLoopCounts = counts);
      }),
    );
    unawaited(
      FirstProofTruthStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _loadFirstLoop();
    unawaited(_loadDefaultBoundaryPause());
    _loadReturnTriggerAccepted();
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
        _loadHookRescueDecision();
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
    } catch (_) {
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
    _disposePostSaveComparisonController();
    unawaited(_recordingState.dispose());
    super.dispose();
  }

  void _onPostSaveComparisonChanged() {
    if (mounted) setState(() {});
  }

  void _disposePostSaveComparisonController() {
    _postSaveComparisonController?.removeListener(_onPostSaveComparisonChanged);
    _postSaveComparisonController?.dispose();
    _postSaveComparisonController = null;
  }

  /// Text-first post-save comparison — no clinical SignalEngine or health gates.
  /// Only requires at least one prior saved moment; parser assigns evidence state.
  Future<void> _handlePostSavePatternComparison(List<JournalEntry> all) async {
    final moments = ArchiveMomentRecordMapper.fromJournalEntries(all);
    if (moments.length < 2) {
      RecordPipelineLog.postSaveComparisonSkipped(
        reason: 'no historical text context exists yet',
      );
      return;
    }

    final currentMoment = moments.last;
    final historicalMoments = moments.sublist(0, moments.length - 1);
    if (historicalMoments.isEmpty) {
      RecordPipelineLog.postSaveComparisonSkipped(
        reason: 'no historical text context exists yet',
      );
      return;
    }

    _disposePostSaveComparisonController();

    final prefs = ComparisonPreferenceStore(AppServices.instance.prefs);
    await prefs.ensureLoaded();
    if (!mounted) return;

    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!mounted) return;

    final controller = PostSaveComparisonController(
      apiClient: JournalComparisonModelApiClient(entries: all),
      prefs: prefs,
    );
    controller.addListener(_onPostSaveComparisonChanged);
    setState(() => _postSaveComparisonController = controller);

    await controller.processMomentComparison(
      currentMoment: currentMoment,
      historicalMoments: historicalMoments,
      isProUser: isPro,
    );
  }

  Widget _buildPostSaveSection() {
    final controller = _postSaveComparisonController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final uiState = controller.uiState;
    if (uiState is! ComparisonLoading && uiState is! ComparisonSuccess) {
      return const SizedBox.shrink();
    }

    return PostSaveComparisonSection(
      key: const Key('post_save_pattern_comparison_section'),
      controller: controller,
      onProUpgradeTapped: () async {
        _logger.info(
          'User tapped paywall CTA within the value moment evidence card.',
        );
        await _paywallPresenter.triggerNativePaywallSheet(
          requiredEntitlementId: SubscriptionEntitlements.pro,
        );
      },
    );
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
        showQuickHelpSheet(
          context,
          languageCode: _languageCode,
          onStartRecording: () => _onRecordPressed(source: 'main'),
          initialIntent: QuickHelpIntent.whatToRecord,
        );
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
    } catch (_) {
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
        AppServices.instance.journalStore.loadAllSync(),
        hasWatchTheme: false,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
      );
      return;
    }

    final all = await AppServices.instance.journal.loadAll();
    await BetaFeedbackStore.ensureLoaded();
    final watchItems = await ArchiveWatchlistStore(
      AppServices.instance.prefs,
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
    unawaited(BetaActivationLoopTracker.trackRecordScreenSeen());
    unawaited(_maybePresentYesterdaysSnapshot());
  }

  Future<void> _refreshArchiveReturnChanges(List<JournalEntry> entries) async {
    final store = ArchiveReturnChangesStore.fromAppPrefs(
      AppServices.instance.prefs,
    );
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
      AppServices.instance.prefs,
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
      onSave: (name) {
        PatternNameStore.setCustomName(patternKey, name);
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
      context.push(
        '/subscription',
        extra: PaywallRouteArgs(
          source: PaywallSource.valueMoment,
          sourceRoute: '/record',
        ),
      );
    }
  }

  Future<void> _dismissProLockMoment() async {
    await ProLockMomentDismissStore.dismiss();
    if (mounted) setState(() {});
  }

  Future<void> _dismissMonthlyPrivateReportPreview() async {
    await MonthlyPrivateReportDismissStore.dismiss();
    if (mounted) setState(() {});
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
    context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        source: PaywallSource.valueMoment,
        sourceRoute: '/record',
      ),
    );
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
    await AppServices.instance.journalStore.save(
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

    const uuid = Uuid();
    final entry = JournalEntry(
      id: uuid.v4(),
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

    await AppServices.instance.journalStore.save(
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

  String? _lastCtaPolicyLogLine;

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
    unawaited(_maybePresentYesterdaysSnapshot());
  }

  Future<void> _maybePresentYesterdaysSnapshot() async {
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
      context.push(YesterdaysSnapshotCopy.route, extra: hook);
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

  Widget _buildCaptureEntryActions({
    required BuildContext context,
    required String? selectedPrompt,
    required RecordCtaPolicyResolution policy,
    bool suppressLogPressureMoment = false,
  }) {
    return CaptureEntryActions(
      onRecord: () => unawaited(_onRecordPressed(source: 'main')),
      recordButtonKey: const Key('capture_entry_record_cta'),
      typeCapturePrompt: BetaImprovementPackEngine.typedCapturePrompt(
        fallback: selectedPrompt ?? '',
      ),
      onTextThoughtSaved: _finishSuccessfulCapture,
      onLogPressureMoment: suppressLogPressureMoment
          ? null
          : () => context.push('/pressure-check-in'),
      pressureMomentPresentation: suppressLogPressureMoment
          ? CapturePressureMomentPresentation.none
          : CapturePressureMomentPresentation.button,
      recordButtonLabel: _recordEntryCtaLabel(policy),
      underRecordHelper: null,
      preferTypedFirst: BetaImprovementPackEngine.preferTypedCaptureFirst(
        entryCount: _journalEntryCount,
      ),
    );
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
      ActivationTracker.trackActivationFirstRecordCtaTapped();
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
        Scrollable.ensureVisible(
          panelContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
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
      debugPrint(
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
      _disposePostSaveComparisonController();
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
        context.push(BeliefEvidenceNavigation.route);
      case ReturningUserTodayAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
    }
  }

  void _handleNextMomentPromptAction(NextMomentPromptAction action) {
    switch (action) {
      case NextMomentPromptAction.addMoment:
        _goToRecordTab();
      case NextMomentPromptAction.viewEvidence:
        context.push(BeliefEvidenceNavigation.route);
      case NextMomentPromptAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
    }
  }

  void _handleDailyArchiveExerciseAction(String route) {
    if (route == DailyArchiveExerciseCopy.recordRoute) {
      unawaited(_onRecordPressed(source: 'daily_archive_exercise'));
      return;
    }
    context.push(route);
  }

  void _handleTodaysOneQuestionAction(TodaysQuestionResult question) {
    if (question.primaryRoute == TodaysQuestionCopy.recordRoute) {
      setState(() => _selectedPromptLine = question.questionText);
      unawaited(_onRecordPressed(source: 'todays_one_question'));
      return;
    }
    context.push(question.primaryRoute);
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

  @override
  Widget build(BuildContext context) {
    var ui = _ui;
    var policyMic = _mic;
    var policyUserDenied = _micPermissionUserDenied;
    final firstUseSimplifiedRecord =
        ui == RecordUiState.ready &&
        RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
        );
    var error = _error;
    var localSaveTitle = _localSaveTitle;
    var syncNote = ConsumerCopyGuard.userFacingSyncNote(_syncNote);
    var stageLabel = _stageLabel;
    var entriesAfterSave = _entriesAfterSave;
    var lastCaptureAnalysisSucceeded = _lastCaptureAnalysisSucceeded;
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        ui = audit.ui;
        if (audit.entriesAfterSave != null) {
          entriesAfterSave = audit.entriesAfterSave!;
        }
        if (audit.micPhase != null) policyMic = audit.micPhase!;
        if (audit.userDeniedThisSession != null) {
          policyUserDenied = audit.userDeniedThisSession!;
        }
        error = audit.error;
        localSaveTitle = audit.localSaveTitle;
        syncNote = ConsumerCopyGuard.userFacingSyncNote(audit.syncNote);
        stageLabel = audit.stageLabel ?? _stageLabel;
        lastCaptureAnalysisSucceeded = audit.lastCaptureAnalysisSucceeded;
      }
    }

    final canRecord =
        (ui == RecordUiState.ready || ui == RecordUiState.recording) &&
        !RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(ui);
    final showFraming =
        ui == RecordUiState.ready ||
        ui == RecordUiState.idle ||
        ui == RecordUiState.requestingPermission ||
        ui == RecordUiState.permissionBlocked;
    final compact = _compactLayout(ui);
    final stack = _recordStackDecision(ui);
    if (stack.showFirstRecordingHandoff && !_firstRecordCardTracked) {
      _firstRecordCardTracked = true;
      ActivationTracker.trackActivationFirstRecordCardShown();
    }
    final suppressPostResultNextCheckCompetitors =
        stack.suppressDuplicateUseTomorrowCtas;
    final auditPresentation = VisualAuditOverrides.active
        ? VisualAuditOverrides.peekRecordPresentation()
        : null;
    final justSavedFirstEntry =
        _recordReturnProJustSaved ||
        (auditPresentation?.justSavedFirst ?? false);
    final postSaveEntryCount = entriesAfterSave.isNotEmpty
        ? entriesAfterSave.length
        : _journalEntryCount;
    final suppressNoisyFirstSaveCards =
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: justSavedFirstEntry,
          entryCount: ui == RecordUiState.done && justSavedFirstEntry
              ? postSaveEntryCount
              : _journalEntryCount,
        );
    final suppressEarlyPatternClaimCards =
        FirstThreeSessionGates.suppressEarlyPatternClaimCards(
          entryCount: _journalEntryCount,
          hasGroundedRepeatMatch:
              _secondSessionComparison?.hasEnoughData == true &&
              const SecondSessionSignalEngine().hasGroundedRepeatMatch(
                _entriesAfterSave.isNotEmpty
                    ? _entriesAfterSave
                    : _journalEntries,
              ),
        );
    final suppressLatestSaveArchiveInsight =
        ui == RecordUiState.done &&
        ArchiveEntrySignalGuard.newestEntryIsLowSignal(entriesAfterSave);
    final secondSessionPayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? SecondSessionPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final thirdEntryBeliefPayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? ThirdEntryBeliefPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final confirmedRepeatTriggerPayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            _savedFromConfirmedRepeatTrigger
        ? EarlyFirstSignalEngine.buildTriggerCapturePayoff(
            entries: entriesAfterSave,
            savedFromTriggerPrompt: true,
          )
        : null;
    final confirmedRepeatHelpfulActionPayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            _savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildHelpfulActionPayoff(
            entries: entriesAfterSave,
            savedFromHelpfulActionPrompt: true,
          )
        : null;
    final confirmedRepeatChangeNotice =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !_savedFromConfirmedRepeatTrigger &&
            !_savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildChangeNotice(entries: entriesAfterSave)
        : null;
    final repeatReturnCheckOffer =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? RepeatReturnCheckEngine.pendingForSave(
            entriesAfterSave: entriesAfterSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final earlyEvidenceTimeline =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
              loaded: _journalEntryCountReady,
              entryCount: _journalEntryCount,
              isPostSave: _isPostSaveSurface,
            )
        ? EarlyEvidenceTimelineEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showEarlyEvidenceTimeline = earlyEvidenceTimeline != null;
    final suppressEarlyRepeatPayoffCompetitors =
        confirmedRepeatTriggerPayoff != null ||
        confirmedRepeatHelpfulActionPayoff != null ||
        confirmedRepeatChangeNotice != null;
    final earlyFirstSignalOnRecord =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !showEarlyEvidenceTimeline
        ? EarlyFirstSignalEngine.build(entries: _journalEntries)
        : null;
    final returnTomorrowCueReady =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? ReturnTomorrowCueEngine.buildReady(entries: _journalEntries)
        : null;
    final returnDayFlowCandidate =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? ReturnDayFlowEngine.build(entries: _journalEntries)
        : null;
    final showReturnDayFlow = ReturnDayFlowGates.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      flow: returnDayFlowCandidate,
      dismissedToday: ReturnDayFlowEngine.shouldHideForDismissal(),
    );
    final showReturnTomorrowCueReady =
        ReturnTomorrowCueGates.shouldShowReady(
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          cue: returnTomorrowCueReady,
        ) &&
        !showReturnDayFlow;
    final firstWeekProgressReady =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? FirstWeekProgressEngine.buildReady(entries: _journalEntries)
        : null;
    final showFirstWeekProgressReady = FirstWeekProgressGates.shouldShowReady(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      progress: firstWeekProgressReady,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCue: showReturnTomorrowCueReady,
    );
    final showEarlyReturnReminder =
        V1CapabilityRegistry.notifications &&
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        !showReturnDayFlow &&
        !showReturnTomorrowCueReady &&
        _earlyReturnReminderOffer &&
        !_earlyReturnReminderHidden &&
        !suppressEarlyRepeatPayoffCompetitors &&
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: _journalEntryCount,
          entries: _journalEntries,
          hasRealTimeline:
              showEarlyEvidenceTimeline ||
              EarlyEvidenceTimelineEngine.build(
                    entries: _journalEntries,
                    triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
                    helpfulActionCapturedMilestone:
                        _earlyEvidenceHelpfulCaptured,
                  ) !=
                  null,
        ) &&
        (showEarlyEvidenceTimeline ||
            (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false));
    final viewingConfirmedRepeatOnRecord =
        showEarlyEvidenceTimeline ||
        (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false);
    final suppressConfirmedRepeatInlineFeedback =
        ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
          state: ConfirmedRepeatBetaFeedbackStore.cached,
        );
    final showConfirmedRepeatBetaFeedback =
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
        _journalEntryCount >= ConfirmedRepeatBetaFeedbackGates.minEntryCount &&
        viewingConfirmedRepeatOnRecord;
    final repeatReturnChangeProof =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? RepeatReturnCheckEngine.changeProofForReady(
            entryCount: _journalEntryCount,
            viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final patternChangedCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternChangedEngine.build(
            changeProof: repeatReturnChangeProof,
            records: RepeatReturnCheckStore.cached,
            entries: _journalEntries,
          )
        : null;
    final patternChangedDismissed =
        patternChangedCandidate != null &&
        PatternChangedStore.isDismissed(
          entryId: patternChangedCandidate.entryId,
          type: patternChangedCandidate.type,
        );
    final confirmedRepeatThoughtMap =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ConfirmedRepeatThoughtMapEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final positivePattern =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PositivePatternEngine.build(entries: _journalEntries)
        : null;
    final helpfulActionAppearedCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? HelpfulActionAppearedEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showHelpfulActionAppearedEligible =
        HelpfulActionAppearedGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          hasConfirmedRepeatFoundation:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _journalEntries,
              ),
          result: helpfulActionAppearedCandidate,
        );
    final positiveReinforcement =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface &&
            !showHelpfulActionAppearedEligible
        ? PositiveReinforcementEngine.build(
            positivePattern: positivePattern,
            entries: _journalEntries,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final archiveSummaryCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ArchiveSummaryEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            timeline: earlyEvidenceTimeline,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveBeliefSurfaceCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternNameEngine.applyDisplayLabels(
            ArchiveBeliefSurfaceSource().resolve(
              _journalEntries,
              confirmedRepeat: earlyFirstSignalOnRecord,
              changeProof: repeatReturnChangeProof,
              returnChecks: RepeatReturnCheckStore.cached,
              triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
              helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
              viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            ),
          )
        : ArchiveBeliefSurface.none;
    final patternNamePrompt =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternNameEngine.buildPrompt(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
          )
        : null;
    final showArchiveCurrentBeliefEligible =
        ArchiveCurrentBeliefGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          hasConfirmedRepeatFoundation:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _journalEntries,
              ),
          hasCurrentBeliefSurface:
              archiveBeliefSurfaceCandidate.isPrimaryAfterFirstProof &&
              archiveBeliefSurfaceCandidate.shouldShow,
        );
    final dailyReturnReasonCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? DailyReturnReasonEngine.build(
            entries: _journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final hasChangeOverTimeProof = repeatReturnChangeProof != null;
    final postProofArchiveProof = PaywallTimingGates.hasArchiveProofFromEntries(
      entries: _journalEntries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      hasChangeOverTimeProof: hasChangeOverTimeProof,
    );
    final archiveSummaryVisibleForProGate = ArchiveSummaryGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasSummary: archiveSummaryCandidate != null,
    );
    final weeklyArchiveReviewVisibleForProGate =
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
          loaded: _journalEntryCountReady,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          entries: _journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final hasConfirmedRepeatForProGate =
        viewingConfirmedRepeatOnRecord &&
        ((earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false) ||
            showEarlyEvidenceTimeline);
    final privateArchiveReportForProGate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PrivateArchiveReportEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final privateArchiveReportPreviewForProGate =
        privateArchiveReportForProGate != null &&
        PrivateArchiveReportGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          report: privateArchiveReportForProGate,
        ) &&
        PrivateArchiveReportGates.showPreviewNote(isPro: _recordReturnProIsPro);
    final patternChangedForProGate =
        patternChangedCandidate != null &&
        viewingConfirmedRepeatOnRecord &&
        _journalEntryCount > FirstThreeSessionGates.minEntriesForUsefulArchive;
    final hasReturnCheckAnsweredForProGate =
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(
          RepeatReturnCheckStore.cached,
        ) &&
        _journalEntryCount >=
            PaywallTimingGates.minFullArchiveHistoryEntryCount;
    final showPostProofProBridge =
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        _recordReturnProState != null &&
        PaywallTimingGates.showPostProofProBridge(
          entryCount: _journalEntryCount,
          resolved: _recordReturnProState!.proBridgeResolved,
          isPro: _recordReturnProIsPro,
          hasArchiveProof: postProofArchiveProof,
          viewingConfirmedRepeatOrTimeline: hasConfirmedRepeatForProGate,
          hasChangeOverTimeProof: hasChangeOverTimeProof,
          isPostSave: _isPostSaveSurface,
          hasArchiveSummary: archiveSummaryVisibleForProGate,
          hasWeeklyArchiveReview: weeklyArchiveReviewVisibleForProGate,
          hasPatternChanged: patternChangedForProGate,
          hasPrivateArchiveReportPreview: privateArchiveReportPreviewForProGate,
          hasReturnCheckAnswered: hasReturnCheckAnsweredForProGate,
        );
    final proofSurfaceLayout = ArchiveProofSurfaceLayout(
      confirmedRepeatCardVisible:
          earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false,
      timelineVisible: showEarlyEvidenceTimeline,
      changeProofVisible: repeatReturnChangeProof != null,
      proBridgeVisible: showPostProofProBridge,
      whyMattersVisible: ConfirmedRepeatWhyMattersGates.shouldShow(
        loaded: _journalEntryCountReady,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        dismissed: ConfirmedRepeatWhyMattersStore.cachedDismissed,
      ),
      thoughtMapVisible: ConfirmedRepeatThoughtMapGates.shouldShow(
        loaded: _journalEntryCountReady,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        hasThoughtMap: confirmedRepeatThoughtMap != null,
      ),
      positiveReinforcementVisible: PositiveReinforcementGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        hasPositivePattern: positiveReinforcement != null,
      ),
      positivePatternVisible: false,
      helpfulActionAppearedVisible: showHelpfulActionAppearedEligible,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        isPostSave: _isPostSaveSurface,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
      archiveSummaryVisible: ArchiveSummaryGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
        hasSummary: archiveSummaryCandidate != null,
      ),
      archiveCurrentBeliefVisible: showArchiveCurrentBeliefEligible,
    );
    final showArchiveSummary =
        proofSurfaceLayout.effectiveArchiveSummaryVisible;
    final archiveSummary = showArchiveSummary ? archiveSummaryCandidate : null;
    final showDailyReturnReason = DailyReturnReasonGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasReason: dailyReturnReasonCandidate != null,
    );
    final dailyReturnReason = showDailyReturnReason
        ? dailyReturnReasonCandidate
        : null;
    final archiveWatchingCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ArchiveWatchingEngine.build(
            entries: _journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveWatching =
        ArchiveWatchingGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          archiveSummaryVisible: showArchiveSummary,
          hasWatching: archiveWatchingCandidate != null,
        )
        ? archiveWatchingCandidate
        : null;
    final weeklyArchiveReview =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? weekly_review_surface.WeeklyArchiveReviewEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final showWeeklyArchiveReview =
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
          loaded: _journalEntryCountReady,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          entries: _journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final privateArchiveReportCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PrivateArchiveReportEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final showPrivateArchiveReport = PrivateArchiveReportGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      report: privateArchiveReportCandidate,
    );
    final showConfirmedRepeatWhyMatters =
        proofSurfaceLayout.effectiveWhyMattersVisible;
    final showConfirmedRepeatThoughtMap =
        proofSurfaceLayout.effectiveThoughtMapVisible;
    final showPositiveReinforcement =
        proofSurfaceLayout.effectivePositiveReinforcementVisible;
    final firstWeekLoopCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? FirstWeekLoopEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final firstWeekLoopProGated = FirstWeekLoopGates.isProRequirementGated(
      valueMomentProBridgeVisible:
          _valueMomentBridge != null && _valueMomentBridge!.show,
      purchaseIntentReturnCueVisible: _purchaseIntentCue != null,
    );
    final recordProofStack = RecordProofStackPolicy.decide(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isPostSave: _isPostSaveSurface,
      isRecording: ui == RecordUiState.recording,
      archiveSummaryVisible: showArchiveSummary,
      hasEarlyFirstSignal:
          EarlyFirstSignalEngine.build(entries: _journalEntries) != null,
      hasEarlyEvidenceTimeline: showEarlyEvidenceTimeline,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        isPostSave: _isPostSaveSurface,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
      dailyReturnReasonEligible: showDailyReturnReason,
      weeklyReviewEligible: showWeeklyArchiveReview,
      privateReportEligible: showPrivateArchiveReport,
      whyMattersEligible: showConfirmedRepeatWhyMatters,
      thoughtMapEligible: showConfirmedRepeatThoughtMap,
      positiveReinforcementEligible: showPositiveReinforcement,
      helpfulActionAppearedEligible: showHelpfulActionAppearedEligible,
      changeProofEligible: repeatReturnChangeProof != null,
      firstWeekLoopEligible:
          firstWeekLoopCandidate != null && !firstWeekLoopProGated,
      proBridgeEligible: showPostProofProBridge,
      archiveCurrentBeliefEligible: showArchiveCurrentBeliefEligible,
    );
    final showPatternChanged = recordProofStack.showPatternChanged;
    final showArchiveCurrentBeliefOnRecord =
        recordProofStack.showArchiveCurrentBelief;
    final showEarlyEvidenceTimelineOnRecord =
        recordProofStack.showEarlyEvidenceTimeline;
    final showWeeklyArchiveReviewOnRecord =
        recordProofStack.showWeeklyArchiveWeekReview;
    final showPrivateArchiveReportOnRecord =
        recordProofStack.showPrivateArchiveReport;
    final showDailyReturnReasonOnRecord =
        recordProofStack.showDailyReturnReason;
    final showPostProofProBridgeOnRecord = recordProofStack.showProBridge;
    final firstProofPayoffSeenOnRecord =
        FirstProofPayoffEngine.build(entries: _journalEntries) != null;
    final isDegradedTranscriptOnRecord =
        _journalEntries.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(_journalEntries.last);
    final currentRelevanceCandidate = _journalEntryCount >= 3
        ? CurrentRelevanceEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    final patternReviewInboxActiveOnRecord =
        CurrentRelevanceEngine.patternReviewInboxHasActiveItems(
          entries: _journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    var showCurrentRelevanceOnRecordReady =
        ui == RecordUiState.ready &&
        CurrentRelevanceEngine.shouldShowOnRecordReady(
          state: currentRelevanceCandidate,
          isZeroEntryState: _journalEntryCount == 0,
          isFirstRecordingState:
              _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final currentRelevanceQuestionActiveOnRecord =
        CurrentRelevanceEngine.isQuestionActive(
          state: currentRelevanceCandidate,
          visible: showCurrentRelevanceOnRecordReady,
        );
    final correctionMemoryCandidate = CorrectionMemoryEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    var showCorrectionMemoryOnRecordReady =
        ui == RecordUiState.ready &&
        showCurrentRelevanceOnRecordReady &&
        CorrectionMemoryEngine.shouldShowOnRecordReady(
          result: correctionMemoryCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final evidenceWeightingCandidate = _journalEntryCount >= 3
        ? EvidenceWeightingEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    var showEvidenceWeightingOnRecordReady =
        ui == RecordUiState.ready &&
        EvidenceWeightingEngine.shouldShowOnRecordReady(
          result: evidenceWeightingCandidate,
          isZeroEntryState: _journalEntryCount == 0,
          isFirstRecordingState:
              _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final proofSpecificityCandidate = _journalEntryCount >= 3
        ? ProofSpecificityEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
          )
        : ProofSpecificityEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: false,
            source: 'record',
          );
    var showProofSpecificityOnRecordReady =
        ui == RecordUiState.ready &&
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: proofSpecificityCandidate,
          isZeroEntryState: _journalEntryCount == 0,
          isFirstRecordingState:
              _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final presentDayRelevanceCandidate = _journalEntryCount >= 3
        ? PresentDayRelevanceEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    var showPresentDayRelevanceOnRecordReady =
        ui == RecordUiState.ready &&
        PresentDayRelevanceEngine.shouldShowOnRecordReady(
          result: presentDayRelevanceCandidate,
          isZeroEntryState: _journalEntryCount == 0,
          isFirstRecordingState:
              _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showCaptureFreedomLine =
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          entryCount: _journalEntryCount,
        );
    final timelinePositioningCandidate = TimelinePositioningEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    final otherEducationCardsOnRecord =
        TimelinePositioningEngine.countOtherEducationCards(
          captureFreedomLineVisible: showCaptureFreedomLine,
          currentRelevanceVisible:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          evidenceWeightingVisible:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
        );
    var showTimelinePositioningOnRecordReady =
        ui == RecordUiState.ready &&
        TimelinePositioningEngine.shouldShowOnRecordReady(
          result: timelinePositioningCandidate,
          entryCount: _journalEntryCount,
          otherEducationCardCount: otherEducationCardsOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final patternConfidenceEducationCount =
        PatternConfidenceEngine.countOtherEducationCards(
          captureFreedomLineVisible: showCaptureFreedomLine,
          timelinePositioningVisible: showTimelinePositioningOnRecordReady,
          currentRelevanceVisible:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemoryVisible:
              showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          evidenceWeightingVisible:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
        );
    final patternConfidenceExplanationCandidate =
        PatternConfidenceEngine.buildExplanation(
          entries: _journalEntries,
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          source: 'record',
          returnChecks: RepeatReturnCheckStore.cached,
          changeProof: repeatReturnChangeProof,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        );
    var showPatternConfidenceExplanationOnRecordReady =
        ui == RecordUiState.ready &&
        PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
          result: patternConfidenceExplanationCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          otherEducationCardCount: patternConfidenceEducationCount,
        );
    var showProEvidenceValueOnRecordReady =
        showPostProofProBridgeOnRecord &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: _journalEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isZeroEntryState: _journalEntryCount == 0,
            isFirstRecordingState:
                _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            currentRelevanceQuestionActive:
                currentRelevanceQuestionActiveOnRecord,
          ),
        );
    var showProBridgeVisibilityOnRecordReady = false;
    var showProEvidenceValuePrivateReportOnRecord =
        showPrivateArchiveReportOnRecord &&
        privateArchiveReportPreviewForProGate &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.privateReportPreview,
            entryCount: _journalEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            privateReportPreviewVisible: true,
          ),
        );
    final showConfirmedRepeatWhyMattersOnRecord =
        recordProofStack.showConfirmedRepeatWhyMatters;
    final showConfirmedRepeatThoughtMapOnRecord =
        recordProofStack.showConfirmedRepeatThoughtMap;
    final showPositiveReinforcementOnRecord =
        recordProofStack.showPositiveReinforcement;
    final showHelpfulActionAppearedOnRecord =
        recordProofStack.showHelpfulActionAppeared;
    final showChangeProofOnRecord = recordProofStack.showChangeProof;
    final showFirstWeekLoopOnRecord = FirstWeekLoopGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isProRequirementGated: firstWeekLoopProGated,
      policyAllows: recordProofStack.showFirstWeekLoop,
      loop: firstWeekLoopCandidate,
    );
    final firstProofPayoffCandidate =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? FirstProofPayoffEngine.build(entries: entriesAfterSave)
        : null;
    var showFirstProofPayoff = FirstProofPayoffGates.shouldShow(
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      payoff: firstProofPayoffCandidate,
    );
    final threeDayChallengeCandidate =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? ThreeDayChallengeEngine.build(entries: _journalEntries)
        : null;
    final showThreeDayChallengeOnRecord = ThreeDayChallengeGates.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState:
          ThreeDayChallengeEngine.shouldHideForDegradedTranscript(
            _journalEntries,
          ),
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      challenge: threeDayChallengeCandidate,
    );
    final firstProofPatternConfidence =
        showFirstProofPayoff && firstProofPayoffCandidate != null
        ? PatternConfidenceEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            hideNotEnoughYet: true,
          )
        : null;
    final firstProofTruthProofKey = showFirstProofPayoff
        ? FirstProofTruthGates.proofKeyForEntries(entriesAfterSave)
        : '';
    final showFirstProofTruth = FirstProofTruthGates.shouldShow(
      showFirstProofPayoff: showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      entries: entriesAfterSave,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof:
          firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofTruthAnswer = firstProofTruthProofKey.isNotEmpty
        ? FirstProofTruthStore.answerFor(firstProofTruthProofKey)
        : null;
    final showFirstProofActionLoop = FirstProofActionLoopGates.shouldShow(
      showFirstProofPayoff: showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof:
          firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofActionLoopContent =
        showFirstProofActionLoop &&
            firstProofTruthAnswer != null &&
            firstProofPayoffCandidate != null
        ? FirstProofActionLoopEngine.build(
            answer: firstProofTruthAnswer,
            entries: entriesAfterSave,
            payoff: firstProofPayoffCandidate,
          )
        : null;
    final showFirstProofMoment = showFirstProofPayoff;
    final postSaveHasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entriesAfterSave);
    final postSaveHasFirstProof = CoreValueFeedbackGates.hasFirstProof(
      entryCount: postSaveEntryCount,
      hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
    );
    final postSaveDegraded =
        entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final showCoreValueFeedbackOnRecordPostFirstProof =
        !showFirstProofPayoff &&
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: showFirstProofMoment,
          isPostSaveDone: ui == RecordUiState.done,
          entryCount: postSaveEntryCount,
          hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
          isRecording: ui == RecordUiState.recording,
          isDegradedPostSave: postSaveDegraded,
          isProPaywallVisible: false,
        );
    final returnCheckPayoffCandidate =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? ReturnCheckPayoffEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Prompt =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPrompt(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Display =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPostSaveDisplay(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final showWhatChangedV2 = WhatChangedV2Engine.shouldShowOnPostSave(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      prompt: whatChangedV2Prompt,
    );
    final showWhatChangedV2Display =
        WhatChangedV2Engine.shouldShowPostSaveDisplay(
          isPostSaveDone: ui == RecordUiState.done,
          isDegradedPostSave:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          showFirstProofMoment: showFirstProofMoment,
          display: whatChangedV2Display,
        );
    var showOpenCapturePromptChips = OpenCaptureEngine.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    var showLowFrictionReturnCard = LowFrictionReturnEngine.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
      entries: _journalEntries,
      dismissedForToday: LowFrictionReturnStore.isDismissedToday,
    );
    final firstMomentCaptureCandidate = FirstMomentCaptureEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    final firstSaveLiftCandidate = FirstSaveLiftEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    var firstSessionCaptureRepairCandidate =
        FirstSessionProofRepairEngine.buildCapture(
          entryCount: _journalEntryCount,
          source: 'record',
        );
    final openingRepairOverride = BetaRepairLabEngine.openingCaptureOverride(
      base: firstSessionCaptureRepairCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    );
    if (openingRepairOverride != null) {
      firstSessionCaptureRepairCandidate = openingRepairOverride;
    }
    var showFirstSessionCaptureRepairCard =
        FirstSessionProofRepairEngine.shouldShowCapture(
          result: firstSessionCaptureRepairCandidate,
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPermissionBlocked: ui == RecordUiState.permissionBlocked,
          entryCount: _journalEntryCount,
        );
    final firstSessionLiftCandidate = FirstSessionLiftEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    var showFirstSessionLiftCard = FirstSessionLiftEngine.shouldShow(
      result: firstSessionLiftCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    var showFirstSaveLiftCard = FirstSaveLiftEngine.shouldShow(
      result: firstSaveLiftCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    if (BetaRepairLabEngine.suppressFirstSessionLiftWhenOpeningRepairActive(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      showOpeningRepair: showFirstSessionCaptureRepairCard,
    )) {
      showFirstSessionLiftCard = false;
      showFirstSaveLiftCard = false;
    }
    var showFirstMomentCaptureCard = FirstMomentCaptureEngine.shouldShow(
      result: firstMomentCaptureCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    final secondMomentReturnCandidate = SecondMomentReturnEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    var showSecondMomentReturnCard = SecondMomentReturnEngine.shouldShow(
      result: secondMomentReturnCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: _journalEntryCount,
    );
    final threeMomentCompletionCandidate = ThreeMomentCompletionEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    var showThreeMomentCompletionCard = ThreeMomentCompletionEngine.shouldShow(
      result: threeMomentCompletionCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
      dismissedForToday: ThreeMomentCompletionStore.isDismissedToday,
    );
    final firstRunPositioningCandidate = FirstRunPositioningEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    var showFirstRunPositioningCard = FirstRunPositioningEngine.shouldShow(
      result: firstRunPositioningCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofSeen: firstProofPayoffSeenOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    final betaTodaySummaryCandidate = BetaTodaySummaryEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    var showBetaTodaySummaryCard = BetaTodaySummaryEngine.shouldShow(
      result: betaTodaySummaryCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    final archiveTimelineSpineCandidate = _journalEntryCount >= 3
        ? ArchiveTimelineSpineEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    final whatToNoticeNextCandidate = WhatToNoticeNextEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    var showWhatToNoticeNextCard = WhatToNoticeNextEngine.shouldShow(
      result: whatToNoticeNextCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: _journalEntryCount,
      lowFrictionReturnVisible: showLowFrictionReturnCard,
      betaTodaySummaryVisible: showBetaTodaySummaryCard,
      openCapturePromptChipsVisible: showOpenCapturePromptChips,
    );
    var showArchiveTimelineSpineOnRecord =
        ui == RecordUiState.ready &&
        ArchiveTimelineSpineEngine.shouldShowOnRecordReady(
          result: archiveTimelineSpineCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final suppressLegacyEducationCardsForSpineOnRecord =
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
          result: archiveTimelineSpineCandidate,
          visible: showArchiveTimelineSpineOnRecord,
        );
    final timelineProofMomentCandidate = archiveTimelineSpineCandidate != null
        ? TimelineProofMomentEngine.buildFromSpine(
            spine: archiveTimelineSpineCandidate,
            entries: _journalEntries,
            source: 'record',
          )
        : null;
    var showTimelineProofMomentOnRecord =
        TimelineProofMomentEngine.shouldShowOnRecordReady(
          result: timelineProofMomentCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final betaTesterReportCandidate = BetaTesterReportEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    var showBetaTesterReportOnRecord = BetaTesterReportEngine.shouldShow(
      result: betaTesterReportCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    showProBridgeVisibilityOnRecordReady = false;
    final notRelevantRecoveryCandidate = NotRelevantRecoveryEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    final proofQualityResponseTimelineCandidate =
        ProofQualityResponseEngine.build(
          entries: _journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
          source: 'record',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseSpineCandidate = ProofQualityResponseEngine.build(
      entries: _journalEntries,
      surface: ProofQualityResponseSurface.archiveTimelineSpine,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final betaProofLiftTimelineCandidate = BetaProofLiftEngine.build(
      entries: _journalEntries,
      surface: BetaProofLiftSurface.timelineProofMoment,
      source: 'record',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentCandidate,
    );
    final returnAfterProofRecordCandidate = ReturnAfterProofEngine.build(
      entries: _journalEntries,
      source: 'record',
      firstProofSeen: firstProofPayoffSeenOnRecord,
      timelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      betaTesterReportVisible: showBetaTesterReportOnRecord,
    );
    var showReturnAfterProofStrengthenedOnRecordReady =
        ReturnAfterProofEngine.shouldShowStrengthenedOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofGenericOnRecordReady =
        ReturnAfterProofEngine.shouldShowGenericOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          betaTesterReportVisible: showBetaTesterReportOnRecord,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofOnRecordReady =
        showReturnAfterProofStrengthenedOnRecordReady ||
        showReturnAfterProofGenericOnRecordReady;
    final returnAfterProofLiftV2Candidate = ReturnAfterProofLiftV2Engine.build(
      entries: _journalEntries,
      source: 'record',
      firstProofSeen: firstProofPayoffSeenOnRecord,
      timelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
    );
    var showReturnAfterProofLiftV2OnRecordReady =
        ReturnAfterProofLiftV2Engine.shouldShow(
          result: returnAfterProofLiftV2Candidate,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: false,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final recordLoosenSignalsPreAudit =
        ProBridgeTimingLoosenEngine.resolveSignals(
          entries: _journalEntries,
          source: 'record_ready',
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final recordEvidenceAnchorPreAudit = EvidenceAnchorEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record_ready',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final recordFeedbackStateForLift =
        ProMomentTimingEngine.resolveFeedbackState(
          entries: _journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
        );
    final timelineFeedbackType = BetaProofFeedbackStore.recordFor(
      BetaProofFeedbackSurface.timelineProofMoment,
    ).feedbackType;
    final betaRepairLabInput = BetaRepairLabVisibilityInput(
      mode: BetaRepairLabStore.activeMode,
      entryCount: _journalEntryCount,
      source: 'record_ready',
      isPro: _recordReturnProIsPro,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      hasTimelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        _journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasUsefulProofFeedback:
          timelineFeedbackType == BetaProofFeedbackType.useful,
      feedbackType: timelineFeedbackType,
      isNegativeFeedback:
          timelineFeedbackType == BetaProofFeedbackType.tooVague ||
          timelineFeedbackType == BetaProofFeedbackType.notRelevant,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    );
    var showBetaRepairLabProPlacementOnRecord =
        BetaRepairLabEngine.shouldShowProPlacement(input: betaRepairLabInput);
    final betaRepairLabProPlacementResult =
        showBetaRepairLabProPlacementOnRecord
        ? BetaRepairLabEngine.buildProPlacement(input: betaRepairLabInput)
        : BetaRepairLabProPlacementResult.hidden;
    var showBetaRepairLabPricingValueFramingOnRecord =
        PricingValueFramingEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPricingValueFramingResult =
        showBetaRepairLabPricingValueFramingOnRecord
        ? PricingValueFramingEngine.build(input: betaRepairLabInput)
        : PricingValueFramingResult.hidden;
    var showBetaRepairLabPaywallValueOnRecord =
        PaywallValueRepairEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPaywallValueResult =
        showBetaRepairLabPaywallValueOnRecord
        ? PaywallValueRepairEngine.build(input: betaRepairLabInput)
        : PaywallValueRepairResult.hidden;
    final hasProEngagementOnRecord =
        _betaActivationLoopCounts.paywallSeen > 0 ||
        _betaActivationLoopCounts.purchaseTapped > 0 ||
        _betaActivationLoopCounts.proBoundarySeen > 0;
    var showBetaRepairLabPricingValidationOnRecord =
        PricingValidationEngine.shouldShow(
          input: betaRepairLabInput,
          hasProEngagement: hasProEngagementOnRecord,
        );
    var showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    final betaRepairLabPricingValidationResult =
        showBetaRepairLabPricingValidationOnRecord
        ? PricingValidationEngine.build(
            input: betaRepairLabInput,
            hasProEngagement: hasProEngagementOnRecord,
          )
        : PricingValidationResult.hidden;
    final proUnderstandingLiftRecordReadyInput =
        ProUnderstandingLiftVisibilityInput(
          surface: ProUnderstandingLiftSurface.recordReady,
          source: 'record_ready',
          entryCount: _journalEntryCount,
          isPro: _recordReturnProIsPro,
          hasUsefulProof:
              recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: recordFeedbackStateForLift,
          hasProEngagement: hasProEngagementOnRecord,
          hasFreshReturnAfterCorrection:
              recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showProUnderstandingLiftOnRecordReady =
        ProUnderstandingLiftEngine.shouldShowCard(
          input: proUnderstandingLiftRecordReadyInput,
        );
    var showProVisibilityLiftOnRecordReady =
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: _journalEntryCount,
          isPro: _recordReturnProIsPro,
          hasUsefulProof:
              recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: recordFeedbackStateForLift,
          hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
          hasFreshReturnAfterCorrection:
              recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var proUnderstandingLiftRecordReadyResult =
        showProUnderstandingLiftOnRecordReady
        ? ProUnderstandingLiftEngine.build(
            input: proUnderstandingLiftRecordReadyInput,
          )
        : null;
    if (proUnderstandingLiftRecordReadyResult != null) {
      proUnderstandingLiftRecordReadyResult =
          BetaRepairLabEngine.applyProExplanationCopy(
            base: proUnderstandingLiftRecordReadyResult,
            betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          ) ??
          proUnderstandingLiftRecordReadyResult;
    }
    final proVisibilityLiftRecordReadyResult =
        showProVisibilityLiftOnRecordReady
        ? ProVisibilityLiftEngine.build(
            surface: ProVisibilityLiftSurface.recordReady,
            source: 'record_ready',
            entryCount: _journalEntryCount,
            isPro: _recordReturnProIsPro,
            hasUsefulProof:
                recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
            confidenceLevel:
                recordLoosenSignalsPreAudit.confidenceLevel ??
                ProofConfidenceLevel.watchOnly,
            feedbackState: recordFeedbackStateForLift,
            hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
            hasFreshReturnAfterCorrection:
                recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
            hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          )
        : null;
    var showProofQualityResponseOnRecordReady =
        ui == RecordUiState.ready &&
        proofQualityResponseTimelineCandidate.shouldShow &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showNotRelevantRecoveryOnRecordReady =
        ui == RecordUiState.ready &&
        notRelevantRecoveryCandidate.shouldShow &&
        NotRelevantRecoveryEngine.shouldRender(
          result: notRelevantRecoveryCandidate,
          parentVisible: true,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showBetaProofLiftOnRecordReady =
        ui == RecordUiState.ready &&
        showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        BetaProofLiftEngine.shouldRender(
          result: betaProofLiftTimelineCandidate,
          qualityResponse: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    showProBridgeVisibilityOnRecordReady =
        showPostProofProBridgeOnRecord &&
        ProBridgeVisibilityEngine.shouldShow(
          input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
            base: ProBridgeVisibilityInput(
              surface: ProBridgeVisibilitySurface.recordReady,
              source: 'record_ready',
              entryCount: _journalEntryCount,
              isPro: _recordReturnProIsPro,
              postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
              hasFirstProof:
                  firstProofPayoffSeenOnRecord ||
                  EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                    _journalEntries,
                  ),
              isRecording: ui == RecordUiState.recording,
              isZeroEntryState: _journalEntryCount == 0,
              isFirstRecordingState:
                  _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              hasTimelineProofVisible:
                  showTimelineProofMomentOnRecord &&
                  timelineProofMomentCandidate != null,
              hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
              hasCorrectionMemoryVisible:
                  showCorrectionMemoryOnRecordReady &&
                  correctionMemoryCandidate != null,
              feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                entries: _journalEntries,
                surface: ProofQualityResponseSurface.timelineProofMoment,
              ),
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActiveOnRecord,
              compact: proofSurfaceLayout.proBridgeCompact,
              hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
              hasOpenedEvidenceTrail:
                  DelayedPaywallProofStore.hasOpenedEvidenceTrail,
            ),
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
            hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
            hasReturnAfterProofStrengthenedVisible:
                showReturnAfterProofStrengthenedOnRecordReady,
          ),
        );
    final betaActivationPathPreAuditContext =
        BetaActivationPathEngine.buildContext(
          source: 'record',
          entryCount: _journalEntryCount,
          hasTimelineProof:
              showTimelineProofMomentOnRecord ||
              showArchiveTimelineSpineOnRecord,
          hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
          hasPurchaseCtaTapped: _betaActivationLoopCounts.purchaseTapped > 0,
          strongerProCardVisible:
              showProBridgeVisibilityOnRecordReady ||
              showProEvidenceValueOnRecordReady ||
              showProVisibilityLiftOnRecordReady,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          isPermissionBlocked: ui == RecordUiState.permissionBlocked,
        );
    final betaActivationPathPreAuditResult = BetaActivationPathEngine.build(
      context: betaActivationPathPreAuditContext,
    );
    var showBetaActivationPathCard =
        betaActivationPathPreAuditResult.shouldShow;
    BetaActivationPathResult? betaActivationPathResult;
    final betaFeedbackCaptureRecordReadyPreAudit =
        BetaFeedbackCaptureEngine.build(
          context: BetaFeedbackCaptureEngine.buildContext(
            surface: BetaFeedbackCaptureSurface.recordReady,
            source: 'record',
            entryCount: _journalEntryCount,
            isReady: ui == RecordUiState.ready,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
            hasPurchaseCtaTapped: _betaActivationLoopCounts.purchaseTapped > 0,
            isPro: _recordReturnProIsPro,
            timelineProofVisible:
                showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null,
            existingProofFeedbackVisible:
                BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                  surface: BetaProofFeedbackSurface.timelineProofMoment,
                  parentVisible:
                      showTimelineProofMomentOnRecord &&
                      timelineProofMomentCandidate != null,
                  entryCount: _journalEntryCount,
                  hasConfirmedRepeat:
                      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                        _journalEntries,
                      ),
                  isRecording: ui == RecordUiState.recording,
                  isPostSaveDegraded: false,
                  whatChangedQuestionActive: showWhatChangedV2,
                  patternReviewInboxHasActiveItems:
                      patternReviewInboxActiveOnRecord,
                ),
            coreCaptureCtaVisible:
                showFirstMomentCaptureCard ||
                showThreeMomentCompletionCard ||
                showSecondMomentReturnCard,
          ),
        );
    var showBetaFeedbackCaptureRecordReady =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow;
    BetaFeedbackCaptureResult? betaFeedbackCaptureRecordReadyResult =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow
        ? betaFeedbackCaptureRecordReadyPreAudit
        : null;
    final betaProofFeedbackCounts =
        FirstSessionProofRepairEngine.feedbackCountsFromStore();
    final betaProofFeedbackRowVisibleOnTimeline =
        FirstSessionProofRepairEngine.betaProofFeedbackRowVisible(
          parentVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          entryCount: _journalEntryCount,
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _journalEntries,
              ),
          isRecording: ui == RecordUiState.recording,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final proofQualityRepairInput = ProofQualityRepairVisibilityInput(
      entryCount: _journalEntryCount,
      source: 'record_ready',
      hasTimelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        _journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      usefulFeedbackCount: betaProofFeedbackCounts.useful,
      negativeFeedbackCount: betaProofFeedbackCounts.negative,
      betaProofFeedbackRowVisible: betaProofFeedbackRowVisibleOnTimeline,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    var showProofQualityRepairOnRecord =
        FirstSessionProofRepairEngine.shouldShowProof(
          input: proofQualityRepairInput,
        );
    final proofQualityRepairResult = showProofQualityRepairOnRecord
        ? FirstSessionProofRepairEngine.buildProof(
            input: proofQualityRepairInput,
          )
        : ProofQualityRepairResult.hidden;
    final proofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: _journalEntryCount,
      source: 'record_ready',
      isPro: _recordReturnProIsPro,
      hasTimelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        _journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
      hasLowMatchQuality: ProofFloorRescueEngine.resolveHasLowMatchQuality(
        entries: _journalEntries,
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        source: 'record_ready',
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      ),
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    var showProofFloorRescueOnRecord = ProofFloorRescueEngine.shouldShowCard(
      input: proofFloorRescueInput,
    );
    final proofFloorRescueResult = showProofFloorRescueOnRecord
        ? ProofFloorRescueEngine.build(input: proofFloorRescueInput)
        : ProofFloorRescueResult.hidden;
    final blocksProByProofFloorOnRecord =
        ProofFloorRescueEngine.blocksProMonetization(proofFloorRescueInput);
    if (blocksProByProofFloorOnRecord) {
      showProUnderstandingLiftOnRecordReady = false;
      showProVisibilityLiftOnRecordReady = false;
      showProBridgeVisibilityOnRecordReady = false;
      showProEvidenceValueOnRecordReady = false;
      showProEvidenceValuePrivateReportOnRecord = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      proofFloorRescueInput,
    )) {
      showBetaProofLiftOnRecordReady = false;
    }
    if (showProofFloorRescueOnRecord) {
      showProofQualityRepairOnRecord = false;
    }
    var showBetaRepairLabProofOnRecord = BetaRepairLabEngine.shouldShowProof(
      input: betaRepairLabInput,
    );
    final betaRepairLabProofResult = showBetaRepairLabProofOnRecord
        ? BetaRepairLabEngine.buildProof(input: betaRepairLabInput)
        : BetaRepairLabProofResult.hidden;
    final blocksProCardsByProofProtectionOnRecord =
        BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: showBetaRepairLabProofOnRecord,
        );
    showBetaRepairLabEvidenceTrailClarityOnRecord =
        EvidenceTrailClarityEngine.shouldShow(
          input: betaRepairLabInput,
          hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
          blocksProCards:
              blocksProByProofFloorOnRecord ||
              blocksProCardsByProofProtectionOnRecord,
        );
    final betaRepairLabEvidenceTrailClarityResult =
        showBetaRepairLabEvidenceTrailClarityOnRecord
        ? EvidenceTrailClarityEngine.build(
            input: betaRepairLabInput,
            hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
            blocksProCards:
                blocksProByProofFloorOnRecord ||
                blocksProCardsByProofProtectionOnRecord,
          )
        : EvidenceTrailClarityResult.hidden;
    if (BetaRepairLabEngine.suppressProofFloorRescueWhenProofRepairActive(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      showProofRepair: showBetaRepairLabProofOnRecord,
    )) {
      showProofFloorRescueOnRecord = false;
      showProofQualityRepairOnRecord = false;
    }
    if (BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: showBetaRepairLabProofOnRecord,
        ) ||
        BetaRepairLabEngine.blocksOtherProCardsWhenPlacementRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showProPlacement: showBetaRepairLabProPlacementOnRecord,
        ) ||
        PaywallValueRepairEngine.blocksOtherProCardsWhenPaywallValueRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPaywallValue: showBetaRepairLabPaywallValueOnRecord,
        ) ||
        PricingValueFramingEngine.blocksOtherProCardsWhenPricingValueFramingActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValueFraming: showBetaRepairLabPricingValueFramingOnRecord,
        ) ||
        PricingValidationEngine.blocksOtherProCardsWhenPricingValidationActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValidation: showBetaRepairLabPricingValidationOnRecord,
        ) ||
        EvidenceTrailClarityEngine.blocksOtherProCardsWhenEvidenceTrailClarityActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showEvidenceTrailClarity:
              showBetaRepairLabEvidenceTrailClarityOnRecord,
        )) {
      showProUnderstandingLiftOnRecordReady = false;
      showProVisibilityLiftOnRecordReady = false;
      showProBridgeVisibilityOnRecordReady = false;
      showProEvidenceValueOnRecordReady = false;
      showProEvidenceValuePrivateReportOnRecord = false;
    }
    SurfacePriorityResult? recordReadySurfacePriority;
    if (ui == RecordUiState.ready) {
      recordReadySurfacePriority = SurfacePriorityEngine.auditRecordReady(
        entryCount: _journalEntryCount,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstSessionProofRepair: showFirstSessionCaptureRepairCard,
          firstSessionLift: showFirstSessionLiftCard,
          firstSaveLift: showFirstSaveLiftCard,
          betaActivationPath:
              showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.guidance,
          betaActivationPathRevenue:
              showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.revenue,
          threeMomentCompletion: showThreeMomentCompletionCard,
          firstMomentCapture: showFirstMomentCaptureCard,
          secondMomentReturn: showSecondMomentReturnCard,
          returnAfterProofStrengthened:
              showReturnAfterProofStrengthenedOnRecordReady,
          returnAfterProofLiftV2: showReturnAfterProofLiftV2OnRecordReady,
          returnAfterProof: showReturnAfterProofGenericOnRecordReady,
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          firstRunPositioning: showFirstRunPositioningCard,
          timelineProofMoment:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          archiveTimelineSpine:
              showArchiveTimelineSpineOnRecord &&
              archiveTimelineSpineCandidate != null,
          timelinePositioning: showTimelinePositioningOnRecordReady,
          currentRelevance:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemory:
              showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          notRelevantRecovery:
              showNotRelevantRecoveryOnRecordReady &&
              notRelevantRecoveryCandidate.shouldShow,
          proofQualityResponse:
              showProofQualityResponseOnRecordReady &&
              proofQualityResponseTimelineCandidate.shouldShow,
          proofQualityRepair: showProofQualityRepairOnRecord,
          proofFloorRescue: showProofFloorRescueOnRecord,
          betaProofLift: showBetaProofLiftOnRecordReady,
          evidenceWeighting:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificity:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevance:
              showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
          patternConfidence:
              showPatternConfidenceExplanationOnRecordReady &&
              patternConfidenceExplanationCandidate != null,
          betaTesterReport: showBetaTesterReportOnRecord,
          proUnderstandingLift: showProUnderstandingLiftOnRecordReady,
          proVisibilityLift: showProVisibilityLiftOnRecordReady,
          proPreview: false,
          proBridgeVisibility: showProBridgeVisibilityOnRecordReady,
          proEvidenceValue: showProEvidenceValueOnRecordReady,
          privateReportProBridge: showProEvidenceValuePrivateReportOnRecord,
          suppressLegacyEducation: suppressLegacyEducationCardsForSpineOnRecord,
          betaFeedbackCapture: showBetaFeedbackCaptureRecordReady,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordReadySurfacePriority);
      final audit = recordReadySurfacePriority;
      showFirstSessionCaptureRepairCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionProofRepair,
        candidate: showFirstSessionCaptureRepairCard,
      );
      showFirstSessionLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionLift,
        candidate: showFirstSessionLiftCard,
      );
      showFirstSaveLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSaveLift,
        candidate: showFirstSaveLiftCard,
      );
      showFirstMomentCaptureCard = audit.isVisible(
        SurfacePriorityCardKey.firstMomentCapture,
        candidate: showFirstMomentCaptureCard,
      );
      showThreeMomentCompletionCard = audit.isVisible(
        SurfacePriorityCardKey.threeMomentCompletion,
        candidate: showThreeMomentCompletionCard,
      );
      showSecondMomentReturnCard = audit.isVisible(
        SurfacePriorityCardKey.secondMomentReturn,
        candidate: showSecondMomentReturnCard,
      );
      showReturnAfterProofStrengthenedOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
        candidate: showReturnAfterProofStrengthenedOnRecordReady,
      );
      showReturnAfterProofLiftV2OnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofLiftV2,
        candidate: showReturnAfterProofLiftV2OnRecordReady,
      );
      showReturnAfterProofGenericOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProof,
        candidate: showReturnAfterProofGenericOnRecordReady,
      );
      showReturnAfterProofOnRecordReady =
          showReturnAfterProofStrengthenedOnRecordReady ||
          showReturnAfterProofGenericOnRecordReady;
      showLowFrictionReturnCard = audit.isVisible(
        SurfacePriorityCardKey.lowFrictionReturn,
        candidate: showLowFrictionReturnCard,
      );
      showWhatToNoticeNextCard = audit.isVisible(
        SurfacePriorityCardKey.whatToNoticeNext,
        candidate: showWhatToNoticeNextCard,
      );
      showBetaTodaySummaryCard = audit.isVisible(
        SurfacePriorityCardKey.betaTodaySummary,
        candidate: showBetaTodaySummaryCard,
      );
      showOpenCapturePromptChips = audit.isVisible(
        SurfacePriorityCardKey.openCapturePromptChips,
        candidate: showOpenCapturePromptChips,
      );
      showCaptureFreedomLine = audit.isVisible(
        SurfacePriorityCardKey.captureFreedomLine,
        candidate: showCaptureFreedomLine,
      );
      showFirstRunPositioningCard = audit.isVisible(
        SurfacePriorityCardKey.firstRunPositioning,
        candidate: showFirstRunPositioningCard,
      );
      showTimelineProofMomentOnRecord = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMoment,
        candidate:
            showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
      );
      showArchiveTimelineSpineOnRecord = audit.isVisible(
        SurfacePriorityCardKey.archiveTimelineSpine,
        candidate:
            showArchiveTimelineSpineOnRecord &&
            archiveTimelineSpineCandidate != null,
      );
      showTimelinePositioningOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.timelinePositioning,
        candidate: showTimelinePositioningOnRecordReady,
      );
      showCurrentRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.currentRelevance,
        candidate:
            showCurrentRelevanceOnRecordReady &&
            currentRelevanceCandidate != null,
      );
      showCorrectionMemoryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.correctionMemory,
        candidate:
            showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
      );
      showNotRelevantRecoveryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.notRelevantRecovery,
        candidate:
            showNotRelevantRecoveryOnRecordReady &&
            notRelevantRecoveryCandidate.shouldShow,
      );
      showProofQualityResponseOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofQualityResponse,
        candidate:
            showProofQualityResponseOnRecordReady &&
            proofQualityResponseTimelineCandidate.shouldShow,
      );
      showBetaProofLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaProofLift,
        candidate: showBetaProofLiftOnRecordReady,
      );
      showEvidenceWeightingOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.evidenceWeighting,
        candidate:
            showEvidenceWeightingOnRecordReady &&
            evidenceWeightingCandidate != null,
      );
      showProofSpecificityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificity,
        candidate:
            showProofSpecificityOnRecordReady &&
            proofSpecificityCandidate.shouldShow,
      );
      showPresentDayRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.presentDayRelevance,
        candidate:
            showPresentDayRelevanceOnRecordReady &&
            presentDayRelevanceCandidate != null,
      );
      showPatternConfidenceExplanationOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.patternConfidence,
        candidate:
            showPatternConfidenceExplanationOnRecordReady &&
            patternConfidenceExplanationCandidate != null,
      );
      showBetaTesterReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.betaTesterReport,
        candidate: showBetaTesterReportOnRecord,
      );
      showProBridgeVisibilityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proBridgeVisibility,
        candidate: showProBridgeVisibilityOnRecordReady,
      );
      showProUnderstandingLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proUnderstandingLift,
        candidate: showProUnderstandingLiftOnRecordReady,
      );
      showProVisibilityLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proVisibilityLift,
        candidate: showProVisibilityLiftOnRecordReady,
      );
      showProEvidenceValueOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValueOnRecordReady,
      );
      showProEvidenceValuePrivateReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.privateReportProBridge,
        candidate: showProEvidenceValuePrivateReportOnRecord,
      );
      final recordLoosenSignals = ProBridgeTimingLoosenEngine.resolveSignals(
        entries: _journalEntries,
        source: 'record_ready',
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      );
      final recordReadyProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordReady,
        source: 'record_ready',
        entryCount: _journalEntryCount,
        isRecording: ui == RecordUiState.recording,
        isZeroEntryState: _journalEntryCount == 0,
        isFirstRecordingState:
            _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        hasFirstProof:
            firstProofPayoffSeenOnRecord ||
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
              _journalEntries,
            ),
        hasTimelineProofVisible:
            showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
        hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
        hasCorrectionMemoryVisible:
            showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
        hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
        hasReturnAfterProofStrengthenedVisible:
            showReturnAfterProofStrengthenedOnRecordReady,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: _journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
        ),
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        proSlotAvailable: true,
        confidenceLevel: recordLoosenSignals.confidenceLevel,
        hasSafeAnchor: recordLoosenSignals.hasSafeAnchor,
        hasFreshReturnAfterCorrection:
            recordLoosenSignals.hasFreshReturnAfterCorrection,
        hasSolidStrongPatternWithSafeAnchors:
            recordLoosenSignals.hasSolidStrongPatternWithSafeAnchors,
      );
      showProBridgeVisibilityOnRecordReady = ProMomentTimingEngine.applyGate(
        candidate: showProBridgeVisibilityOnRecordReady,
        timing: recordReadyProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnRecordReady &&
              !showProVisibilityLiftOnRecordReady,
        ),
      );
      showProEvidenceValueOnRecordReady = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValueOnRecordReady,
        timing: recordReadyProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnRecordReady &&
              !showProVisibilityLiftOnRecordReady &&
              !showProBridgeVisibilityOnRecordReady,
        ),
      );
      showProEvidenceValuePrivateReportOnRecord =
          ProMomentTimingEngine.applyGate(
            candidate: showProEvidenceValuePrivateReportOnRecord,
            timing: recordReadyProTiming.copyWith(
              hasMonthlyPrivateReportPreviewVisible: true,
              proSlotAvailable:
                  showProEvidenceValuePrivateReportOnRecord &&
                  !showProUnderstandingLiftOnRecordReady &&
                  !showProVisibilityLiftOnRecordReady &&
                  !showProBridgeVisibilityOnRecordReady &&
                  !showProEvidenceValueOnRecordReady,
            ),
          );
      final betaActivationPathFinalContext =
          BetaActivationPathEngine.buildContext(
            source: 'record',
            entryCount: _journalEntryCount,
            hasTimelineProof:
                showTimelineProofMomentOnRecord ||
                showArchiveTimelineSpineOnRecord,
            hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
            hasPurchaseCtaTapped: _betaActivationLoopCounts.purchaseTapped > 0,
            strongerProCardVisible:
                showProBridgeVisibilityOnRecordReady ||
                showProEvidenceValueOnRecordReady ||
                showProUnderstandingLiftOnRecordReady ||
                showProVisibilityLiftOnRecordReady,
            isReady: ui == RecordUiState.ready,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            isPermissionBlocked: ui == RecordUiState.permissionBlocked,
          );
      betaActivationPathResult = BetaActivationPathEngine.build(
        context: betaActivationPathFinalContext,
      );
      showBetaActivationPathCard = betaActivationPathResult.shouldShow;
      if (betaActivationPathResult.slot == BetaActivationPathSlot.guidance) {
        showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: showBetaActivationPathCard,
        );
      } else if (betaActivationPathResult.slot ==
          BetaActivationPathSlot.revenue) {
        showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPathRevenue,
          candidate: showBetaActivationPathCard,
        );
      } else {
        showBetaActivationPathCard = false;
      }
      showProofQualityRepairOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofQualityRepair,
        candidate: showProofQualityRepairOnRecord,
      );
      showProofFloorRescueOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofFloorRescue,
        candidate: showProofFloorRescueOnRecord,
      );
      if (showProofFloorRescueOnRecord) {
        showProofQualityRepairOnRecord = false;
      }
      if (showFirstSessionCaptureRepairCard) {
        showFirstSessionLiftCard = false;
        showFirstSaveLiftCard = false;
        showBetaActivationPathCard = false;
      } else if (showFirstSessionLiftCard) {
        showFirstSaveLiftCard = false;
        showBetaActivationPathCard = false;
      } else if (showFirstSaveLiftCard) {
        showBetaActivationPathCard = false;
      }
      if (showBetaActivationPathCard &&
          betaActivationPathResult.slot == BetaActivationPathSlot.guidance) {
        showThreeMomentCompletionCard = false;
        showFirstMomentCaptureCard = false;
        showSecondMomentReturnCard = false;
      }
      showBetaFeedbackCaptureRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: showBetaFeedbackCaptureRecordReady,
      );
      betaFeedbackCaptureRecordReadyResult = showBetaFeedbackCaptureRecordReady
          ? betaFeedbackCaptureRecordReadyPreAudit
          : null;
    }
    if (showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null) {
      ShareableProofSeenLatch.markTimelineProofMomentSeen();
    }
    if (showBetaTesterReportOnRecord) {
      ShareableProofSeenLatch.markBetaTesterReportSeen();
    }
    final shareableNonPrivateProofResult = ShareableProofEngine.build(
      input: ShareableProofVisibilityInput(
        entryCount: _journalEntryCount,
        timelineProofMomentSeen:
            ShareableProofSeenLatch.timelineProofMomentSeen,
        betaTesterReportSeen: ShareableProofSeenLatch.betaTesterReportSeen,
        isRecording: ui == RecordUiState.recording,
        isDegradedTranscript: isDegradedTranscriptOnRecord,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      ),
    );
    final showShareableNonPrivateProofOnRecord =
        shareableNonPrivateProofResult.shouldShow;
    final proofSpecificityBoostCandidate = ProofSpecificityBoostEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final timelineProofParentVisible =
        showTimelineProofMomentOnRecord && timelineProofMomentCandidate != null;
    var showProofSpecificityBoostOnTimelineProof =
        ui == RecordUiState.ready &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostCandidate,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: timelineProofParentVisible,
          timelineProofVisible: timelineProofParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showProofQualityResponseUnderTimelineProof =
        showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showProofQualityResponseUnderArchiveSpine =
        showArchiveTimelineSpineOnRecord &&
        archiveTimelineSpineCandidate != null &&
        !showProofQualityResponseUnderTimelineProof &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseSpineCandidate,
          parentVisible: true,
          timelineProofVisible: false,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showNotRelevantRecoveryUnderTimelineProof =
        showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        NotRelevantRecoveryEngine.shouldRender(
          result: notRelevantRecoveryCandidate,
          parentVisible: true,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    if (showNotRelevantRecoveryUnderTimelineProof) {
      showNotRelevantRecoveryOnRecordReady = false;
    }
    if (showProofQualityResponseUnderTimelineProof ||
        showProofQualityResponseUnderArchiveSpine) {
      showProofQualityResponseOnRecordReady = false;
      if (ProofQualityResponseEngine.coversLegacyBoost(
        result: proofQualityResponseTimelineCandidate,
        parentVisible: true,
        timelineProofVisible: showProofQualityResponseUnderTimelineProof,
        firstProofPayoffVisible: false,
        isRecording: ui == RecordUiState.recording,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      )) {
        showProofSpecificityBoostOnTimelineProof = false;
      }
      if (ProofQualityResponseEngine.coversLegacyNotRelevant(
            result: proofQualityResponseTimelineCandidate,
            parentVisible: true,
            timelineProofVisible: showProofQualityResponseUnderTimelineProof,
            firstProofPayoffVisible: false,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          ) ||
          ProofQualityResponseEngine.coversLegacyNotRelevant(
            result: proofQualityResponseSpineCandidate,
            parentVisible: true,
            timelineProofVisible: false,
            firstProofPayoffVisible: false,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          )) {
        showNotRelevantRecoveryUnderTimelineProof = false;
        showNotRelevantRecoveryOnRecordReady = false;
      }
    }
    final showBetaProofLiftUnderTimelineProof =
        showBetaProofLiftOnRecordReady &&
        showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null;
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftTimelineCandidate,
      parentVisible: timelineProofParentVisible,
      timelineProofVisible: timelineProofParentVisible,
      firstProofPayoffVisible: false,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPostSaveDegradedState: false,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    )) {
      showProofSpecificityBoostOnTimelineProof = false;
    }
    final showReturnAfterProofLiftV2BelowProofOnRecord =
        showReturnAfterProofLiftV2OnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord);
    final showReturnAfterProofLiftV2InGuidanceStack =
        showReturnAfterProofLiftV2OnRecordReady &&
        !showReturnAfterProofLiftV2BelowProofOnRecord;
    final showReturnAfterProofBelowProofOnRecord =
        showReturnAfterProofOnRecordReady &&
        !showReturnAfterProofLiftV2OnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord);
    final showReturnAfterProofInGuidanceStack =
        showReturnAfterProofOnRecordReady &&
        !showReturnAfterProofBelowProofOnRecord;
    if (firstUseSimplifiedRecord) {
      showFirstSaveLiftCard = false;
      showFirstSessionLiftCard = false;
      showFirstSessionCaptureRepairCard = false;
      showSecondMomentReturnCard = false;
      showBetaActivationPathCard = false;
      showCaptureFreedomLine = false;
      showLowFrictionReturnCard = false;
      showBetaTodaySummaryCard = false;
      showWhatToNoticeNextCard = false;
      showFirstMomentCaptureCard = false;
      showThreeMomentCompletionCard = false;
      showOpenCapturePromptChips = false;
    }
    final showProUnderstandingLiftBelowProofOnRecord =
        showProUnderstandingLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord =
        showBetaRepairLabEvidenceTrailClarityOnRecord &&
        betaRepairLabEvidenceTrailClarityResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValidationBelowProofOnRecord =
        showBetaRepairLabPricingValidationOnRecord &&
        betaRepairLabPricingValidationResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValueFramingBelowProofOnRecord =
        showBetaRepairLabPricingValueFramingOnRecord &&
        betaRepairLabPricingValueFramingResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPaywallValueBelowProofOnRecord =
        showBetaRepairLabPaywallValueOnRecord &&
        betaRepairLabPaywallValueResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabProPlacementBelowProofOnRecord =
        showBetaRepairLabProPlacementOnRecord &&
        betaRepairLabProPlacementResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    if (ArchiveBetaMissionGate.isEnabled) {
      ProPlacementTriggerAuditEngine.updateLatestInput(
        ProPlacementTriggerAuditInput(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          activeRepairMode: BetaRepairLabStore.activeMode,
          entryCount: _journalEntryCount,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
          hasMatchQuality: !ProofFloorRescueEngine.resolveHasLowMatchQuality(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record_ready',
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
          ),
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _journalEntries,
              ),
          hasTimelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          feedbackType: timelineFeedbackType,
          hasUsefulOrStrongProof:
              ProPlacementTriggerAuditEngine.hasUsefulOrStrongProof(
                feedbackType: timelineFeedbackType,
                confidenceLevel:
                    recordLoosenSignalsPreAudit.confidenceLevel ??
                    ProofConfidenceLevel.watchOnly,
              ),
          proPlacementEligible: showBetaRepairLabProPlacementOnRecord,
          proPlacementShown: showBetaRepairLabProPlacementBelowProofOnRecord,
          proPlacementBlocked:
              BetaRepairLabEngine.isRepairActive(
                BetaRepairLabMode.proPlacementAfterUsefulProof,
              ) &&
              !showBetaRepairLabProPlacementBelowProofOnRecord,
          hasProEngagement: hasProEngagementOnRecord,
          source: 'record_ready',
        ),
      );
    }
    final showProUnderstandingLiftInProSectionOnRecord =
        showProUnderstandingLiftOnRecordReady &&
        !showProUnderstandingLiftBelowProofOnRecord;
    final showProVisibilityLiftBelowProofOnRecord =
        showProVisibilityLiftOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showProVisibilityLiftInProSectionOnRecord =
        showProVisibilityLiftOnRecordReady &&
        !showProVisibilityLiftBelowProofOnRecord;
    final showProBridgeBelowProofOnRecord =
        showProBridgeVisibilityOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        !showProVisibilityLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofStrengthenedOnRecordReady);
    final showProBridgeInProSectionOnRecord =
        showProBridgeVisibilityOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        !showProVisibilityLiftOnRecordReady &&
        !showProBridgeBelowProofOnRecord;
    final proBridgeVisibilityRecordResult = showProBridgeVisibilityOnRecordReady
        ? ProBridgeVisibilityEngine.build(
            input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
              base: ProBridgeVisibilityInput(
                surface: ProBridgeVisibilitySurface.recordReady,
                source: 'record_ready',
                entryCount: _journalEntryCount,
                isPro: _recordReturnProIsPro,
                postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
                hasFirstProof:
                    firstProofPayoffSeenOnRecord ||
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      _journalEntries,
                    ),
                hasTimelineProofVisible:
                    showTimelineProofMomentOnRecord &&
                    timelineProofMomentCandidate != null,
                hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
                hasCorrectionMemoryVisible:
                    showCorrectionMemoryOnRecordReady &&
                    correctionMemoryCandidate != null,
                hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
                hasReturnAfterProofStrengthenedVisible:
                    showReturnAfterProofStrengthenedOnRecordReady,
                feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                  entries: _journalEntries,
                  surface: ProofQualityResponseSurface.timelineProofMoment,
                ),
                compact: proofSurfaceLayout.proBridgeCompact,
                hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
                hasOpenedEvidenceTrail:
                    DelayedPaywallProofStore.hasOpenedEvidenceTrail,
              ),
              entries: _journalEntries,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnRecordReady,
            ),
          )
        : null;
    final patternReviewInboxActivePostSave =
        ProofSpecificityEngine.patternReviewInboxHasActiveItems(
          entries: entriesAfterSave,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final timelineProofMomentPostSaveCandidate = entriesAfterSave.length >= 3
        ? TimelineProofMomentEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record_post_save',
            compact: true,
          )
        : null;
    var showTimelineProofMomentOnFirstProofPayoff =
        TimelineProofMomentEngine.shouldShowOnFirstProofPayoffPostSave(
          result: timelineProofMomentPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isDegradedPostSave:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    final proofSpecificityPostSaveCandidate = entriesAfterSave.length >= 3
        ? ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          )
        : ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          );
    var showProofSpecificityOnFirstProofPayoff =
        ui == RecordUiState.done &&
        showFirstProofPayoff &&
        ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
          result: proofSpecificityPostSaveCandidate,
          isPostSaveDegradedState:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    final proofSpecificityBoostPostSaveCandidate =
        ProofSpecificityBoostEngine.build(
          entries: entriesAfterSave,
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseFirstProofCandidate =
        ProofQualityResponseEngine.build(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseTimelinePostSaveCandidate =
        ProofQualityResponseEngine.build(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.timelineProofMoment,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final betaProofLiftFirstProofCandidate = BetaProofLiftEngine.build(
      entries: entriesAfterSave,
      surface: BetaProofLiftSurface.firstProofPayoff,
      source: 'record_post_save',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentPostSaveCandidate,
    );
    final betaProofLiftTimelinePostSaveCandidate = BetaProofLiftEngine.build(
      entries: entriesAfterSave,
      surface: BetaProofLiftSurface.timelineProofMoment,
      source: 'record_post_save_first_proof',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentPostSaveCandidate,
    );
    final returnAfterProofPostSaveCandidate = ReturnAfterProofEngine.build(
      entries: entriesAfterSave,
      source: 'record_post_save',
      firstProofSeen: true,
      timelineProofVisible: false,
      betaTesterReportVisible: false,
    );
    final firstProofPayoffParentVisible =
        showFirstProofPayoff && firstProofPayoffCandidate != null;
    var showProofSpecificityBoostOnFirstProofPayoff =
        ui == RecordUiState.done &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostPostSaveCandidate,
          surface: ProofSpecificityBoostSurface.firstProofPayoff,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    var showProofQualityResponseOnFirstProofPayoff =
        ui == RecordUiState.done &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (showProofQualityResponseOnFirstProofPayoff &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      showProofSpecificityBoostOnFirstProofPayoff = false;
    }
    final timelineProofPostSaveParentVisible =
        showTimelineProofMomentOnFirstProofPayoff &&
        timelineProofMomentPostSaveCandidate != null;
    var showProofSpecificityBoostOnTimelineProofPostSave =
        ui == RecordUiState.done &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostPostSaveCandidate,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    var showProofQualityResponseOnTimelineProofPostSave =
        ui == RecordUiState.done &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (showProofQualityResponseOnTimelineProofPostSave &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      showProofSpecificityBoostOnTimelineProofPostSave = false;
    }
    var showBetaProofLiftOnFirstProofPayoff =
        ui == RecordUiState.done &&
        BetaProofLiftEngine.shouldRender(
          result: betaProofLiftFirstProofCandidate,
          qualityResponse: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    var showBetaProofLiftUnderTimelineProofPostSave =
        ui == RecordUiState.done &&
        BetaProofLiftEngine.shouldRender(
          result: betaProofLiftTimelinePostSaveCandidate,
          qualityResponse: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftFirstProofCandidate,
      parentVisible: firstProofPayoffParentVisible,
      timelineProofVisible: false,
      firstProofPayoffVisible: firstProofPayoffParentVisible,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: false,
      isPostSaveDegradedState: postSaveDegraded,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    )) {
      showProofSpecificityBoostOnFirstProofPayoff = false;
    }
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftTimelinePostSaveCandidate,
      parentVisible: timelineProofPostSaveParentVisible,
      timelineProofVisible: timelineProofPostSaveParentVisible,
      firstProofPayoffVisible: false,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: false,
      isPostSaveDegradedState: postSaveDegraded,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    )) {
      showProofSpecificityBoostOnTimelineProofPostSave = false;
    }
    var showReturnAfterProofStrengthenedOnFirstProofPayoff =
        ui == RecordUiState.done &&
        ReturnAfterProofEngine.shouldShowStrengthenedOnFirstProofPayoffPostSave(
          result: returnAfterProofPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isRecording: ui == RecordUiState.recording,
          isPostSaveDegraded: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofGenericOnFirstProofPayoff =
        ui == RecordUiState.done &&
        ReturnAfterProofEngine.shouldShowGenericOnFirstProofPayoffPostSave(
          result: returnAfterProofPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isRecording: ui == RecordUiState.recording,
          isPostSaveDegraded: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofOnFirstProofPayoff =
        showReturnAfterProofStrengthenedOnFirstProofPayoff ||
        showReturnAfterProofGenericOnFirstProofPayoff;
    final returnAfterProofLiftV2PostSaveCandidate =
        ReturnAfterProofLiftV2Engine.build(
          entries: entriesAfterSave,
          source: 'record_post_save',
          firstProofSeen: true,
          timelineProofVisible:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
        );
    var showReturnAfterProofLiftV2OnPostSave =
        ReturnAfterProofLiftV2Engine.shouldShow(
          result: returnAfterProofLiftV2PostSaveCandidate,
          isReady: false,
          isRecording: ui == RecordUiState.recording,
          isPostSave: ui == RecordUiState.done,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    final postSaveLoosenSignalsPreAudit =
        ProBridgeTimingLoosenEngine.resolveSignals(
          entries: entriesAfterSave,
          source: 'record_post_save',
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final postSaveEvidenceAnchorPreAudit = EvidenceAnchorEngine.build(
      entries: entriesAfterSave,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record_post_save',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final postSaveFeedbackStateForLift =
        ProMomentTimingEngine.resolveFeedbackState(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
        );
    final hasProEngagementOnPostSave =
        _betaActivationLoopCounts.paywallSeen > 0 ||
        _betaActivationLoopCounts.purchaseTapped > 0 ||
        _betaActivationLoopCounts.proBoundarySeen > 0;
    final proUnderstandingLiftPostSaveInput =
        ProUnderstandingLiftVisibilityInput(
          surface: ProUnderstandingLiftSurface.recordPostSave,
          source: 'record_post_save',
          entryCount: postSaveEntryCount,
          isPro: _recordReturnProIsPro,
          hasUsefulProof:
              postSaveFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              postSaveLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: postSaveFeedbackStateForLift,
          hasProEngagement: hasProEngagementOnPostSave,
          hasFreshReturnAfterCorrection:
              postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    var showProUnderstandingLiftOnPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProUnderstandingLiftEngine.shouldShowCard(
          input: proUnderstandingLiftPostSaveInput,
        );
    ProUnderstandingLiftResult? proUnderstandingLiftPostSaveResult;
    if (showProUnderstandingLiftOnPostSave) {
      final base = ProUnderstandingLiftEngine.build(
        input: proUnderstandingLiftPostSaveInput,
      );
      proUnderstandingLiftPostSaveResult =
          BetaRepairLabEngine.applyProExplanationCopy(
            base: base,
            betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          ) ??
          base;
    }
    var showProVisibilityLiftOnPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: postSaveEntryCount,
          isPro: _recordReturnProIsPro,
          hasUsefulProof:
              postSaveFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              postSaveLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: postSaveFeedbackStateForLift,
          hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
          hasFreshReturnAfterCorrection:
              postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    final proVisibilityLiftPostSaveResult = showProVisibilityLiftOnPostSave
        ? ProVisibilityLiftEngine.build(
            surface: ProVisibilityLiftSurface.recordPostSave,
            source: 'record_post_save',
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            hasUsefulProof:
                postSaveFeedbackStateForLift ==
                ProofQualityFeedbackState.useful,
            confidenceLevel:
                postSaveLoosenSignalsPreAudit.confidenceLevel ??
                ProofConfidenceLevel.watchOnly,
            feedbackState: postSaveFeedbackStateForLift,
            hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
            hasFreshReturnAfterCorrection:
                postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
            hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          )
        : null;
    var showProEvidenceValuePostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
          ),
        );
    var showBetaInviteLoopPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        BetaInviteLoopEngine.shouldShowCard(
          BetaInviteLoopEngine.buildContext(
            surface: BetaInviteLoopSurface.recordPostSave,
            source: 'record_post_save',
            entryCount: postSaveEntryCount,
            entries: entriesAfterSave,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
        );
    var showProPreviewPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProPreviewEngine.shouldShowCard(
          ProPreviewEngine.buildContext(
            surface: ProPreviewSurface.recordPostSave,
            source: 'record_post_save',
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProPreviewEngine.isDismissed(),
            entries: entriesAfterSave,
            hasTimelineProofVisible:
                showTimelineProofMomentOnFirstProofPayoff &&
                timelineProofMomentPostSaveCandidate != null,
            firstProofPayoffVisible: showFirstProofPayoff,
            isPostSaveDegradedState: postSaveDegraded,
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
        );
    var showProBridgeVisibilityPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProBridgeVisibilityEngine.shouldShow(
          input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
            base: ProBridgeVisibilityInput(
              surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPro: _recordReturnProIsPro,
              postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
              hasFirstProof: true,
              isPostSaveDegradedState: postSaveDegraded,
              hasFirstProofPayoffVisible: showFirstProofPayoff,
              hasTimelineProofVisible:
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              hasBetaProofLiftVisible:
                  showBetaProofLiftOnFirstProofPayoff ||
                  showBetaProofLiftUnderTimelineProofPostSave,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnFirstProofPayoff,
              feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                entries: entriesAfterSave,
                surface: ProofQualityResponseSurface.firstProofPayoff,
              ),
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
              hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
              hasOpenedEvidenceTrail:
                  DelayedPaywallProofStore.hasOpenedEvidenceTrail,
            ),
            entries: entriesAfterSave,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
            hasBetaProofLiftVisible:
                showBetaProofLiftOnFirstProofPayoff ||
                showBetaProofLiftUnderTimelineProofPostSave,
            hasReturnAfterProofStrengthenedVisible:
                showReturnAfterProofStrengthenedOnFirstProofPayoff,
          ),
        );
    var showProLockMomentPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProBridgeVisibilityPostSave &&
        !showProEvidenceValuePostSave &&
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProLockMomentDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
          ),
        );
    final monthlyPrivateReportPreviewPostSave =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? MonthlyPrivateReportEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            isPostSave: true,
          )
        : null;
    var showMonthlyPrivateReportPreviewPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProBridgeVisibilityPostSave &&
        !showProEvidenceValuePostSave &&
        !showProLockMomentPostSave &&
        monthlyPrivateReportPreviewPostSave != null &&
        MonthlyPrivateReportEngine.shouldShowCard(
          MonthlyPrivateReportEngine.buildContext(
            surface: MonthlyPrivateReportSurface.recordPostSaveAfterProof,
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: MonthlyPrivateReportDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            preview: monthlyPrivateReportPreviewPostSave,
            isPostSaveDegradedState: postSaveDegraded,
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            proLockMomentVisible: showProLockMomentPostSave,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
            isPostSave: true,
          ),
        );
    const betaFeedbackRecordSurfaces = [
      BetaFeedbackIntelligenceSurface.afterProEvidenceSheet,
      BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
    ];
    final betaFeedbackIntelligenceSurfaceOnRecordReady =
        ui == RecordUiState.ready
        ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
            candidates: betaFeedbackRecordSurfaces,
            entryCount: _journalEntryCount,
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isZeroEntryState: _journalEntryCount == 0,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            firstProofPayoffVisible: firstProofPayoffSeenOnRecord,
          )
        : null;
    final betaFeedbackIntelligenceSurfacePostSave =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
            candidates: betaFeedbackRecordSurfaces,
            entryCount: postSaveEntryCount,
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible:
                showFirstProofPayoff && firstProofPayoffCandidate != null,
          )
        : null;
    final helpedTrackingPrompt =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? HelpedTrackingEngine.buildPrompt(
            entries: entriesAfterSave,
            isPostSaveDone: ui == RecordUiState.done,
            isDegradedPostSave:
                entriesAfterSave.isNotEmpty &&
                VoiceCaptureQuality.isDegradedVoiceCapture(
                  entriesAfterSave.last,
                ),
            showWhatChangedV2: showWhatChangedV2,
          )
        : null;
    final showHelpedTracking =
        helpedTrackingPrompt != null && !showFirstProofPayoff;
    final showReturnCheckPayoff = ReturnCheckPayoffGates.shouldShow(
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      payoff: returnCheckPayoffCandidate,
    );
    final showArchiveSummaryOnRecord =
        recordProofStack.showArchiveSummary &&
        !showFirstProofMoment &&
        !showReturnCheckPayoff &&
        !showWhatChangedV2;
    final lowEvidenceGuidance = recordProofStack.showEarlyRepeatProgress
        ? LowEvidenceEngine.buildForRecordReady(entries: _journalEntries)
        : null;
    final quietSignalCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? QuietSignalEngine.build(entries: _journalEntries)
        : null;
    final showQuietSignalOnRecord = QuietSignalGates.shouldShowOnRecordReady(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      signal: quietSignalCandidate,
      showReturnDayFlow: showReturnDayFlow,
    );
    final showLowEvidenceGuidanceOnRecord =
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        recordProofStack.showEarlyRepeatProgress &&
        lowEvidenceGuidance != null &&
        !showReturnTomorrowCueReady &&
        !showReturnDayFlow &&
        !showQuietSignalOnRecord;
    final dailyArchiveMemoryCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? DailyArchiveMemoryEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            returnChecks: RepeatReturnCheckStore.cached,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final firstProofLoopActive =
        showFirstProofPayoff || showFirstProofTruth || showFirstProofActionLoop;
    final showDailyArchiveMemory = DailyArchiveMemoryGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      memory: dailyArchiveMemoryCandidate,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCueReady: showReturnTomorrowCueReady,
      showLowEvidenceGuidance: showLowEvidenceGuidanceOnRecord,
      showWeeklyArchiveReview: showWeeklyArchiveReviewOnRecord,
      firstProofLoopActive: firstProofLoopActive,
      showComeBackTomorrowQuietSignal: showQuietSignalOnRecord,
    );
    final showReturningWatchTargetFocusedUi =
        ReturningRecordWatchTargetUiGates.showFocusedSurface(
          showDailyArchiveMemory: showDailyArchiveMemory,
          dailyArchiveMemory: dailyArchiveMemoryCandidate,
        );
    final recordReadyShowsWatchTargetOnly =
        showReturningWatchTargetFocusedUi &&
        ui == RecordUiState.ready &&
        !_isPostSaveSurface;
    final recordReadySuppressStreakPressure =
        recordReadyShowsWatchTargetOnly ||
        ReturningRecordWatchTargetUiGates.suppressDailyStreakPressureToday();
    if (showReturningWatchTargetFocusedUi) {
      showOpenCapturePromptChips = false;
      showLowFrictionReturnCard = false;
      showCaptureFreedomLine = false;
      showBetaTodaySummaryCard = false;
      showBetaActivationPathCard = false;
      showBetaTesterReportOnRecord = false;
      showBetaFeedbackCaptureRecordReady = false;
      betaFeedbackCaptureRecordReadyResult = null;
      showBetaProofLiftOnRecordReady = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      showBetaRepairLabProofOnRecord = false;
    }
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      showBetaTodaySummaryCard = false;
      showBetaActivationPathCard = false;
      showBetaTesterReportOnRecord = false;
      showBetaFeedbackCaptureRecordReady = false;
      betaFeedbackCaptureRecordReadyResult = null;
      showBetaProofLiftOnRecordReady = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      showBetaRepairLabProofOnRecord = false;
    }
    final betaTestScriptCardCandidate =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? BetaTestScriptEngine.buildCompactCard(entries: _journalEntries)
        : null;
    final showBetaTestScriptCard =
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          dismissed: BetaTestScriptStore.cached.dismissed,
          showReturnDayFlow: showReturnDayFlow,
          firstProofLoopActive: firstProofLoopActive,
          showWhatChangedV2Display: showWhatChangedV2Display,
        );
    final daysSinceLastEntry = CaptureRecoveryGates.daysSinceLastEntry(
      entries: _journalEntries,
    );
    final showReturnedAfterDelayRecovery =
        CaptureRecoveryGates.showReturnedAfterDelay(
          entryCount: _journalEntryCount,
          daysSinceLastEntry: daysSinceLastEntry,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
        );
    final nextBestActionCandidate =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? NextBestActionEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            privateReportForming:
                showPrivateArchiveReportOnRecord &&
                privateArchiveReportCandidate != null,
          )
        : null;
    final showNextBestActionOnRecord = NextBestActionGates.shouldShow(
      action: nextBestActionCandidate,
      surface: NextBestActionSurface.record,
      showEarlyRepeatProgress: recordProofStack.showEarlyRepeatProgress,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      repeatReturnCheckOfferVisible: repeatReturnCheckOffer != null,
      showPatternChangedCard:
          showPatternChanged && patternChangedCandidate != null,
      showHelpfulActionCard:
          showHelpfulActionAppearedOnRecord &&
          helpfulActionAppearedCandidate != null,
      showPrivateArchiveReportCard:
          showPrivateArchiveReportOnRecord &&
          privateArchiveReportCandidate != null,
    );
    final postSaveReturnHandoffCandidate =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? PostSaveReturnHandoffEngine.build(entries: entriesAfterSave)
        : null;
    final returnTomorrowCuePostSave =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? ReturnTomorrowCueEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final postSaveDegradedForReturnCue =
        entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final comeBackTomorrowV2PostSaveWatch =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? ComeBackTomorrowV2Engine.buildPostSaveWatch(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    var showComeBackTomorrowV2PostSave =
        !suppressNoisyFirstSaveCards &&
        ComeBackTomorrowV2Gates.shouldShowPostSave(
          isPostSaveDone: ui == RecordUiState.done,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          watch: comeBackTomorrowV2PostSaveWatch,
          showFirstProofPayoff: showFirstProofPayoff,
          showFirstProofTruth: showFirstProofTruth,
          showFirstProofActionLoop: showFirstProofActionLoop,
          showWhatChangedV2Display: showWhatChangedV2Display,
          showHelpedTracking: showHelpedTracking,
        );
    final showPostSaveCuriosityHook = CuriosityHookGates.shouldShowPostSaveCard(
      isPostSaveDone: ui == RecordUiState.done,
      hook: _postSaveCuriosityHook,
      isDegradedPostSave: postSaveDegradedForReturnCue,
    );
    final betaFeedbackCapturePostSavePreAudit =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? BetaFeedbackCaptureEngine.build(
            context: BetaFeedbackCaptureEngine.buildContext(
              surface: BetaFeedbackCaptureSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPostSave: true,
              isRecording: ui == RecordUiState.recording,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
              hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
              hasPurchaseCtaTapped:
                  _betaActivationLoopCounts.purchaseTapped > 0,
              isPro: _recordReturnProIsPro,
              timelineProofVisible:
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              proPreviewVisible: showProPreviewPostSave,
              existingProofFeedbackVisible:
                  BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                    surface: BetaProofFeedbackSurface.timelineProofMoment,
                    parentVisible:
                        showTimelineProofMomentOnFirstProofPayoff &&
                        timelineProofMomentPostSaveCandidate != null,
                    entryCount: postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          entriesAfterSave,
                        ),
                    isRecording: ui == RecordUiState.recording,
                    isPostSaveDegraded: postSaveDegraded,
                    whatChangedQuestionActive: showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        patternReviewInboxActivePostSave,
                  ) ||
                  BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                    surface: BetaProofFeedbackSurface.firstProofPayoff,
                    parentVisible:
                        showFirstProofPayoff &&
                        firstProofPayoffCandidate != null,
                    entryCount: postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          entriesAfterSave,
                        ),
                    isRecording: ui == RecordUiState.recording,
                    isPostSaveDegraded: postSaveDegraded,
                    whatChangedQuestionActive: showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        patternReviewInboxActivePostSave,
                  ),
            ),
          )
        : BetaFeedbackCaptureResult.hidden;
    var showBetaFeedbackCapturePostSave =
        betaFeedbackCapturePostSavePreAudit.shouldShow;
    BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveResult =
        betaFeedbackCapturePostSavePreAudit.shouldShow
        ? betaFeedbackCapturePostSavePreAudit
        : null;
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      showBetaProofLiftOnFirstProofPayoff = false;
      showBetaProofLiftUnderTimelineProofPostSave = false;
      showBetaInviteLoopPostSave = false;
      showBetaFeedbackCapturePostSave = false;
      betaFeedbackCapturePostSaveResult = null;
    }
    final postSaveProofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: postSaveEntryCount,
      source: 'record_post_save',
      isPro: _recordReturnProIsPro,
      hasTimelineProofVisible:
          showTimelineProofMomentOnFirstProofPayoff &&
          timelineProofMomentPostSaveCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entriesAfterSave,
      ),
      confidenceLevel:
          postSaveLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: postSaveLoosenSignalsPreAudit.hasSafeAnchor,
      hasLowMatchQuality: ProofFloorRescueEngine.resolveHasLowMatchQuality(
        entries: entriesAfterSave,
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        source: 'record_post_save',
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      ),
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: false,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    );
    final blocksProByProofFloorOnPostSave =
        ProofFloorRescueEngine.blocksProMonetization(
          postSaveProofFloorRescueInput,
        );
    if (blocksProByProofFloorOnPostSave) {
      showProUnderstandingLiftOnPostSave = false;
      showProVisibilityLiftOnPostSave = false;
      showProPreviewPostSave = false;
      showProBridgeVisibilityPostSave = false;
      showProEvidenceValuePostSave = false;
      showProLockMomentPostSave = false;
      showMonthlyPrivateReportPreviewPostSave = false;
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      postSaveProofFloorRescueInput,
    )) {
      showBetaProofLiftOnFirstProofPayoff = false;
      showBetaProofLiftUnderTimelineProofPostSave = false;
    }
    SurfacePriorityResult? recordPostSaveSurfacePriority;
    if (ui == RecordUiState.done) {
      recordPostSaveSurfacePriority = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: postSaveEntryCount,
        source: 'record_post_save',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          firstProofPayoff:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          whatChanged: showWhatChangedV2 || showWhatChangedV2Display,
          returnPayoff: showComeBackTomorrowV2PostSave,
          timelineProofMomentPostSave:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proofSpecificityPostSave:
              showProofSpecificityOnFirstProofPayoff &&
              proofSpecificityPostSaveCandidate.shouldShow,
          betaProofFeedback:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          betaInviteLoop: showBetaInviteLoopPostSave,
          betaProofLift:
              showBetaProofLiftOnFirstProofPayoff ||
              showBetaProofLiftUnderTimelineProofPostSave,
          returnAfterProofStrengthened:
              showReturnAfterProofStrengthenedOnFirstProofPayoff,
          returnAfterProofLiftV2: showReturnAfterProofLiftV2OnPostSave,
          returnAfterProof: showReturnAfterProofGenericOnFirstProofPayoff,
          proofFloorRescue: blocksProByProofFloorOnPostSave,
          proPreview: showProPreviewPostSave,
          proUnderstandingLift: showProUnderstandingLiftOnPostSave,
          proVisibilityLift: showProVisibilityLiftOnPostSave,
          proBridgeVisibility: showProBridgeVisibilityPostSave,
          proEvidenceValue: showProEvidenceValuePostSave,
          proLockMoment: showProLockMomentPostSave,
          privateReportProBridge: showMonthlyPrivateReportPreviewPostSave,
          betaFeedbackCapture: showBetaFeedbackCapturePostSave,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordPostSaveSurfacePriority);
      final audit = recordPostSaveSurfacePriority;
      if (audit.isVisible(
        SurfacePriorityCardKey.whatChanged,
        candidate: showWhatChangedV2 || showWhatChangedV2Display,
      )) {
        showFirstProofPayoff = false;
      }
      showTimelineProofMomentOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMomentPostSave,
        candidate:
            showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
      );
      showProofSpecificityOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificityPostSave,
        candidate:
            showProofSpecificityOnFirstProofPayoff &&
            proofSpecificityPostSaveCandidate.shouldShow,
      );
      showReturnAfterProofStrengthenedOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
        candidate:
            showReturnAfterProofStrengthenedOnFirstProofPayoff &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      showReturnAfterProofGenericOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProof,
        candidate:
            showReturnAfterProofGenericOnFirstProofPayoff &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      showReturnAfterProofOnFirstProofPayoff =
          showReturnAfterProofStrengthenedOnFirstProofPayoff ||
          showReturnAfterProofGenericOnFirstProofPayoff;
      showReturnAfterProofLiftV2OnPostSave = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofLiftV2,
        candidate:
            showReturnAfterProofLiftV2OnPostSave &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      if (showReturnAfterProofLiftV2OnPostSave) {
        showReturnAfterProofStrengthenedOnFirstProofPayoff = false;
        showReturnAfterProofGenericOnFirstProofPayoff = false;
        showReturnAfterProofOnFirstProofPayoff = false;
      }
      showProPreviewPostSave = audit.isVisible(
        SurfacePriorityCardKey.proPreview,
        candidate: showProPreviewPostSave,
      );
      showBetaInviteLoopPostSave = audit.isVisible(
        SurfacePriorityCardKey.betaInviteLoop,
        candidate: showBetaInviteLoopPostSave,
      );
      showProBridgeVisibilityPostSave = audit.isVisible(
        SurfacePriorityCardKey.proBridgeVisibility,
        candidate: showProBridgeVisibilityPostSave,
      );
      showProUnderstandingLiftOnPostSave = audit.isVisible(
        SurfacePriorityCardKey.proUnderstandingLift,
        candidate: showProUnderstandingLiftOnPostSave,
      );
      showProVisibilityLiftOnPostSave = audit.isVisible(
        SurfacePriorityCardKey.proVisibilityLift,
        candidate: showProVisibilityLiftOnPostSave,
      );
      showProEvidenceValuePostSave = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValuePostSave,
      );
      showProLockMomentPostSave = audit.isVisible(
        SurfacePriorityCardKey.proLockMoment,
        candidate: showProLockMomentPostSave,
      );
      showBetaFeedbackCapturePostSave = audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: showBetaFeedbackCapturePostSave,
      );
      betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
          ? betaFeedbackCapturePostSavePreAudit
          : null;
      final postSaveLoosenSignals = ProBridgeTimingLoosenEngine.resolveSignals(
        entries: entriesAfterSave,
        source: 'record_post_save',
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      );
      final postSaveProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordPostSave,
        source: 'record_post_save',
        entryCount: postSaveEntryCount,
        isPostSaveDegradedState: postSaveDegraded,
        hasFirstProof:
            showFirstProofPayoff && firstProofPayoffCandidate != null,
        hasTimelineProofVisible:
            showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
        hasFirstProofPayoffVisible: showFirstProofPayoff,
        hasMonthlyPrivateReportPreviewVisible:
            showMonthlyPrivateReportPreviewPostSave,
        hasBetaProofLiftVisible:
            showBetaProofLiftOnFirstProofPayoff ||
            showBetaProofLiftUnderTimelineProofPostSave,
        hasReturnAfterProofStrengthenedVisible:
            showReturnAfterProofStrengthenedOnFirstProofPayoff,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
        ),
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        proSlotAvailable: true,
        confidenceLevel: postSaveLoosenSignals.confidenceLevel,
        hasSafeAnchor: postSaveLoosenSignals.hasSafeAnchor,
        hasFreshReturnAfterCorrection:
            postSaveLoosenSignals.hasFreshReturnAfterCorrection,
        hasSolidStrongPatternWithSafeAnchors:
            postSaveLoosenSignals.hasSolidStrongPatternWithSafeAnchors,
      );
      showProPreviewPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProPreviewPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave,
        ),
      );
      showProBridgeVisibilityPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProBridgeVisibilityPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave,
        ),
      );
      showProEvidenceValuePostSave = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValuePostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
      showProLockMomentPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProLockMomentPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              showProLockMomentPostSave &&
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
      showMonthlyPrivateReportPreviewPostSave = ProMomentTimingEngine.applyGate(
        candidate: showMonthlyPrivateReportPreviewPostSave,
        timing: postSaveProTiming.copyWith(
          hasMonthlyPrivateReportPreviewVisible: true,
          proSlotAvailable:
              showMonthlyPrivateReportPreviewPostSave &&
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
      final betaFeedbackCapturePostSaveFinal = BetaFeedbackCaptureEngine.build(
        context: BetaFeedbackCaptureEngine.buildContext(
          surface: BetaFeedbackCaptureSurface.recordPostSave,
          source: 'record_post_save',
          entryCount: postSaveEntryCount,
          isPostSave: true,
          isRecording: ui == RecordUiState.recording,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          hasPaywallSeen: _betaActivationLoopCounts.paywallSeen > 0,
          hasPurchaseCtaTapped: _betaActivationLoopCounts.purchaseTapped > 0,
          isPro: _recordReturnProIsPro,
          timelineProofVisible:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proPreviewVisible: showProPreviewPostSave,
          existingProofFeedbackVisible:
              BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                surface: BetaProofFeedbackSurface.timelineProofMoment,
                parentVisible:
                    showTimelineProofMomentOnFirstProofPayoff &&
                    timelineProofMomentPostSaveCandidate != null,
                entryCount: postSaveEntryCount,
                hasConfirmedRepeat:
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      entriesAfterSave,
                    ),
                isRecording: ui == RecordUiState.recording,
                isPostSaveDegraded: postSaveDegraded,
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
              ) ||
              BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                surface: BetaProofFeedbackSurface.firstProofPayoff,
                parentVisible:
                    showFirstProofPayoff && firstProofPayoffCandidate != null,
                entryCount: postSaveEntryCount,
                hasConfirmedRepeat:
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      entriesAfterSave,
                    ),
                isRecording: ui == RecordUiState.recording,
                isPostSaveDegraded: postSaveDegraded,
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
              ),
        ),
      );
      showBetaFeedbackCapturePostSave =
          showBetaFeedbackCapturePostSave &&
          betaFeedbackCapturePostSaveFinal.shouldShow;
      betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
          ? betaFeedbackCapturePostSaveFinal
          : null;
    }
    final proPreviewPostSaveResult = showProPreviewPostSave
        ? ProPreviewEngine.build(
            context: ProPreviewEngine.buildContext(
              surface: ProPreviewSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPro: _recordReturnProIsPro,
              dismissed: ProPreviewEngine.isDismissed(),
              entries: entriesAfterSave,
              hasTimelineProofVisible:
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              firstProofPayoffVisible: showFirstProofPayoff,
              isPostSaveDegradedState: postSaveDegraded,
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          )
        : null;
    final betaInviteLoopPostSaveResult = showBetaInviteLoopPostSave
        ? BetaInviteLoopEngine.build(
            context: BetaInviteLoopEngine.buildContext(
              surface: BetaInviteLoopSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          )
        : null;
    final proBridgeVisibilityPostSaveResult = showProBridgeVisibilityPostSave
        ? ProBridgeVisibilityEngine.build(
            input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
              base: ProBridgeVisibilityInput(
                surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
                source: 'record_post_save',
                entryCount: postSaveEntryCount,
                isPro: _recordReturnProIsPro,
                postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
                hasFirstProof: true,
                isPostSaveDegradedState: postSaveDegraded,
                hasFirstProofPayoffVisible: showFirstProofPayoff,
                hasTimelineProofVisible:
                    showTimelineProofMomentOnFirstProofPayoff &&
                    timelineProofMomentPostSaveCandidate != null,
                hasBetaProofLiftVisible:
                    showBetaProofLiftOnFirstProofPayoff ||
                    showBetaProofLiftUnderTimelineProofPostSave,
                hasReturnAfterProofStrengthenedVisible:
                    showReturnAfterProofStrengthenedOnFirstProofPayoff,
                feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                  entries: entriesAfterSave,
                  surface: ProofQualityResponseSurface.firstProofPayoff,
                ),
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
                hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
                hasOpenedEvidenceTrail:
                    DelayedPaywallProofStore.hasOpenedEvidenceTrail,
              ),
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              hasBetaProofLiftVisible:
                  showBetaProofLiftOnFirstProofPayoff ||
                  showBetaProofLiftUnderTimelineProofPostSave,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnFirstProofPayoff,
            ),
          )
        : null;
    final showReturnTomorrowCuePostSave =
        !suppressNoisyFirstSaveCards &&
        !showFirstProofPayoff &&
        !showComeBackTomorrowV2PostSave &&
        ReturnTomorrowCueGates.shouldShowPostSave(
          isPostSaveDone: ui == RecordUiState.done,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          cue: returnTomorrowCuePostSave,
        );
    final firstWeekProgressPostSave =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? FirstWeekProgressEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final showFirstWeekProgressPostSave =
        FirstWeekProgressGates.shouldShowPostSave(
          isPostSaveDone: ui == RecordUiState.done,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          progress: firstWeekProgressPostSave,
          showReturnTomorrowCue: showReturnTomorrowCuePostSave,
        );
    final showPostSaveReturnHandoff =
        !suppressNoisyFirstSaveCards &&
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: ui == RecordUiState.done,
          entryCount: postSaveEntryCount,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          handoff: postSaveReturnHandoffCandidate,
        ) &&
        !showReturnTomorrowCuePostSave &&
        !showComeBackTomorrowV2PostSave;
    final beliefUpdatePayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? BeliefUpdatePayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final journalShareProof =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? const ShareableArchiveProofEngine().buildFromJournal(
            entries: entriesAfterSave,
          )
        : null;
    final shareableProof = journalShareProof?.hasProof == true
        ? journalShareProof
        : _shareableProof;
    final returnLoopPayoff =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight &&
            thirdEntryBeliefPayoff == null &&
            beliefUpdatePayoff == null
        ? DayTwoReturnLoopPayoffEngine.build(
            entries: entriesAfterSave,
            reminderAvailable: _offerDayTwoReminder && !_recordReturnCueVisible,
          )
        : null;
    final postSaveDailyMirror =
        ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? const DailyMirrorEngine().build(entriesAfterSave)
        : null;
    final postSaveArchiveHierarchy =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
        ? PostSaveArchiveHierarchy.resolve(
            entries: entriesAfterSave,
            suppressLatestSaveArchiveInsight: suppressLatestSaveArchiveInsight,
            beliefUpdatePayoff: beliefUpdatePayoff,
            mirror: postSaveDailyMirror,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final suppressNoisyRepeatPostSaveCards =
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: suppressNoisyFirstSaveCards,
          showFirstProofMoment: showFirstProofMoment,
          postSaveArchiveKind: postSaveArchiveHierarchy?.kind,
          mirror: postSaveDailyMirror,
        );
    final repeatPostSaveThoughtMapPreview = suppressNoisyRepeatPostSaveCards
        ? const ArchiveThoughtMapEngine().build(entriesAfterSave)
        : null;
    if (suppressNoisyRepeatPostSaveCards) {
      showComeBackTomorrowV2PostSave = false;
    }
    final showDegradedTranscriptFocusedPostSave =
        ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        DegradedTranscriptPostSaveUiGates.showFocusedRecoverySurface(
          isDegradedPostSave: _lastSavedEntryIsDegraded,
        );
    final suppressDegradedTranscriptPostSaveCompetitors =
        DegradedTranscriptPostSaveUiGates.suppressCompetingPostSaveCards(
          showFocusedRecoverySurface: showDegradedTranscriptFocusedPostSave,
        );
    final returningUserToday =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? ReturningUserTodayEngine.build(entries: _journalEntries)
        : null;
    final nextMomentPrompt =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? NextMomentPromptEngine.build(entries: _journalEntries)
        : null;
    final dailyArchiveExercise =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !ScreenshotMode.enabled
        ? const DailyArchiveExerciseEngine().buildFromJournal(
            entries: _journalEntries,
            hasWatchTheme: _hasWatchTheme,
            betaFeedbackCaptured: _betaFeedbackCaptured,
          )
        : null;
    final todaysOneQuestion =
        ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !ScreenshotMode.enabled
        ? const TodaysQuestionEngine().buildFromJournal(
            entries: _journalEntries,
            hasWatchTheme: _hasWatchTheme,
            betaFeedbackCaptured: _betaFeedbackCaptured,
            weeklyReviewAvailable: WeeklyArchiveReviewEngine.build(
              entries: _journalEntries,
            ).hasEnoughEvidence,
          )
        : null;
    final recordHomeSurface =
        ui == RecordUiState.ready && _journalEntryCountReady
        ? RecordHomeSurfacePolicy.resolve(
            isReady: true,
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
            screenshotMode: ScreenshotMode.enabled,
            dailyArchiveExercise: dailyArchiveExercise,
            returningUserToday: returningUserToday,
            todaysOneQuestion: todaysOneQuestion,
            hasStartHereSuggestion: _dailyReturnSuggestions.hasSuggestions,
          )
        : const RecordHomeSurfacePolicy();
    final showArchiveProgressCards = ui == RecordUiState.ready
        ? recordHomeSurface.showArchiveProgressCards &&
              !showEarlyEvidenceTimeline
        : _canShowArchiveProgressCards;

    _logRecordEmptyGate('build');
    _maybeLogRecordCtaPolicy(
      _recordCtaPolicy(
        ui,
        micPhase: policyMic,
        userDeniedThisSession: policyUserDenied,
      ),
    );

    final readyCapturePolicy = _recordCtaPolicy(
      ui,
      micPhase: policyMic,
      userDeniedThisSession: policyUserDenied,
    );
    final showTesterMission =
        TesterMissionGates.shouldShow(
          dismissed: TesterMissionStore.isDismissed,
          ui: ui,
          entryCountLoaded: _journalEntryCountReady,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
        ) &&
        !firstUseSimplifiedRecord &&
        !showReturningWatchTargetFocusedUi;
    final testerMissionCompact =
        showTesterMission &&
        TesterMissionGates.useCompactPresentation(
          entryCount: _journalEntryCount,
          firstUseSimplifiedRecord: firstUseSimplifiedRecord,
        );
    final showTesterMissionFull = showTesterMission && !testerMissionCompact;
    final testerMission = showTesterMission
        ? TesterMissionEngine.build(
            entryCount: _journalEntryCount,
            entries: _journalEntries,
            compactAtEntryZero: firstUseSimplifiedRecord,
            feedbackAnswered: CoreValueFeedbackStore.cached.answered,
          )
        : null;
    final showThoughtMapRecordCta =
        showConfirmedRepeatThoughtMapOnRecord &&
        confirmedRepeatThoughtMap?.firstMissingSection != null &&
        ConfirmedRepeatThoughtMapGates.showRecordMissingPieceCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
        );
    final showPositiveReinforcementRecordCta =
        showPositiveReinforcementOnRecord &&
        positiveReinforcement != null &&
        PositiveReinforcementGates.showRecordAgainCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
          isCompletion: positiveReinforcement.isCompletion,
        );
    final showPatternChangedRecordCta =
        showPatternChanged &&
        patternChangedCandidate != null &&
        PatternChangedGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
        );
    final showArchiveSummaryRecordCta =
        showArchiveSummaryOnRecord &&
        ArchiveSummaryGates.showRecordNextCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
        );
    final showDailyReturnReasonRecordCta =
        showDailyReturnReasonOnRecord &&
        DailyReturnReasonGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
        );
    final showFirstWeekLoopRecordCta =
        showFirstWeekLoopOnRecord &&
        firstWeekLoopCandidate != null &&
        FirstWeekLoopGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions: _shouldPromoteMicCaptureActions(
            readyCapturePolicy,
          ),
        );

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showFirstSessionOnboarding =
        showFraming &&
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !showReturningWatchTargetFocusedUi &&
        FirstSessionOnboardingStore.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isPostSave: _isPostSaveSurface,
        );
    final showFirstUseWordingHelper =
        ui == RecordUiState.ready &&
        FirstUseWordingGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: true,
          isPostSave: _isPostSaveSurface,
          isRecordCluttered: _isPostSaveSurface,
        );
    final showCloseButton = RecordScreenCloseButton.shouldShow(context);
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  key: const Key('record_screen_scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    firstUseSimplifiedRecord ? 0 : 8,
                    24,
                    (compact ? 12 : 16) + bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: firstUseSimplifiedRecord
                          ? 0
                          : constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (kDebugMode)
                          SizedBox(
                            key: ValueKey(
                              'record_empty_gate_${_journalEntryCount}_'
                              '$_journalEntryCountLoaded',
                            ),
                            width: 0,
                            height: 0,
                          ),
                        if (firstUseSimplifiedRecord &&
                            ui == RecordUiState.ready &&
                            _journalEntryCountReady) ...[
                          RecordFirstRunScreenCard(
                            onRecord: () =>
                                unawaited(_onRecordPressed(source: 'main')),
                            recordButtonLabel: _recordEntryCtaLabel(
                              readyCapturePolicy,
                            ),
                            onTextThoughtSaved: _finishSuccessfulCapture,
                          ),
                        ] else if (showFirstSessionOnboarding) ...[
                          FirstSessionOnboardingCard(
                            onStartMoment: () =>
                                unawaited(_onRecordPressed(source: 'main')),
                            onExploreFirst: () =>
                                unawaited(_dismissFirstSessionOnboarding()),
                          ),
                          const SizedBox(height: 16),
                        ] else if (showFraming &&
                            ui == RecordUiState.ready &&
                            _journalEntryCountReady &&
                            _journalEntryCount == 0) ...[
                          const RecordTopArchivePromiseHero(),
                          const SizedBox(height: 16),
                        ],
                        if (showTesterMissionFull &&
                            testerMission != null &&
                            !showReturningWatchTargetFocusedUi) ...[
                          TesterMissionCard(
                            mission: testerMission,
                            onDismissed: () => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (recordHomeSurface.showDailyMapPrompt &&
                            dailyArchiveExercise != null &&
                            !showReturningWatchTargetFocusedUi) ...[
                          DailyArchiveExerciseRecordCard(
                            exercise: dailyArchiveExercise,
                            onPrimary: () => _handleDailyArchiveExerciseAction(
                              dailyArchiveExercise.primaryRoute,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (showReturningWatchTargetFocusedUi &&
                            dailyArchiveMemoryCandidate != null) ...[
                          DailyArchiveMemoryCard(
                            memory: dailyArchiveMemoryCandidate,
                            entryCount: _journalEntryCount,
                            source: 'record',
                            showFocusedCaptureActions: true,
                            onRecord: () => unawaited(
                              _onRecordPressed(source: 'daily_archive_memory'),
                            ),
                            onTypeInstead: () => unawaited(
                              navigateToTypeInsteadCapture(
                                context,
                                onSaved: _finishSuccessfulCapture,
                              ),
                            ),
                            onNotToday: () =>
                                unawaited(_dismissReturningWatchTargetPrompt()),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (showReturningWatchTargetFocusedUi &&
                            _journalEntryCountReady &&
                            ReturningRecordWatchTargetUiGates.showProUpgradePromptOnReturn(
                              entryCount: _journalEntryCount,
                            ) &&
                            showProBridgeBelowProofOnRecord &&
                            proBridgeVisibilityRecordResult != null) ...[
                          ProBridgeVisibilityCard(
                            result: proBridgeVisibilityRecordResult,
                            onSeePro: () => _openProEvidenceValueSubscription(
                              analyticsSource: 'record_return_watch_pro_bridge',
                            ),
                            onDismiss: () =>
                                unawaited(_dismissProEvidenceValueBridge()),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (RecordEmptyArchiveGates.showArchiveEducationStackOnRecord(
                              loaded: _journalEntryCountReady,
                              entryCount: _journalEntryCount,
                            ) &&
                            !ReturningRecordWatchTargetUiGates.suppressArchiveEducationStack(
                              showFocusedSurface:
                                  showReturningWatchTargetFocusedUi,
                            )) ...[
                          if (ui == RecordUiState.ready &&
                              _journalEntryCountReady &&
                              _journalEntryCount == 0 &&
                              _showFirstRunPrivacyReassurance &&
                              !firstUseSimplifiedRecord) ...[
                            const RecordFirstRunPrivacyReassurance(),
                            const SizedBox(height: 12),
                          ],
                          if (showFraming &&
                              stack.showFramingTitle &&
                              !showReturningWatchTargetFocusedUi &&
                              !ReturningRecordWatchTargetUiGates.suppressDailyStreakPressureToday()) ...[
                            Text(
                              RecordScreenFramingCopy.title,
                              key: const Key('record_screen_framing_title'),
                              style: ArchiveMobileTypography.recordPageTitle(
                                context,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              RecordScreenFramingCopy.guidance,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: VoiceMemoryColors.textSecondary,
                                    fontSize:
                                        ArchiveMobileTypography.responsiveBody(
                                          context,
                                        ).fontSize,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (recordHomeSurface.showReturningUserToday &&
                              returningUserToday != null &&
                              !showReturningWatchTargetFocusedUi) ...[
                            ReturningUserTodayCard(
                              model: returningUserToday,
                              onPrimary: () => _handleReturningUserTodayAction(
                                returningUserToday.primaryAction,
                              ),
                              onSecondary: () =>
                                  _handleReturningUserTodayAction(
                                    returningUserToday.secondaryAction,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (recordHomeSurface.showNextMomentPrompt &&
                              nextMomentPrompt != null &&
                              !showReturningWatchTargetFocusedUi) ...[
                            NextMomentPromptCard(
                              prompt: nextMomentPrompt,
                              onPrimary: () => _handleNextMomentPromptAction(
                                nextMomentPrompt.primaryAction,
                              ),
                              onSecondary: nextMomentPrompt.secondaryCta != null
                                  ? () => _handleNextMomentPromptAction(
                                      nextMomentPrompt.secondaryAction,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (recordHomeSurface.showTodaysOneQuestion &&
                              todaysOneQuestion != null &&
                              !showReturningWatchTargetFocusedUi) ...[
                            TodaysOneQuestionCard(
                              question: todaysOneQuestion,
                              onPrimary: () => _handleTodaysOneQuestionAction(
                                todaysOneQuestion,
                              ),
                              onViewFull: _openTodaysOneQuestionScreen,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showFirstUseWordingHelper &&
                              !firstUseSimplifiedRecord) ...[
                            FirstUseWordingHelperCard(
                              onUseOpening: (prompt) => unawaited(
                                _openFirstUseWordingOpening(prompt),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (ui == RecordUiState.ready &&
                              !firstUseSimplifiedRecord) ...[
                            if (ArchiveJourneyExplainerGates.showFirstProofJourneyStripOnRecord(
                                  loaded: _journalEntryCountReady,
                                  entryCount: _journalEntryCount,
                                  isPostSave: _isPostSaveSurface,
                                  entries: _journalEntries,
                                ) &&
                                !recordReadySuppressStreakPressure) ...[
                              const FirstProofJourneyStripCard(),
                              const SizedBox(height: 12),
                            ],
                            if (!showReturningWatchTargetFocusedUi)
                              Builder(
                                builder: (context) {
                                  final readyPolicy = readyCapturePolicy;
                                  if (!_shouldPromoteMicCaptureActions(
                                    readyPolicy,
                                  )) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildCaptureEntryActions(
                                        context: context,
                                        selectedPrompt: _selectedPromptLine,
                                        policy: readyPolicy,
                                        suppressLogPressureMoment:
                                            showReturningWatchTargetFocusedUi,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                },
                              ),
                          ],
                          if (ui == RecordUiState.ready &&
                              RecordCaptureModeEngine.shouldShow(
                                loaded: _journalEntryCountReady,
                                isReady: true,
                                isPostSave: _isPostSaveSurface,
                              ) &&
                              !firstUseSimplifiedRecord &&
                              !showReturningWatchTargetFocusedUi) ...[
                            RecordCaptureModesCard(
                              onModeTap: (mode) =>
                                  unawaited(_openCaptureMode(mode)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (recordReadySurfacePriority != null) ...[
                            SurfacePriorityDebugBadge(
                              result: recordReadySurfacePriority,
                            ),
                          ],
                          if (showFirstSessionCaptureRepairCard &&
                              !firstUseSimplifiedRecord) ...[
                            FirstSessionCaptureRepairCard(
                              result: firstSessionCaptureRepairCandidate,
                              onTypeOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: firstSessionCaptureRepairCandidate
                                      .typedCapturePrompt,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onUseVoice: () => unawaited(
                                _onRecordPressed(
                                  source: 'first_session_capture_repair',
                                ),
                              ),
                              onChipSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                                unawaited(
                                  navigateToTypeInsteadCapture(
                                    context,
                                    prompt: prompt,
                                    onSaved: _finishSuccessfulCapture,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showFirstSessionLiftCard &&
                              !firstUseSimplifiedRecord) ...[
                            FirstSessionLiftCard(
                              result: firstSessionLiftCandidate,
                              onTypeOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onUseVoiceInstead: () => unawaited(
                                _onRecordPressed(source: 'first_session_lift'),
                              ),
                              onChipSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                                unawaited(
                                  navigateToTypeInsteadCapture(
                                    context,
                                    prompt: prompt,
                                    onSaved: _finishSuccessfulCapture,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showFirstSaveLiftCard &&
                              !firstUseSimplifiedRecord) ...[
                            FirstSaveLiftCard(
                              result: firstSaveLiftCandidate,
                              onTypeOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onRecordInstead: () => unawaited(
                                _onRecordPressed(source: 'first_save_lift'),
                              ),
                              onExampleSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                                unawaited(
                                  navigateToTypeInsteadCapture(
                                    context,
                                    prompt: prompt,
                                    onSaved: _finishSuccessfulCapture,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showBetaActivationPathCard &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                              betaActivationPathResult != null &&
                              !firstUseSimplifiedRecord) ...[
                            BetaActivationPathCard(
                              result: betaActivationPathResult,
                              onPrimaryCta: () =>
                                  _handleBetaActivationPathPrimaryCta(
                                    betaActivationPathResult!,
                                  ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showThreeMomentCompletionCard &&
                              !firstUseSimplifiedRecord) ...[
                            ThreeMomentCompletionCard(
                              result: threeMomentCompletionCandidate,
                              onPrimaryCta: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showSecondMomentReturnCard &&
                              !firstUseSimplifiedRecord) ...[
                            SecondMomentReturnCard(
                              result: secondMomentReturnCandidate,
                              onNoticedSomething: () {
                                setState(() {});
                              },
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                              onSaveOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showFirstMomentCaptureCard &&
                              !firstUseSimplifiedRecord) ...[
                            FirstMomentCaptureCard(
                              result: firstMomentCaptureCandidate,
                              onSaveOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onRecordInstead: () => unawaited(
                                _onRecordPressed(
                                  source: 'first_moment_capture',
                                ),
                              ),
                              onExampleSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showFirstRunPositioningCard &&
                              !firstUseSimplifiedRecord) ...[
                            FirstRunPositioningCard(
                              result: firstRunPositioningCandidate,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showOpenCapturePromptChips &&
                              !firstUseSimplifiedRecord &&
                              !showReturningWatchTargetFocusedUi) ...[
                            OpenCapturePromptChips(
                              source: 'record',
                              entryCount: _journalEntryCount,
                              onChipTap: (chip) {
                                setState(
                                  () =>
                                      _selectedPromptLine = chip.promptStarter,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showReturnAfterProofLiftV2InGuidanceStack &&
                              !firstUseSimplifiedRecord) ...[
                            ReturnAfterProofLiftV2Card(
                              result: returnAfterProofLiftV2Candidate,
                              onPrimaryCta: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showReturnAfterProofInGuidanceStack &&
                              !firstUseSimplifiedRecord) ...[
                            ReturnAfterProofCard(
                              result: returnAfterProofRecordCandidate,
                              useStrengthenedLayout:
                                  showReturnAfterProofStrengthenedOnRecordReady,
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showLowFrictionReturnCard &&
                              !firstUseSimplifiedRecord &&
                              !showReturningWatchTargetFocusedUi &&
                              !ReturningRecordWatchTargetUiGates.watchPromptSkippedToday()) ...[
                            LowFrictionReturnCard(
                              source: 'record',
                              entryCount: _journalEntryCount,
                              onSaveOneSentence: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showBetaTodaySummaryCard &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                              !firstUseSimplifiedRecord) ...[
                            BetaTodaySummaryCard(
                              result: betaTodaySummaryCandidate,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showWhatToNoticeNextCard &&
                              !firstUseSimplifiedRecord &&
                              !recordReadySuppressStreakPressure) ...[
                            WhatToNoticeNextCard(
                              result: whatToNoticeNextCandidate,
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showCaptureFreedomLine &&
                              !firstUseSimplifiedRecord &&
                              !showReturningWatchTargetFocusedUi) ...[
                            CaptureFreedomLine(
                              source: 'record',
                              entryCount: _journalEntryCount,
                              compact: _journalEntryCount > 0,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showTimelinePositioningOnRecordReady &&
                              !firstUseSimplifiedRecord) ...[
                            TimelinePositioningCard(
                              result: timelinePositioningCandidate,
                              source: 'record',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showThreeDayChallengeOnRecord &&
                              threeDayChallengeCandidate != null &&
                              !firstUseSimplifiedRecord &&
                              !recordReadySuppressStreakPressure) ...[
                            ThreeDayChallengeCard(
                              challenge: threeDayChallengeCandidate,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (ui == RecordUiState.ready &&
                              showNextBestActionOnRecord &&
                              nextBestActionCandidate != null &&
                              !firstUseSimplifiedRecord &&
                              !showReturningWatchTargetFocusedUi) ...[
                            NextBestActionLine(
                              action: nextBestActionCandidate,
                              surface: NextBestActionSurface.record,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (ui == RecordUiState.ready &&
                              recordHomeSurface.showStartHereTodayPrompt &&
                              _dailyReturnSuggestions.hasSuggestions &&
                              !recordReadySuppressStreakPressure) ...[
                            DailyReturnSuggestionsCard(
                              startHereOnly: true,
                              suggestionSet: _dailyReturnSuggestions,
                              selectedPrompt: _selectedPromptLine,
                              onSuggestionTap: _onDailySuggestionTapped,
                              onSelectPrompt: (p) {
                                ActivationTracker.trackActivationStarterPromptSelected();
                                setState(() => _selectedPromptLine = p);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showReturnedAfterDelayRecovery &&
                              !recordReadySuppressStreakPressure) ...[
                            const CaptureRecoveryHintStrip.returnedAfterDelay(),
                            const SizedBox(height: 12),
                          ],
                          if (showReturnDayFlow &&
                              returnDayFlowCandidate != null &&
                              !recordReadySuppressStreakPressure) ...[
                            ReturnDayFlowCard(
                              flow: returnDayFlowCandidate,
                              entryCount: _journalEntryCount,
                              onCameBack: () => setState(
                                () => _selectedPromptLine =
                                    ComeBackTomorrowV2Copy.cameBackRecordPrompt,
                              ),
                              onDifferent: () => setState(
                                () =>
                                    _selectedPromptLine = ComeBackTomorrowV2Copy
                                        .differentRecordPrompt,
                              ),
                              onAnswered: () {
                                if (mounted) setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showQuietSignalOnRecord &&
                              quietSignalCandidate != null &&
                              !recordReadySuppressStreakPressure) ...[
                            QuietSignalRecordCard(
                              signal: quietSignalCandidate,
                              entryCount: _journalEntryCount,
                              onKeepWatching: () {
                                if (mounted) setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showReturnTomorrowCueReady &&
                              returnTomorrowCueReady != null &&
                              !recordReadySuppressStreakPressure) ...[
                            ReturnTomorrowCueCard(
                              cue: returnTomorrowCueReady,
                              entryCount: _journalEntryCount,
                              surface: 'record_ready',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showFirstWeekProgressReady &&
                              firstWeekProgressReady != null &&
                              !recordReadySuppressStreakPressure) ...[
                            FirstWeekProgressLine(
                              progress: firstWeekProgressReady,
                              entryCount: _journalEntryCount,
                              surface: 'record_ready',
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (showLowEvidenceGuidanceOnRecord &&
                              !recordReadyShowsWatchTargetOnly) ...[
                            LowEvidenceGuidanceCard(
                              guidance: lowEvidenceGuidance,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showDailyArchiveMemory &&
                              !showReturningWatchTargetFocusedUi &&
                              dailyArchiveMemoryCandidate != null) ...[
                            DailyArchiveMemoryCard(
                              memory: dailyArchiveMemoryCandidate,
                              entryCount: _journalEntryCount,
                              source: 'record',
                              onRecord: () => unawaited(
                                _onRecordPressed(
                                  source: 'daily_archive_memory',
                                ),
                              ),
                              onViewPatternDetails:
                                  dailyArchiveMemoryCandidate
                                      .canShowPatternDetail
                                  ? _openPatternDetailFromRecord
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (ui == RecordUiState.ready &&
                              _journalEntryCountReady &&
                              recordProofStack.showEarlyFirstSignalCard &&
                              !showEarlyEvidenceTimelineOnRecord) ...[
                            if (EarlyFirstSignalEngine.build(
                                  entries: _journalEntries,
                                )
                                case final signal?) ...[
                              EarlyFirstSignalCard(
                                signal: signal,
                                showPrimaryCta:
                                    !_shouldHideCardRecordButtons(ui) &&
                                    FirstThreeSessionGates.showEarlyFirstSignalCardPrimaryCta(
                                      signal.kind,
                                    ),
                                showInsightFeedback:
                                    !suppressConfirmedRepeatInlineFeedback,
                                analyticsSurface: 'record',
                                entryCount: _journalEntryCount,
                                entriesForWhy: _journalEntries,
                                onPrimary: () =>
                                    unawaited(_onRecordPressed(source: 'main')),
                                onViewEvidence: signal.showsConfirmedRepeat
                                    ? () => context.push(
                                        BeliefEvidenceNavigation.route,
                                      )
                                    : null,
                                onReturnPrompt: signal.returnPrompt != null
                                    ? () {
                                        ConfirmedRepeatTriggerCapture.armForNextSave();
                                        setState(
                                          () => _selectedPromptLine = signal
                                              .returnPrompt!
                                              .guidedRecordPrompt,
                                        );
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (showPatternChanged &&
                              patternChangedCandidate != null) ...[
                            PatternChangedCard(
                              result: patternChangedCandidate,
                              entryCount: _journalEntryCount,
                              surface: 'record',
                              showRecordCta: showPatternChangedRecordCta,
                              onRecord: () => _handlePatternChangedRecord(
                                patternChangedCandidate,
                              ),
                              onDismissed: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showArchiveCurrentBeliefOnRecord &&
                              ui == RecordUiState.ready &&
                              archiveBeliefSurfaceCandidate.shouldShow) ...[
                            ArchiveBeliefSurfaceCard(
                              surface: archiveBeliefSurfaceCandidate,
                              onRecordNext: () => unawaited(
                                _onRecordPressed(
                                  source: 'archive_current_belief',
                                ),
                              ),
                            ),
                            if (patternNamePrompt != null) ...[
                              const SizedBox(height: 12),
                              PatternNameConfirmationCard(
                                prompt: patternNamePrompt,
                                source: 'record',
                                entryCount: _journalEntryCount,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                          if (showTimelineProofMomentOnRecord &&
                              timelineProofMomentCandidate != null) ...[
                            TimelineProofMomentCard(
                              result: timelineProofMomentCandidate,
                              source: 'record',
                            ),
                            if (showBetaProofLiftUnderTimelineProof &&
                                ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                              const SizedBox(height: 12),
                              BetaProofLiftCard(
                                result: betaProofLiftTimelineCandidate,
                                source: 'record',
                                surface: 'record_ready',
                              ),
                            ],
                            if (showBetaRepairLabProofOnRecord &&
                                ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                                betaRepairLabProofResult.shouldShow) ...[
                              const SizedBox(height: 12),
                              BetaRepairLabProofCard(
                                result: betaRepairLabProofResult,
                                onNotRelevantAnswered: () =>
                                    NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                                      entries: _journalEntries,
                                      source: 'record',
                                    ),
                                onChanged: () => setState(() {}),
                              ),
                            ] else if (showProofFloorRescueOnRecord &&
                                proofFloorRescueResult.shouldShow) ...[
                              const SizedBox(height: 12),
                              ProofFloorRescueCard(
                                result: proofFloorRescueResult,
                                onPrimaryCta: () => unawaited(
                                  navigateToTypeInsteadCapture(
                                    context,
                                    prompt: _selectedPromptLine,
                                    onSaved: _finishSuccessfulCapture,
                                  ),
                                ),
                                onNotRelevantAnswered: () =>
                                    NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                                      entries: _journalEntries,
                                      source: 'record',
                                    ),
                                onChanged: () => setState(() {}),
                              ),
                            ] else if (showProofQualityRepairOnRecord &&
                                proofQualityRepairResult.shouldShow) ...[
                              const SizedBox(height: 12),
                              ProofQualityRepairCard(
                                result: proofQualityRepairResult,
                                onNotRelevantAnswered: () =>
                                    NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                                      entries: _journalEntries,
                                      source: 'record',
                                    ),
                                onChanged: () => setState(() {}),
                              ),
                            ] else if (!showProofFloorRescueOnRecord) ...[
                              BetaProofFeedbackRow(
                                surface: BetaProofFeedbackSurface
                                    .timelineProofMoment,
                                source: 'record',
                                entryCount: _journalEntryCount,
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                      _journalEntries,
                                    ),
                                parentVisible: true,
                                isRecording: ui == RecordUiState.recording,
                                isPostSaveDegraded: false,
                                whatChangedQuestionActive: showWhatChangedV2,
                                patternReviewInboxHasActiveItems:
                                    patternReviewInboxActiveOnRecord,
                                onNotRelevantAnswered: () =>
                                    NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                                      entries: _journalEntries,
                                      source: 'record',
                                    ),
                                onChanged: () => setState(() {}),
                              ),
                            ],
                            if (showProofQualityResponseUnderTimelineProof) ...[
                              const SizedBox(height: 12),
                              ProofQualityResponseCard(
                                result: proofQualityResponseTimelineCandidate,
                                source: 'record',
                                onChanged: () => setState(() {}),
                              ),
                            ] else ...[
                              if (showNotRelevantRecoveryUnderTimelineProof) ...[
                                const SizedBox(height: 12),
                                NotRelevantRecoveryCard(
                                  result: notRelevantRecoveryCandidate,
                                  source: 'record',
                                  onChanged: () => setState(() {}),
                                ),
                              ],
                              if (showProofSpecificityBoostOnTimelineProof) ...[
                                const SizedBox(height: 12),
                                ProofSpecificityBoostCard(
                                  result: proofSpecificityBoostCandidate,
                                  surface: ProofSpecificityBoostSurface
                                      .timelineProofMoment,
                                  source: 'record',
                                  hasConfirmedRepeat:
                                      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                        _journalEntries,
                                      ),
                                  proofKey: CurrentRelevanceStore.proofKeyFor(
                                    _journalEntries,
                                  ),
                                  onChanged: () => setState(() {}),
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                          ],
                          if (showReturnAfterProofLiftV2BelowProofOnRecord &&
                              showTimelineProofMomentOnRecord &&
                              timelineProofMomentCandidate != null) ...[
                            ReturnAfterProofLiftV2Card(
                              result: returnAfterProofLiftV2Candidate,
                              onPrimaryCta: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else if (showReturnAfterProofBelowProofOnRecord &&
                              showTimelineProofMomentOnRecord &&
                              timelineProofMomentCandidate != null) ...[
                            ReturnAfterProofCard(
                              result: returnAfterProofRecordCandidate,
                              useStrengthenedLayout:
                                  showReturnAfterProofStrengthenedOnRecordReady,
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showBetaFeedbackCaptureRecordReady &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                              !showReturningWatchTargetFocusedUi &&
                              betaFeedbackCaptureRecordReadyResult != null) ...[
                            BetaFeedbackCaptureCard(
                              result: betaFeedbackCaptureRecordReadyResult,
                              proofFeedbackSurface:
                                  betaFeedbackCaptureRecordReadyResult.moment ==
                                      BetaFeedbackCaptureMoment
                                          .afterTimelineProof
                                  ? BetaProofFeedbackSurface.timelineProofMoment
                                  : null,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showArchiveTimelineSpineOnRecord &&
                              archiveTimelineSpineCandidate != null) ...[
                            ArchiveTimelineSpineCard(
                              result: archiveTimelineSpineCandidate,
                              source: 'record',
                            ),
                            BetaProofFeedbackRow(
                              surface:
                                  BetaProofFeedbackSurface.archiveTimelineSpine,
                              source: 'record',
                              entryCount: _journalEntryCount,
                              hasConfirmedRepeat:
                                  EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                    _journalEntries,
                                  ),
                              parentVisible: true,
                              isRecording: ui == RecordUiState.recording,
                              isPostSaveDegraded: false,
                              whatChangedQuestionActive: showWhatChangedV2,
                              patternReviewInboxHasActiveItems:
                                  patternReviewInboxActiveOnRecord,
                              onNotRelevantAnswered: () =>
                                  NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                                    entries: _journalEntries,
                                    source: 'record',
                                  ),
                              onChanged: () => setState(() {}),
                            ),
                            if (showProofQualityResponseUnderArchiveSpine) ...[
                              const SizedBox(height: 12),
                              ProofQualityResponseCard(
                                result: proofQualityResponseSpineCandidate,
                                source: 'record',
                                onChanged: () => setState(() {}),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                          if (showBetaTesterReportOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            BetaTesterReportCard(
                              result: betaTesterReportCandidate,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showReturnAfterProofLiftV2BelowProofOnRecord) ...[
                            ReturnAfterProofLiftV2Card(
                              result: returnAfterProofLiftV2Candidate,
                              onPrimaryCta: () => unawaited(
                                navigateToTypeInsteadCapture(
                                  context,
                                  prompt: _selectedPromptLine,
                                  onSaved: _finishSuccessfulCapture,
                                ),
                              ),
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else if (showReturnAfterProofBelowProofOnRecord &&
                              !showTimelineProofMomentOnRecord &&
                              showBetaTesterReportOnRecord) ...[
                            ReturnAfterProofCard(
                              result: returnAfterProofRecordCandidate,
                              useStrengthenedLayout:
                                  showReturnAfterProofStrengthenedOnRecordReady,
                              onPromptSelected: (prompt) {
                                setState(() => _selectedPromptLine = prompt);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            EvidenceTrailClarityCard(
                              result: betaRepairLabEvidenceTrailClarityResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_beta_repair_lab_evidence_trail_clarity',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showBetaRepairLabPricingValidationBelowProofOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            PricingValidationCard(
                              result: betaRepairLabPricingValidationResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_beta_repair_lab_pricing_validation',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showBetaRepairLabPricingValueFramingBelowProofOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            PricingValueFramingCard(
                              result: betaRepairLabPricingValueFramingResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_beta_repair_lab_pricing_value_framing',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showBetaRepairLabPaywallValueBelowProofOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            PaywallValueRepairCard(
                              result: betaRepairLabPaywallValueResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_beta_repair_lab_paywall_value',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showBetaRepairLabProPlacementBelowProofOnRecord &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                            BetaRepairLabProPlacementCard(
                              result: betaRepairLabProPlacementResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_beta_repair_lab_pro_placement',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProUnderstandingLiftBelowProofOnRecord &&
                              proUnderstandingLiftRecordReadyResult !=
                                  null) ...[
                            ProUnderstandingLiftCard(
                              result: proUnderstandingLiftRecordReadyResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_pro_understanding_lift',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProVisibilityLiftBelowProofOnRecord &&
                              proVisibilityLiftRecordReadyResult != null) ...[
                            ProVisibilityLiftCard(
                              result: proVisibilityLiftRecordReadyResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_pro_visibility_lift',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProBridgeBelowProofOnRecord &&
                              proBridgeVisibilityRecordResult != null) ...[
                            ProBridgeVisibilityCard(
                              result: proBridgeVisibilityRecordResult,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_pro_bridge_visibility',
                              ),
                              onDismiss: () =>
                                  unawaited(_dismissProEvidenceValueBridge()),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showShareableNonPrivateProofOnRecord) ...[
                            ShareableProofCard(
                              result: shareableNonPrivateProofResult,
                              source: 'record',
                              surface: 'record_ready',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showCurrentRelevanceOnRecordReady &&
                              currentRelevanceCandidate != null) ...[
                            CurrentRelevanceCard(
                              state: currentRelevanceCandidate,
                              source: 'record',
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showCorrectionMemoryOnRecordReady &&
                              correctionMemoryCandidate != null) ...[
                            CorrectionMemoryCard(
                              result: correctionMemoryCandidate,
                              source: 'record',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showProofQualityResponseOnRecordReady &&
                              !showProofQualityResponseUnderTimelineProof &&
                              !showProofQualityResponseUnderArchiveSpine &&
                              proofQualityResponseTimelineCandidate
                                  .shouldShow) ...[
                            ProofQualityResponseCard(
                              result: proofQualityResponseTimelineCandidate,
                              source: 'record',
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showNotRelevantRecoveryOnRecordReady &&
                              !showNotRelevantRecoveryUnderTimelineProof &&
                              notRelevantRecoveryCandidate.shouldShow) ...[
                            NotRelevantRecoveryCard(
                              result: notRelevantRecoveryCandidate,
                              source: 'record',
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showEvidenceWeightingOnRecordReady &&
                              evidenceWeightingCandidate != null) ...[
                            EvidenceWeightingCard(
                              result: evidenceWeightingCandidate,
                              source: 'record',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showProofSpecificityOnRecordReady &&
                              proofSpecificityCandidate.shouldShow) ...[
                            ProofSpecificityCard(
                              result: proofSpecificityCandidate,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showPresentDayRelevanceOnRecordReady &&
                              presentDayRelevanceCandidate != null) ...[
                            PresentDayRelevanceCard(
                              result: presentDayRelevanceCandidate,
                              source: 'record',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!suppressLegacyEducationCardsForSpineOnRecord &&
                              showPatternConfidenceExplanationOnRecordReady &&
                              patternConfidenceExplanationCandidate !=
                                  null) ...[
                            PatternConfidenceCard(
                              result: patternConfidenceExplanationCandidate,
                              source: 'record',
                              compact: true,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!showReturningWatchTargetFocusedUi &&
                              showArchiveSummaryOnRecord &&
                              ui == RecordUiState.ready &&
                              archiveSummary != null) ...[
                            ArchiveSummaryCard(
                              summary: archiveSummary,
                              showRecordNextCta: showArchiveSummaryRecordCta,
                              watching: archiveWatching,
                              onRecordNext: () =>
                                  _handleArchiveSummaryRecordNext(
                                    archiveSummary,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showDailyReturnReasonOnRecord &&
                              dailyReturnReason != null) ...[
                            DailyReturnReasonCard(
                              reason: dailyReturnReason,
                              showRecordCta: showDailyReturnReasonRecordCta,
                              onRecord: () =>
                                  _handleDailyReturnReason(dailyReturnReason),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showEarlyEvidenceTimelineOnRecord) ...[
                            EarlyEvidenceTimelineCard(
                              timeline: earlyEvidenceTimeline!,
                              compact: true,
                              nearbyConfirmedRepeat:
                                  proofSurfaceLayout.timelineNearby,
                              suppressEvidencePhrases: proofSurfaceLayout
                                  .suppressTimelineEvidencePhrases,
                              analyticsSurface: 'record',
                              entryCount: _journalEntryCount,
                              entriesForWhy: _journalEntries,
                              onRecordWhatHelped:
                                  earlyEvidenceTimeline.showsSofterReturn &&
                                      !earlyEvidenceTimeline.showsHelpfulAction
                                  ? () {
                                      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                                      setState(
                                        () => _selectedPromptLine =
                                            EarlyFirstSignalCopy
                                                .recordWhatHelpedGuidedPrompt,
                                      );
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showWeeklyArchiveReviewOnRecord &&
                              weeklyArchiveReview != null) ...[
                            weekly_review_surface.WeeklyArchiveReviewCard(
                              review: weeklyArchiveReview,
                              onViewReview: () =>
                                  _openWeeklyArchiveReview(weeklyArchiveReview),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showPrivateArchiveReportOnRecord &&
                              privateArchiveReportCandidate != null) ...[
                            PrivateArchiveReportCard(
                              report: privateArchiveReportCandidate,
                              entryCount: _journalEntryCount,
                              surface: 'record',
                              isPro: _recordReturnProIsPro,
                              onSeePro: _recordReturnProIsPro
                                  ? null
                                  : () => unawaited(
                                      _resolveRecordReturnProBridge(
                                        seePro: true,
                                      ),
                                    ),
                            ),
                            if (BetaProofFeedbackEngine.shouldShowOnPrivateArchiveReportPreview(
                              privateArchiveReportVisible: true,
                              isPro: _recordReturnProIsPro,
                              entryCount: _journalEntryCount,
                              hasConfirmedRepeat:
                                  EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                    _journalEntries,
                                  ),
                              isRecording: ui == RecordUiState.recording,
                              isPostSaveDegraded: false,
                              whatChangedQuestionActive: showWhatChangedV2,
                              patternReviewInboxHasActiveItems:
                                  patternReviewInboxActiveOnRecord,
                            ))
                              BetaProofFeedbackRow(
                                surface: BetaProofFeedbackSurface
                                    .privateArchiveReportPreview,
                                source: 'record',
                                entryCount: _journalEntryCount,
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                      _journalEntries,
                                    ),
                                parentVisible: true,
                                isRecording: ui == RecordUiState.recording,
                                isPostSaveDegraded: false,
                                whatChangedQuestionActive: showWhatChangedV2,
                                patternReviewInboxHasActiveItems:
                                    patternReviewInboxActiveOnRecord,
                                onChanged: () => setState(() {}),
                              ),
                            const SizedBox(height: 12),
                          ],
                          if (showProEvidenceValuePrivateReportOnRecord) ...[
                            ProEvidenceValueCard(
                              surface:
                                  ProEvidenceValueSurface.privateReportPreview,
                              entryCount: _journalEntryCount,
                              compact: true,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_private_report_pro_evidence_value',
                              ),
                              onDismiss: () =>
                                  unawaited(_dismissProEvidenceValueBridge()),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showConfirmedRepeatWhyMattersOnRecord) ...[
                            ConfirmedRepeatWhyMattersCard(
                              onDismissed: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showConfirmedRepeatThoughtMapOnRecord &&
                              confirmedRepeatThoughtMap != null) ...[
                            ConfirmedRepeatThoughtMapCard(
                              result: confirmedRepeatThoughtMap,
                              showRecordMissingPieceCta:
                                  showThoughtMapRecordCta,
                              onRecordMissingPiece: () =>
                                  _handleThoughtMapMissingPiece(
                                    confirmedRepeatThoughtMap,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showHelpfulActionAppearedOnRecord &&
                              helpfulActionAppearedCandidate != null) ...[
                            HelpfulActionAppearedCard(
                              result: helpfulActionAppearedCandidate,
                              entryCount: _journalEntryCount,
                              source: 'record',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showPositiveReinforcementOnRecord &&
                              positiveReinforcement != null) ...[
                            PositiveReinforcementCard(
                              reinforcement: positiveReinforcement,
                              showRecordAgainCta:
                                  showPositiveReinforcementRecordCta,
                              onRecordAgain: () =>
                                  _handlePositiveReinforcementRecordAgain(
                                    positiveReinforcement,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showChangeProofOnRecord &&
                              repeatReturnChangeProof != null) ...[
                            RepeatReturnCheckChangeProofCard(
                              proof: repeatReturnChangeProof,
                              entryCount: _journalEntryCount,
                              surface: 'record',
                              onRecordNext: () => unawaited(
                                _onRecordPressed(source: 'repeat_return_proof'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showConfirmedRepeatBetaFeedback &&
                              !showReturningWatchTargetFocusedUi &&
                              !showArchiveSummaryOnRecord) ...[
                            ConfirmedRepeatBetaFeedbackCard(
                              entryCount: _journalEntryCount,
                              surface: 'record',
                              viewingConfirmedRepeat:
                                  viewingConfirmedRepeatOnRecord,
                              isRecording: ui == RecordUiState.recording,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showFirstWeekLoopOnRecord &&
                              firstWeekLoopCandidate != null &&
                              !recordReadySuppressStreakPressure) ...[
                            FirstWeekLoopCard(
                              loop: firstWeekLoopCandidate,
                              entryCount: _journalEntryCount,
                              showRecordCta: showFirstWeekLoopRecordCta,
                              onRecord: () => unawaited(
                                _onRecordPressed(source: 'first_week_loop'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showBetaTestScriptCard &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                              !showReturningWatchTargetFocusedUi &&
                              betaTestScriptCardCandidate != null) ...[
                            BetaTestScriptCard(
                              card: betaTestScriptCardCandidate,
                              onViewSteps: () {
                                BetaTestScriptSheet.show(
                                  context,
                                  entries: _journalEntries,
                                  source: 'record',
                                  onReset: () {
                                    if (mounted) setState(() {});
                                  },
                                );
                              },
                              onSendFeedback:
                                  betaTestScriptCardCandidate
                                      .showSendFeedbackSecondary
                                  ? () {
                                      BetaFeedbackSheet.show(
                                        context,
                                        source: 'record_beta_test_script',
                                        entryCount: _journalEntryCount,
                                      );
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (showProUnderstandingLiftInProSectionOnRecord &&
                              proUnderstandingLiftRecordReadyResult !=
                                  null) ...[
                            ProUnderstandingLiftCard(
                              result: proUnderstandingLiftRecordReadyResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_pro_understanding_lift',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProVisibilityLiftInProSectionOnRecord &&
                              proVisibilityLiftRecordReadyResult != null) ...[
                            ProVisibilityLiftCard(
                              result: proVisibilityLiftRecordReadyResult,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_pro_visibility_lift',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProBridgeInProSectionOnRecord &&
                              proBridgeVisibilityRecordResult != null) ...[
                            ProBridgeVisibilityCard(
                              result: proBridgeVisibilityRecordResult,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_pro_bridge_visibility',
                              ),
                              onDismiss: () =>
                                  unawaited(_dismissProEvidenceValueBridge()),
                            ),
                            const SizedBox(height: 12),
                          ] else if (showProEvidenceValueOnRecordReady) ...[
                            ProEvidenceValueCard(
                              surface: ProEvidenceValueSurface.recordReady,
                              entryCount: _journalEntryCount,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_pro_evidence_value',
                              ),
                              onDismiss: () =>
                                  unawaited(_dismissProEvidenceValueBridge()),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (betaFeedbackIntelligenceSurfaceOnRecordReady !=
                                  null &&
                              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                              !showReturningWatchTargetFocusedUi) ...[
                            BetaFeedbackIntelligenceCard(
                              surface:
                                  betaFeedbackIntelligenceSurfaceOnRecordReady,
                              entryCount: _journalEntryCount,
                              reachedFirstProof: firstProofPayoffSeenOnRecord,
                              compact: proofSurfaceLayout.proBridgeCompact,
                              onSubmitted: () {
                                if (mounted) setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (ui == RecordUiState.ready &&
                              _journalEntryCountReady &&
                              RecordEmptyArchiveGates.showConfirmedRepeatChangeNoticeCard(
                                loaded: _journalEntryCountReady,
                                entryCount: _journalEntryCount,
                                isPostSave: _isPostSaveSurface,
                              ) &&
                              !showEarlyEvidenceTimelineOnRecord &&
                              !showArchiveSummaryOnRecord) ...[
                            if (EarlyFirstSignalEngine.buildChangeNotice(
                                  entries: _journalEntries,
                                )
                                case final notice?) ...[
                              ConfirmedRepeatChangeNoticeCard(
                                notice: notice,
                                analyticsSurface: 'record',
                                entryCount: _journalEntryCount,
                                entriesForWhy: _journalEntries,
                                onRecordWhatHelped: () {
                                  ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                                  setState(
                                    () => _selectedPromptLine =
                                        notice.guidedRecordPrompt,
                                  );
                                },
                                onViewEvidence: () => context.push(
                                  BeliefEvidenceNavigation.route,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (showEarlyReturnReminder) ...[
                            EarlyArchiveReturnReminderCard(
                              source: 'record',
                              onDismiss: () => setState(
                                () => _earlyReturnReminderHidden = true,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Zero-entry intro card removed — [RecordTopArchivePromiseHero]
                          // carries the first-open promise without a second competing card.
                          if (ui == RecordUiState.ready &&
                              recordHomeSurface.showDailyMirrorCard &&
                              !(_journalEntryCountReady &&
                                  _journalEntryCount == 0)) ...[
                            DailyMirrorRecordCard(
                              mirror: _dailyMirror,
                              onPrimaryCta: () =>
                                  unawaited(_onRecordPressed(source: 'moment')),
                              showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ),
                            if (_showFirstRunPrivacyReassurance) ...[
                              const SizedBox(height: 8),
                              const RecordFirstRunPrivacyReassurance(),
                            ],
                            const SizedBox(height: 12),
                          ],
                          if (_missedCheckInForDiagnosis != null &&
                              ui == RecordUiState.ready &&
                              _showBottomRetentionCards) ...[
                            MissedCheckInReasonPrompt(
                              checkIn: _missedCheckInForDiagnosis!,
                              onAnswered: () => setState(
                                () => _missedCheckInForDiagnosis = null,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if ((_showCurrentObjectiveOnRecord &&
                                  (ui == RecordUiState.ready
                                      ? recordHomeSurface
                                            .showCurrentObjectiveCard
                                      : stack.showCurrentObjectiveCard) &&
                                  !_shouldHideCompetingRecordCtas(ui)) ||
                              (ScreenshotMode.enabled &&
                                  ScreenshotMode.objective != null)) ...[
                            _currentObjectiveWidget(stack)!,
                            const SizedBox(height: 16),
                          ],
                          if ((ui == RecordUiState.ready
                                  ? recordHomeSurface.showRetentionStateCard
                                  : stack.showRetentionStateCard) &&
                              showArchiveProgressCards) ...[
                            _retentionCardWidget(stack)!,
                            const SizedBox(height: 16),
                          ],
                          if (stack.showDueCheckCard &&
                              _journalEntryCountReady &&
                              _journalEntryCount >= 1) ...[
                            Builder(
                              builder: (context) {
                                final guided =
                                    _hookRescue?.includes(
                                      HookRescueAction.guidedCheckIn,
                                    ) ??
                                    false;
                                return TomorrowCheckInDueCard(
                                  checkIn: _dueCheckInToday!,
                                  plannedAnchor: _dueRoutineAnchor,
                                  guided: guided,
                                  // Fast path by default; only the gated guided flow opts
                                  // out so confused users still get the step-by-step card.
                                  oneTapMode: !guided,
                                  onRecord: () => unawaited(
                                    _onRecordPressed(source: 'moment'),
                                  ),
                                  onSelectOption: (option) async {
                                    final checkInId = _dueCheckInToday!.id;
                                    final updated =
                                        await TomorrowCheckInCoordinator.selectOption(
                                          checkInId: checkInId,
                                          optionId: option.id,
                                        );
                                    await ReturnDayFrictionCoordinator.markAnswerSelected(
                                      checkInId,
                                      option.id,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _dueCheckInToday = updated;
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (stack.showReturnDayJourneyCard &&
                              showArchiveProgressCards &&
                              _signalJourney != null &&
                              ui == RecordUiState.ready) ...[
                            ReturnDayJourneyCard(
                              journey: _signalJourney!,
                              recordedToday: const ReturnDayJourneyEngine()
                                  .evaluate(
                                    journey: _signalJourney,
                                    reflectionCount: _journalEntryCount,
                                    now: DateTime.now(),
                                    lastReflectionAt: _lastReflectionAt,
                                  )
                                  .recordedToday,
                              onViewChanged: () =>
                                  context.push('/signal-journey'),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_shouldHideCompetingRecordCtas(ui) &&
                              _activeLoop?.isCapacityYes == true &&
                              CapacityLoopGates.showRecordPrompt(
                                capacityWedgeActive: true,
                                sampleMode: ScreenshotMode.enabled,
                              ) &&
                              ui == RecordUiState.ready &&
                              _mic == RecordingPhase.ready &&
                              _postSavePattern == null) ...[
                            BeforeYouSayYesCard(
                              result: const BeforeYesPauseEngine().build(
                                BeforeYesPauseInput(
                                  capacityWedgeActive: true,
                                  sampleMode: ScreenshotMode.enabled,
                                  realSavedMomentCount: 0,
                                  capacityEvidenceCount: 0,
                                  capacityLoopHasCard: false,
                                  costLaterCheckinVisible: false,
                                  recordedCostCount: 0,
                                ),
                              ),
                              onPauseBeforeYes: () {
                                setState(
                                  () => _selectedPromptLine =
                                      BeforeYesCopy.recordPrompt,
                                );
                                unawaited(
                                  _onRecordPressed(source: 'before_yes_pause'),
                                );
                              },
                              onAlreadySaidYes: () {
                                setState(
                                  () => _selectedPromptLine =
                                      LoopModeCopy.capacityHandoffPrompt,
                                );
                                unawaited(
                                  _onRecordPressed(source: 'capacity_loop'),
                                );
                              },
                              onQuickSave: () =>
                                  context.push(LowEffortYesCaptureCopy.route),
                            ),
                            const SizedBox(height: 12),
                            LowEffortYesCaptureCard(
                              result: const LowEffortYesCaptureEngine().build(
                                const LowEffortYesCaptureInput(
                                  capacityWedgeActive: true,
                                  sampleMode: false,
                                  screenshotMode: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final threeMoment =
                                    const CapacityThreeMomentEngine()
                                        .buildFromJournal(
                                          entries: _journalEntries,
                                          capacityLoopActive:
                                              _activeLoop?.isCapacityYes ??
                                              false,
                                          capacityCohortActive: false,
                                          sampleMode: false,
                                        );
                                final progressLine =
                                    CapacityThreeMomentEngine.recordProgressLine(
                                      threeMoment,
                                    );
                                if (progressLine.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    Text(
                                      progressLine,
                                      key: const Key(
                                        'record_screen_capacity_three_moment_progress',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: VoiceMemoryColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            ),
                          ],
                          if (_showDefaultBoundaryPauseOnRecord(ui)) ...[
                            Text(
                              _defaultBoundaryPauseLabel!,
                              key: const Key(
                                'record_screen_default_boundary_pause',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: VoiceMemoryColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_shouldHideCompetingRecordCtas(ui) &&
                              stack.showFirstRecordingHandoff &&
                              _activeLoop != null) ...[
                            LoopModeFirstHandoffCard(
                              loop: _activeLoop!,
                              onStartRecording: () =>
                                  _onRecordPressed(source: 'main'),
                              showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ),
                            const SizedBox(height: 12),
                          ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                              stack.showFirstRecordingHandoff) ...[
                            FirstRecordingHandoffCard(
                              onStartRecording: () =>
                                  _onRecordPressed(source: 'main'),
                              wedgePrompt: _selectedPromptLine,
                              showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ),
                            const SizedBox(height: 12),
                          ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                              _activeLoop != null &&
                              showArchiveProgressCards &&
                              _postSavePattern == null &&
                              !stack.showReturnDayJourneyCard) ...[
                            LoopModeProgressCard(
                              loop: _activeLoop!,
                              onRecordNext: () =>
                                  unawaited(_onRecordPressed(source: 'loop')),
                              showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ),
                            const SizedBox(height: 12),
                          ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                              stack.showArchiveMemoryDemo) ...[
                            ArchiveMemoryDemoCard(
                              onRecord: () =>
                                  unawaited(_onRecordPressed(source: 'main')),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (stack.showFirstLoopStartCard &&
                              !_shouldHideCompetingRecordCtas(ui)) ...[
                            FirstLoopStartCard(
                              onRecord: () =>
                                  unawaited(_onRecordPressed(source: 'loop')),
                              showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (stack.showTrialFirstMomentCard &&
                              !_shouldHideCompetingRecordCtas(ui)) ...[
                            TrialFirstMomentCard(
                              onStartRecording: () =>
                                  unawaited(_onRecordPressed(source: 'main')),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                        AnimatedSwitcher(
                          key: const Key(
                            'microphone_recovery_animated_switcher',
                          ),
                          duration: const Duration(milliseconds: 280),
                          reverseDuration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  child: child,
                                ),
                              ),
                          child:
                              RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
                                ui: ui,
                                micPhase: _mic,
                                userDeniedThisSession: _micPermissionUserDenied,
                              )
                              ? Padding(
                                  key: const ValueKey(
                                    'microphone_recovery_visible',
                                  ),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: KeyedSubtree(
                                    key: _permissionPanelKey,
                                    child: MicrophonePermissionBlockedPanel(
                                      showSimulatorHelper:
                                          _showMicPermissionSimulatorHelper,
                                      onOpenSettings: _openMicSettings,
                                      onTypeInstead: _typeInsteadFromPermission,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('microphone_recovery_hidden'),
                                ),
                        ),
                        if (ui == RecordUiState.recording) ...[
                          _RecordingStatusCard(
                            seconds: _seconds,
                            stageLabel: stageLabel,
                          ),
                          if (_selectedPromptLine != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _selectedPromptLine!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: VoiceMemoryColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ] else ...[
                          if (ui == RecordUiState.ready &&
                              _showReadyToRecordStatus &&
                              !showReturningWatchTargetFocusedUi) ...[
                            Semantics(
                              label: 'Recording status',
                              child: Text(
                                stageLabel.isEmpty
                                    ? _statusTextFor(ui, localSaveTitle)
                                    : stageLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                          if (ui == RecordUiState.processing) ...[
                            const SizedBox(height: 12),
                            PostSaveListeningCard(stageLabel: stageLabel),
                          ],
                          if (_selectedPromptLine != null &&
                              _showBottomRetentionCards &&
                              !showReturningWatchTargetFocusedUi &&
                              (ui == RecordUiState.ready ||
                                  ui == RecordUiState.recording)) ...[
                            const SizedBox(height: 12),
                            Text(
                              ConsumerUiCopy.trySayingLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: VoiceMemoryColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedPromptLine!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: VoiceMemoryColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              recordHomeSurface.showNextEvidencePrompt &&
                              _nextEvidencePrompt != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ConsumerUiCopy
                                        .postSaveInsightRecordThisNext,
                                    style: ArchiveMobileTypography.cardLabel(
                                      context,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _nextEvidencePrompt!,
                                    style:
                                        ArchiveMobileTypography.explanationBody(
                                          context,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              stack.showActivePatternThread &&
                              _activePatternThread != null) ...[
                            const SizedBox(height: 12),
                            ActivePatternThreadPromptCard(
                              thread: _activePatternThread!,
                              onAddMoment: () =>
                                  unawaited(_onRecordPressed(source: 'moment')),
                              onPause: () async {
                                await ActivePatternThreadCoordinator.pauseThread();
                                if (!mounted) return;
                                setState(() => _activePatternThread = null);
                              },
                            ),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              stack.showFirstThreeJourney &&
                              _firstThreeJourney != null &&
                              _firstThreeJourney!.showOnRecord &&
                              _showFirstThreeJourneyOnRecord) ...[
                            const SizedBox(height: 12),
                            FirstThreeJourneyCard(model: _firstThreeJourney!),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              _postSavePattern == null &&
                              !stack.showReturnDayJourneyCard &&
                              _showRetentionJourneyCards &&
                              _signalJourney != null &&
                              _signalJourney!.isActive) ...[
                            const SizedBox(height: 12),
                            SignalJourneyCard(
                              journey: _signalJourney!,
                              activeLoop: _activeLoop,
                              compact: true,
                            ),
                          ] else if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              _postSavePattern == null &&
                              _showRetentionJourneyCards &&
                              _signalJourney != null &&
                              _signalJourney!.showCompletion &&
                              !_journeyCompletionDismissed &&
                              _signalReview != null &&
                              _signalReview!.isShowable) ...[
                            const SizedBox(height: 12),
                            SignalReviewCard(
                              review: _signalReview!,
                              onConfirm: () async {
                                await SignalReviewCoordinator.confirm(
                                  reviewId: _signalReview!.id,
                                );
                                if (!mounted) return;
                                setState(
                                  () => _journeyCompletionDismissed = true,
                                );
                                unawaited(_loadSignalArchive());
                              },
                              onCorrect: () {
                                SignalReviewNavigation.openFullReview(context);
                              },
                              onKeepWatching: () async {
                                await SignalReviewCoordinator.keepWatching(
                                  reviewId: _signalReview!.id,
                                );
                                final journey =
                                    await SignalJourneyCoordinator.loadActive();
                                if (journey != null) {
                                  unawaited(
                                    NextEvidenceReminderService.schedule(
                                      journeyId: journey.id,
                                      prompt: _signalReview!.nextEvidencePrompt,
                                    ),
                                  );
                                }
                                if (!context.mounted) return;
                                setState(
                                  () => _journeyCompletionDismissed = true,
                                );
                                unawaited(_loadSignalArchive());
                                SignalReviewNavigation.recordNextEvidence(
                                  context,
                                  prompt: _signalReview!.nextEvidencePrompt,
                                );
                              },
                            ),
                          ] else if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              _postSavePattern == null &&
                              _showRetentionJourneyCards &&
                              _signalJourney != null &&
                              _signalJourney!.showCompletion &&
                              !_journeyCompletionDismissed) ...[
                            const SizedBox(height: 12),
                            SignalJourneyCompletionCard(
                              journey: _signalJourney!,
                              onKeepWatching: () async {
                                await SignalJourneyCoordinator.acknowledgeCompletion();
                                if (!mounted) return;
                                setState(
                                  () => _journeyCompletionDismissed = true,
                                );
                                unawaited(_loadSignalArchive());
                              },
                              onViewPattern: () =>
                                  context.go('/archive-belief'),
                            ),
                          ] else if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              _postSavePattern == null &&
                              _showRetentionJourneyCards &&
                              _signalArchiveSnapshot?.hasActiveSignal ==
                                  true) ...[
                            const SizedBox(height: 12),
                            ArchiveWatchingCard(
                              snapshot: _signalArchiveSnapshot!,
                              compact: true,
                            ),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              showArchiveProgressCards &&
                              stack.showPendingWatchFor &&
                              _pendingWatchForToday != null) ...[
                            const SizedBox(height: 12),
                            TodaysWatchForCard(
                              pending: _pendingWatchForToday!,
                              onRecord: () =>
                                  unawaited(_onRecordPressed(source: 'moment')),
                              onSkip: () async {
                                await WatchForCoordinator.skipPendingForToday();
                                if (!mounted) return;
                                setState(() => _pendingWatchForToday = null);
                              },
                            ),
                          ],
                          if (ui == RecordUiState.ready &&
                              !showReturningWatchTargetFocusedUi &&
                              recordHomeSurface.showOneSmallRecordingCard &&
                              stack.showStarterPrompts &&
                              recordHomeSurface.showWorthCheckingToday) ...[
                            if (_oneSmallRecording.hasRecording) ...[
                              const SizedBox(height: 12),
                              OneSmallRecordingCard(
                                recording: _oneSmallRecording,
                                showRecordCta: !_shouldHideCardRecordButtons(
                                  ui,
                                ),
                                ctaLabel:
                                    _recordCtaPolicy(
                                      ui,
                                      micPhase: policyMic,
                                      userDeniedThisSession: policyUserDenied,
                                    ).primaryLabel ??
                                    OneSmallRecording.recordCtaLabel,
                                onRecordThis: (p) {
                                  ActivationTracker.trackActivationStarterPromptSelected();
                                  setState(() => _selectedPromptLine = p);
                                  unawaited(
                                    _onRecordPressed(
                                      source: 'one_small_recording',
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              LowEffortCheckInCard(
                                onSelect: _saveLowEffortCheckIn,
                              ),
                            ],
                            if (_dailyReturnSuggestions.hasSuggestions &&
                                recordHomeSurface.showWorthCheckingToday) ...[
                              const SizedBox(height: 12),
                              DailyReturnSuggestionsCard(
                                suggestionSet: _dailyReturnSuggestions,
                                selectedPrompt: _selectedPromptLine,
                                onSuggestionTap: _onDailySuggestionTapped,
                                onSelectPrompt: (p) {
                                  ActivationTracker.trackActivationStarterPromptSelected();
                                  setState(() => _selectedPromptLine = p);
                                },
                              ),
                            ],
                            if (recordHomeSurface.showTrySayingPrompts) ...[
                              const SizedBox(height: 12),
                              ConsumerRecordPromptsSection(
                                selectedPrompt: _selectedPromptLine,
                                personalPrompts: _personalReturnPrompts,
                                deemphasized: _oneSmallRecording.hasRecording,
                                onSelectPrompt: (p) {
                                  ActivationTracker.trackActivationStarterPromptSelected();
                                  _pendingSuggestionSource = null;
                                  _pendingTappedSuggestion = null;
                                  setState(() => _selectedPromptLine = p);
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).recordingPlainLanguageHint,
                                style: VoiceMemoryTypography.metadataStyle(
                                  color: AppColors.textSecondary,
                                ).copyWith(fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 6),
                              QuickHelpButton(
                                languageCode: _languageCode,
                                patternTitle: _activePatternThread?.title,
                                onStartRecording: () =>
                                    _onRecordPressed(source: 'main'),
                              ),
                            ],
                          ],
                          if (ui == RecordUiState.done &&
                              entriesAfterSave.isNotEmpty) ...[
                            if (justSavedFirstEntry &&
                                !showDegradedTranscriptFocusedPostSave) ...[
                              const SizedBox(height: 16),
                              PostSaveRecordedSummaryCard(
                                entry: entriesAfterSave.first,
                                allEntries: entriesAfterSave,
                                showAnalysisPendingNote: false,
                                mirror: postSaveDailyMirror,
                                primaryArchiveResult: PostSavePrimaryArchiveKind
                                    .firstEntryFootnote,
                                onCorrectTranscript:
                                    _lastSavedEntry != null &&
                                        TranscriptCorrectionGate.entryAllowsCorrection(
                                          _lastSavedEntry!,
                                        )
                                    ? () => unawaited(
                                        _openCorrectTranscriptForEntry(
                                          _lastSavedEntry!,
                                        ),
                                      )
                                    : null,
                                onBackToRecord: _resetPostSaveToReady,
                              ),
                            ],
                            if (!suppressNoisyFirstSaveCards &&
                                    !suppressNoisyRepeatPostSaveCards ||
                                showDegradedTranscriptFocusedPostSave) ...[
                              if (!VoiceCaptureQuality.isDegradedVoiceCapture(
                                entriesAfterSave.first,
                              )) ...[
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: VoiceMemoryColors.captureSuccess,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        BeliefProductCopy.reflectionSavedTitle,
                                        style:
                                            VoiceMemoryTypography.cardTitleStyle(
                                              color: VoiceMemoryColors
                                                  .captureSuccess,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                const SizedBox(height: 16),
                              ],
                              PostSaveRecordedSummaryCard(
                                entry: entriesAfterSave.first,
                                allEntries: entriesAfterSave,
                                degradedBodyCopy:
                                    _lastCaptureLowQualityTranscript
                                    ? VoiceCaptureCopy.lowQualityTranscriptIssue
                                    : null,
                                showSilentInputWarning:
                                    _lastCaptureLikelySilentInput,
                                showAnalysisPendingNote: false,
                                mirror: postSaveDailyMirror,
                                primaryArchiveResult:
                                    postSaveArchiveHierarchy?.kind,
                                onAddWhatYouSaid: _lastSavedEntryIsDegraded
                                    ? () => unawaited(
                                        _openPendingTranscriptRecoveryForLastVoiceEntry(),
                                      )
                                    : null,
                                onCorrectTranscript:
                                    _lastSavedEntry != null &&
                                        !_lastSavedEntryIsDegraded &&
                                        TranscriptCorrectionGate.entryAllowsCorrection(
                                          _lastSavedEntry!,
                                        )
                                    ? () => unawaited(
                                        _openCorrectTranscriptForEntry(
                                          _lastSavedEntry!,
                                        ),
                                      )
                                    : null,
                                onAddMoreDetail:
                                    suppressLatestSaveArchiveInsight
                                    ? () => unawaited(
                                        navigateToTypeInsteadCapture(
                                          context,
                                          onSaved: _finishSuccessfulCapture,
                                        ),
                                      )
                                    : null,
                                onBackToRecord:
                                    showDegradedTranscriptFocusedPostSave
                                    ? _resetPostSaveToReady
                                    : entriesAfterSave.length == 1
                                    ? _resetPostSaveToReady
                                    : suppressLatestSaveArchiveInsight
                                    ? _resetPostSaveToReady
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              if (!suppressDegradedTranscriptPostSaveCompetitors) ...[
                                if (MomentQualityFeedbackGates.shouldShow(
                                  entry: entriesAfterSave.first,
                                  showFirstProofMoment: showFirstProofMoment,
                                  hierarchyAllowsFeedback:
                                      (postSaveArchiveHierarchy
                                              ?.showMomentQualityFeedback ??
                                          true) &&
                                      !showComeBackTomorrowV2PostSave,
                                )) ...[
                                  MomentQualityFeedbackCard(
                                    entry: entriesAfterSave.first,
                                  ),
                                ],
                                if (showFirstProofPayoff &&
                                    firstProofPayoffCandidate != null) ...[
                                  const SizedBox(height: 16),
                                  FirstProofPayoffCard(
                                    payoff: firstProofPayoffCandidate,
                                    entryCount: postSaveEntryCount,
                                    patternConfidence:
                                        firstProofPatternConfidence,
                                    suppressCtas:
                                        firstProofActionLoopContent != null,
                                    showProPackagingBridge:
                                        !showProBridgeVisibilityPostSave &&
                                        !showProEvidenceValuePostSave,
                                    onWatchThisNext:
                                        _handleFirstProofWatchThisNext,
                                    onViewPatternDetails:
                                        firstProofPayoffCandidate
                                            .canShowPatternDetail
                                        ? _openFirstProofPatternDetail
                                        : null,
                                  ),
                                  if (showBetaProofLiftOnFirstProofPayoff &&
                                      ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                                    const SizedBox(height: 12),
                                    BetaProofLiftCard(
                                      result: betaProofLiftFirstProofCandidate,
                                      source: 'record_post_save',
                                      surface: 'record_post_save_first_proof',
                                    ),
                                  ],
                                  if (showReturnAfterProofLiftV2OnPostSave) ...[
                                    const SizedBox(height: 12),
                                    ReturnAfterProofLiftV2Card(
                                      result:
                                          returnAfterProofLiftV2PostSaveCandidate,
                                      onPrimaryCta: () => unawaited(
                                        navigateToTypeInsteadCapture(
                                          context,
                                          prompt: _selectedPromptLine,
                                          onSaved: _finishSuccessfulCapture,
                                        ),
                                      ),
                                      onPromptSelected: (prompt) {
                                        setState(
                                          () => _selectedPromptLine = prompt,
                                        );
                                      },
                                    ),
                                  ] else if (showReturnAfterProofOnFirstProofPayoff) ...[
                                    const SizedBox(height: 12),
                                    ReturnAfterProofCard(
                                      result: returnAfterProofPostSaveCandidate,
                                      useStrengthenedLayout:
                                          showReturnAfterProofStrengthenedOnFirstProofPayoff,
                                      onPromptSelected: (prompt) {
                                        setState(
                                          () => _selectedPromptLine = prompt,
                                        );
                                      },
                                    ),
                                  ],
                                  if (showProUnderstandingLiftOnPostSave &&
                                      proUnderstandingLiftPostSaveResult !=
                                          null) ...[
                                    const SizedBox(height: 12),
                                    ProUnderstandingLiftCard(
                                      result:
                                          proUnderstandingLiftPostSaveResult,
                                      onSeePro: () =>
                                          _openProEvidenceValueSubscription(
                                            analyticsSource:
                                                'record_post_save_pro_understanding_lift',
                                          ),
                                    ),
                                  ] else if (showProVisibilityLiftOnPostSave &&
                                      proVisibilityLiftPostSaveResult !=
                                          null) ...[
                                    const SizedBox(height: 12),
                                    ProVisibilityLiftCard(
                                      result: proVisibilityLiftPostSaveResult,
                                      onSeePro: () =>
                                          _openProEvidenceValueSubscription(
                                            analyticsSource:
                                                'record_post_save_pro_visibility_lift',
                                          ),
                                    ),
                                  ] else if (showProPreviewPostSave &&
                                      proPreviewPostSaveResult != null) ...[
                                    const SizedBox(height: 12),
                                    ProPreviewCard(
                                      result: proPreviewPostSaveResult,
                                      onSeePro: () =>
                                          _openProEvidenceValueSubscription(
                                            analyticsSource:
                                                'record_post_save_pro_preview',
                                          ),
                                      onDismiss: () => unawaited(
                                        _dismissProEvidenceValueBridge(),
                                      ),
                                    ),
                                  ] else if (showProBridgeVisibilityPostSave &&
                                      proBridgeVisibilityPostSaveResult !=
                                          null) ...[
                                    const SizedBox(height: 12),
                                    ProBridgeVisibilityCard(
                                      result: proBridgeVisibilityPostSaveResult,
                                      onSeePro: () =>
                                          _openProEvidenceValueSubscription(
                                            analyticsSource:
                                                'record_post_save_pro_bridge_visibility',
                                          ),
                                      onDismiss: () => unawaited(
                                        _dismissProEvidenceValueBridge(),
                                      ),
                                    ),
                                  ],
                                  if (BetaProofFeedbackEngine.shouldShowOnFirstProofPayoff(
                                    showFirstProofPayoff: showFirstProofPayoff,
                                    firstProofPayoffVisible: true,
                                    entryCount: postSaveEntryCount,
                                    hasConfirmedRepeat:
                                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                          entriesAfterSave,
                                        ),
                                    isRecording: ui == RecordUiState.recording,
                                    isPostSaveDegraded:
                                        entriesAfterSave.isNotEmpty &&
                                        VoiceCaptureQuality.isDegradedVoiceCapture(
                                          entriesAfterSave.last,
                                        ),
                                    whatChangedQuestionActive:
                                        showWhatChangedV2,
                                    patternReviewInboxHasActiveItems:
                                        patternReviewInboxActivePostSave,
                                  ))
                                    BetaProofFeedbackRow(
                                      surface: BetaProofFeedbackSurface
                                          .firstProofPayoff,
                                      source: 'record_post_save',
                                      entryCount: postSaveEntryCount,
                                      hasConfirmedRepeat:
                                          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                            entriesAfterSave,
                                          ),
                                      parentVisible: true,
                                      isRecording:
                                          ui == RecordUiState.recording,
                                      isPostSaveDegraded:
                                          entriesAfterSave.isNotEmpty &&
                                          VoiceCaptureQuality.isDegradedVoiceCapture(
                                            entriesAfterSave.last,
                                          ),
                                      whatChangedQuestionActive:
                                          showWhatChangedV2,
                                      patternReviewInboxHasActiveItems:
                                          patternReviewInboxActivePostSave,
                                      onChanged: () => setState(() {}),
                                    ),
                                  if (showProofQualityResponseOnFirstProofPayoff) ...[
                                    const SizedBox(height: 12),
                                    ProofQualityResponseCard(
                                      result:
                                          proofQualityResponseFirstProofCandidate,
                                      source: 'record_post_save',
                                      onChanged: () => setState(() {}),
                                    ),
                                  ] else if (showProofSpecificityBoostOnFirstProofPayoff) ...[
                                    const SizedBox(height: 12),
                                    ProofSpecificityBoostCard(
                                      result:
                                          proofSpecificityBoostPostSaveCandidate,
                                      surface: ProofSpecificityBoostSurface
                                          .firstProofPayoff,
                                      source: 'record_post_save',
                                      hasConfirmedRepeat:
                                          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                            entriesAfterSave,
                                          ),
                                      proofKey:
                                          CurrentRelevanceStore.proofKeyFor(
                                            entriesAfterSave,
                                          ),
                                      onChanged: () => setState(() {}),
                                    ),
                                  ],
                                ],
                                if (showTimelineProofMomentOnFirstProofPayoff &&
                                    timelineProofMomentPostSaveCandidate !=
                                        null) ...[
                                  const SizedBox(height: 12),
                                  TimelineProofMomentCard(
                                    result:
                                        timelineProofMomentPostSaveCandidate,
                                    source: 'record_post_save_first_proof',
                                  ),
                                  if (showBetaProofLiftUnderTimelineProofPostSave &&
                                      ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                                    const SizedBox(height: 12),
                                    BetaProofLiftCard(
                                      result:
                                          betaProofLiftTimelinePostSaveCandidate,
                                      source: 'record_post_save_first_proof',
                                      surface: 'record_post_save_first_proof',
                                    ),
                                  ],
                                  if (BetaProofFeedbackEngine.shouldShow(
                                    surface: BetaProofFeedbackSurface
                                        .timelineProofMoment,
                                    parentVisible: true,
                                    entryCount: postSaveEntryCount,
                                    hasConfirmedRepeat:
                                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                          entriesAfterSave,
                                        ),
                                    isRecording: ui == RecordUiState.recording,
                                    isPostSaveDegraded:
                                        entriesAfterSave.isNotEmpty &&
                                        VoiceCaptureQuality.isDegradedVoiceCapture(
                                          entriesAfterSave.last,
                                        ),
                                    whatChangedQuestionActive:
                                        showWhatChangedV2,
                                    patternReviewInboxHasActiveItems:
                                        patternReviewInboxActivePostSave,
                                  ))
                                    BetaProofFeedbackRow(
                                      surface: BetaProofFeedbackSurface
                                          .timelineProofMoment,
                                      source: 'record_post_save_first_proof',
                                      entryCount: postSaveEntryCount,
                                      hasConfirmedRepeat:
                                          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                            entriesAfterSave,
                                          ),
                                      parentVisible: true,
                                      isRecording:
                                          ui == RecordUiState.recording,
                                      isPostSaveDegraded:
                                          entriesAfterSave.isNotEmpty &&
                                          VoiceCaptureQuality.isDegradedVoiceCapture(
                                            entriesAfterSave.last,
                                          ),
                                      whatChangedQuestionActive:
                                          showWhatChangedV2,
                                      patternReviewInboxHasActiveItems:
                                          patternReviewInboxActivePostSave,
                                      onChanged: () => setState(() {}),
                                    ),
                                  if (showProofQualityResponseOnTimelineProofPostSave) ...[
                                    const SizedBox(height: 12),
                                    ProofQualityResponseCard(
                                      result:
                                          proofQualityResponseTimelinePostSaveCandidate,
                                      source: 'record_post_save_first_proof',
                                      onChanged: () => setState(() {}),
                                    ),
                                  ] else if (showProofSpecificityBoostOnTimelineProofPostSave) ...[
                                    const SizedBox(height: 12),
                                    ProofSpecificityBoostCard(
                                      result:
                                          proofSpecificityBoostPostSaveCandidate,
                                      surface: ProofSpecificityBoostSurface
                                          .timelineProofMoment,
                                      source: 'record_post_save_first_proof',
                                      hasConfirmedRepeat:
                                          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                            entriesAfterSave,
                                          ),
                                      proofKey:
                                          CurrentRelevanceStore.proofKeyFor(
                                            entriesAfterSave,
                                          ),
                                      onChanged: () => setState(() {}),
                                    ),
                                  ],
                                  if (showBetaInviteLoopPostSave &&
                                      ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                                      betaInviteLoopPostSaveResult != null) ...[
                                    const SizedBox(height: 12),
                                    BetaInviteCard(
                                      result: betaInviteLoopPostSaveResult,
                                      onDismiss: () =>
                                          unawaited(_dismissBetaInviteLoop()),
                                    ),
                                  ],
                                ],
                                if (showProofSpecificityOnFirstProofPayoff &&
                                    proofSpecificityPostSaveCandidate
                                        .shouldShow) ...[
                                  const SizedBox(height: 12),
                                  ProofSpecificityCard(
                                    result: proofSpecificityPostSaveCandidate,
                                  ),
                                ] else if (showProEvidenceValuePostSave) ...[
                                  const SizedBox(height: 12),
                                  ProEvidenceValueCard(
                                    surface: ProEvidenceValueSurface
                                        .recordPostSaveAfterPayoff,
                                    entryCount: postSaveEntryCount,
                                    onSeePro: () =>
                                        _openProEvidenceValueSubscription(
                                          analyticsSource:
                                              'record_post_save_pro_evidence_value',
                                        ),
                                    onDismiss: () => unawaited(
                                      _dismissProEvidenceValueBridge(),
                                    ),
                                  ),
                                ] else if (showProLockMomentPostSave) ...[
                                  const SizedBox(height: 12),
                                  ProLockMomentCard(
                                    entryCount: postSaveEntryCount,
                                    hasFirstProof: true,
                                    hasConfirmedRepeat:
                                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                          entriesAfterSave,
                                        ),
                                    onSeePro: () =>
                                        _openProEvidenceValueSubscription(
                                          analyticsSource:
                                              'record_post_save_pro_lock_moment',
                                        ),
                                    onDismiss: () =>
                                        unawaited(_dismissProLockMoment()),
                                  ),
                                ] else if (showMonthlyPrivateReportPreviewPostSave &&
                                    monthlyPrivateReportPreviewPostSave !=
                                        null) ...[
                                  const SizedBox(height: 12),
                                  MonthlyPrivateReportPreviewCard(
                                    surface: MonthlyPrivateReportSurface
                                        .recordPostSaveAfterProof,
                                    entryCount: postSaveEntryCount,
                                    preview:
                                        monthlyPrivateReportPreviewPostSave,
                                    onSeePro: () =>
                                        _openProEvidenceValueSubscription(
                                          analyticsSource:
                                              'record_post_save_monthly_private_report_preview',
                                        ),
                                    onDismiss: () => unawaited(
                                      _dismissMonthlyPrivateReportPreview(),
                                    ),
                                  ),
                                ],
                                if (betaFeedbackIntelligenceSurfacePostSave !=
                                        null &&
                                    ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                                  const SizedBox(height: 12),
                                  BetaFeedbackIntelligenceCard(
                                    surface:
                                        betaFeedbackIntelligenceSurfacePostSave,
                                    entryCount: postSaveEntryCount,
                                    reachedFirstProof:
                                        showFirstProofPayoff &&
                                        firstProofPayoffCandidate != null,
                                    onSubmitted: () {
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                                if (showBetaFeedbackCapturePostSave &&
                                    ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                                    betaFeedbackCapturePostSaveResult !=
                                        null) ...[
                                  const SizedBox(height: 12),
                                  BetaFeedbackCaptureCard(
                                    result: betaFeedbackCapturePostSaveResult,
                                    proofFeedbackSurface:
                                        betaFeedbackCapturePostSaveResult
                                                .moment ==
                                            BetaFeedbackCaptureMoment
                                                .afterTimelineProof
                                        ? (showTimelineProofMomentOnFirstProofPayoff &&
                                                  timelineProofMomentPostSaveCandidate !=
                                                      null
                                              ? BetaProofFeedbackSurface
                                                    .timelineProofMoment
                                              : null)
                                        : null,
                                    onChanged: () => setState(() {}),
                                  ),
                                ],
                                if (showFirstProofTruth) ...[
                                  const SizedBox(height: 12),
                                  FirstProofTruthCard(
                                    proofKey: firstProofTruthProofKey,
                                    entryCount: postSaveEntryCount,
                                    hasSnippets:
                                        firstProofPayoffCandidate!.hasSnippets,
                                    onAnswered: () {
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                                if (firstProofActionLoopContent != null) ...[
                                  const SizedBox(height: 12),
                                  FirstProofActionLoopCard(
                                    content: firstProofActionLoopContent,
                                    entryCount: postSaveEntryCount,
                                    onWatchThisNext:
                                        _handleFirstProofWatchThisNext,
                                    onViewPatternDetails:
                                        firstProofActionLoopContent
                                            .canShowPatternDetails
                                        ? _openFirstProofPatternDetail
                                        : null,
                                    onRenamePattern:
                                        firstProofActionLoopContent
                                            .canRenamePattern
                                        ? _openFirstProofRenamePattern
                                        : null,
                                    onKeepRecording: _keepRecording,
                                    onCorrectTranscript:
                                        firstProofActionLoopContent
                                            .canCorrectTranscript
                                        ? () {
                                            final entry = entriesAfterSave.last;
                                            unawaited(
                                              _openCorrectTranscriptForEntry(
                                                entry,
                                              ),
                                            );
                                          }
                                        : null,
                                    onRemoveFromPattern:
                                        firstProofActionLoopContent
                                            .canRemoveFromPattern
                                        ? () => unawaited(
                                            _excludeLatestFromFirstProofPattern(),
                                          )
                                        : null,
                                    onOpenPatternCorrection:
                                        firstProofActionLoopContent
                                            .canShowPatternCorrection
                                        ? () => unawaited(
                                            _openFirstProofPatternCorrection(),
                                          )
                                        : null,
                                  ),
                                ],
                                if (confirmedRepeatTriggerPayoff != null) ...[
                                  const SizedBox(height: 16),
                                  ConfirmedRepeatTriggerPayoffCard(
                                    payoff: confirmedRepeatTriggerPayoff,
                                    analyticsSurface: 'record',
                                    entryCount: entriesAfterSave.length,
                                    entriesForWhy: entriesAfterSave,
                                    onKeepWatching: _resetPostSaveToReady,
                                    onViewEvidence: () => context.push(
                                      BeliefEvidenceNavigation.route,
                                    ),
                                  ),
                                ],
                                if (confirmedRepeatHelpfulActionPayoff !=
                                    null) ...[
                                  const SizedBox(height: 16),
                                  ConfirmedRepeatHelpfulActionPayoffCard(
                                    payoff: confirmedRepeatHelpfulActionPayoff,
                                    analyticsSurface: 'record',
                                    entryCount: entriesAfterSave.length,
                                    entriesForWhy: entriesAfterSave,
                                    onKeepWatching: _resetPostSaveToReady,
                                    onViewEvidence: () => context.push(
                                      BeliefEvidenceNavigation.route,
                                    ),
                                  ),
                                ],
                                if (confirmedRepeatChangeNotice != null) ...[
                                  const SizedBox(height: 16),
                                  ConfirmedRepeatChangeNoticeCard(
                                    notice: confirmedRepeatChangeNotice,
                                    analyticsSurface: 'record',
                                    entryCount: entriesAfterSave.length,
                                    entriesForWhy: entriesAfterSave,
                                    onRecordWhatHelped: () {
                                      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                                      setState(
                                        () => _selectedPromptLine =
                                            confirmedRepeatChangeNotice
                                                .guidedRecordPrompt,
                                      );
                                      _resetPostSaveToReady();
                                    },
                                    onViewEvidence: () => context.push(
                                      BeliefEvidenceNavigation.route,
                                    ),
                                  ),
                                ],
                                if (repeatReturnCheckOffer != null &&
                                    !showReturnCheckPayoff &&
                                    !showWhatChangedV2) ...[
                                  const SizedBox(height: 12),
                                  RepeatReturnCheckCard(
                                    entryId: repeatReturnCheckOffer.entryId,
                                    entryCount:
                                        repeatReturnCheckOffer.entryCount,
                                    surface: 'record',
                                    onChanged: () {
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                                if (postSaveArchiveHierarchy
                                        ?.showMomentQualityFeedback ??
                                    true)
                                  Builder(
                                    builder: (context) {
                                      if (suppressLatestSaveArchiveInsight) {
                                        return const SizedBox.shrink();
                                      }
                                      final returnTrigger =
                                          const CapacityReturnTriggerEngine()
                                              .buildFromJournal(
                                                entries: entriesAfterSave,
                                                capacityLoopActive:
                                                    _activeLoop
                                                        ?.isCapacityYes ??
                                                    false,
                                                capacityCohortActive: false,
                                                surface:
                                                    CapacityReturnTriggerSurface
                                                        .completion,
                                                sampleMode: false,
                                                screenshotMode:
                                                    ScreenshotMode.enabled,
                                              );
                                      if (!returnTrigger.showCard) {
                                        return const SizedBox.shrink();
                                      }
                                      return Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          CapacityReturnTriggerCard(
                                            result: returnTrigger,
                                            onPrimaryDismiss:
                                                _resetPostSaveToReady,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ],
                            if (postSaveArchiveHierarchy
                                        ?.showBeliefUpdateCard ==
                                    true &&
                                beliefUpdatePayoff != null &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !showFirstProofMoment &&
                                !showReturnCheckPayoff &&
                                !showWhatChangedV2) ...[
                              const SizedBox(height: 16),
                              BeliefUpdatePayoffCard(
                                payoff: beliefUpdatePayoff,
                                showInlineActions: false,
                                onAddAnother: _goToRecordTab,
                                onViewEvidence: () => context.push(
                                  BeliefEvidenceNavigation.route,
                                ),
                              ),
                            ],
                            if (postSaveArchiveHierarchy != null &&
                                postSaveArchiveHierarchy
                                    .showFocusedActionsBar &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards &&
                                !suppressEarlyRepeatPayoffCompetitors &&
                                !showFirstProofMoment &&
                                !showReturnCheckPayoff &&
                                !showWhatChangedV2) ...[
                              const SizedBox(height: 16),
                              PostSaveFocusedActionsBar(
                                onViewEvidence: () => context.push(
                                  BeliefEvidenceNavigation.route,
                                ),
                                onViewPatterns: () =>
                                    context.go('/archive-belief'),
                                onAddOneMoreMoment: _goToRecordTab,
                              ),
                            ],
                            if (returnLoopPayoff != null &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              DayTwoReturnLoopCard(
                                payoff: returnLoopPayoff,
                                onAddAnother: () =>
                                    unawaited(_onRecordPressed(source: 'main')),
                                onViewArchive: () =>
                                    context.go('/archive-belief'),
                                onReminderAccepted: () async {
                                  await RecordReturnProStore.instance()
                                      .markReturnCueResolved(
                                        RecordReturnProReturnCueMethod.reminder,
                                      );
                                  if (!mounted) return;
                                  setState(() {
                                    _offerDayTwoReminder = false;
                                    _recordReturnProState =
                                        _recordReturnProState?.copyWith(
                                          returnCueResolved: true,
                                          returnCueMethod:
                                              RecordReturnProReturnCueMethod
                                                  .reminder,
                                        );
                                  });
                                },
                                onReminderDeclined: () async {
                                  await RecordReturnProStore.instance()
                                      .markReturnCueResolved(
                                        RecordReturnProReturnCueMethod.localCue,
                                      );
                                  if (!mounted) return;
                                  setState(() {
                                    _offerDayTwoReminder = false;
                                    _recordReturnProState =
                                        _recordReturnProState?.copyWith(
                                          returnCueResolved: true,
                                          returnCueMethod:
                                              RecordReturnProReturnCueMethod
                                                  .localCue,
                                        );
                                  });
                                },
                              ),
                            ],
                            if (_languageCode != 'en') ...[
                              const SizedBox(height: 12),
                              LanguageIndicatorChip(
                                languageCode: _languageCode,
                                detectedCode: _detectedLanguageCode,
                                onSelected: _onLanguageSelected,
                              ),
                            ],
                            // Record → Return → Pro: evidence, return cue,
                            // Pro bridge — after the save succeeded, never blocking.
                            if (suppressNoisyRepeatPostSaveCards &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                postSaveDailyMirror != null &&
                                entriesAfterSave.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              RepeatPostSaveCard(
                                entry: entriesAfterSave.first,
                                allEntries: entriesAfterSave,
                                mirror: postSaveDailyMirror,
                                onViewEvidence: () => context.push(
                                  BeliefEvidenceNavigation.route,
                                ),
                                onAddOneMoreMoment: _goToRecordTab,
                                onDoneForToday: _resetPostSaveToReady,
                                onCorrectTranscript:
                                    _lastSavedEntry != null &&
                                        !_lastSavedEntryIsDegraded &&
                                        TranscriptCorrectionGate.entryAllowsCorrection(
                                          _lastSavedEntry!,
                                        )
                                    ? () => unawaited(
                                        _openCorrectTranscriptForEntry(
                                          _lastSavedEntry!,
                                        ),
                                      )
                                    : null,
                                onViewThoughtMap:
                                    repeatPostSaveThoughtMapPreview
                                            ?.shouldShow ==
                                        true
                                    ? () => context.go('/archive-belief')
                                    : null,
                              ),
                            ],
                            if (_saveReceipt != null &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              StartHereSaveReceiptCard(
                                receipt: _saveReceipt!,
                                onDismiss: () =>
                                    setState(() => _saveReceipt = null),
                              ),
                            ] else if (_suggestionProNudgeSource != null &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              _SuggestionProNudgeCard(
                                onUnlock: () {
                                  final source = _suggestionProNudgeSource!;
                                  setState(
                                    () => _suggestionProNudgeSource = null,
                                  );
                                  context.push(
                                    '/subscription',
                                    extra: PaywallRouteArgs(
                                      source: source,
                                      sourceRoute: '/record',
                                    ),
                                  );
                                },
                                onDismiss: () => setState(
                                  () => _suggestionProNudgeSource = null,
                                ),
                              ),
                            ],
                            if (_doneForTodayReceipt != null &&
                                _doneForTodayReceipt!.hasReceipt &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              DoneForTodayReceiptCard(
                                receipt: showFirstProofMoment
                                    ? _doneForTodayReceipt!.copyWith(
                                        archiveLine: '',
                                      )
                                    : _doneForTodayReceipt!,
                              ),
                              // 2-day path day-1 closure: only after the very
                              // first save, alongside (never instead of) the
                              // Done for today receipt.
                              Builder(
                                builder: (context) {
                                  final path = const TwoDayActivationEngine()
                                      .buildPostSave(
                                        entryCount: _journalEntryCount,
                                      );
                                  if (!path.show || returnLoopPayoff != null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: TwoDayActivationCard(path: path),
                                  );
                                },
                              ),
                              // One optional day-2 reminder offer — first save
                              // only, below (never instead of) the receipt. The
                              // First 60 return cue carries the same single
                              // reminder offer, so the two never show together.
                              if (_offerDayTwoReminder &&
                                  !_recordReturnCueVisible &&
                                  returnLoopPayoff == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: DayTwoReminderCard(),
                                ),
                              // Tomorrow's-check preview — passive, no CTA,
                              // safe labels only.
                              if (_dayTwoReturnPreview != null &&
                                  _dayTwoReturnPreview!.show &&
                                  returnLoopPayoff == null &&
                                  !justSavedFirstEntry &&
                                  !suppressNoisyFirstSaveCards)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: DayTwoReturnPreviewCard(
                                    preview: _dayTwoReturnPreview!,
                                    entryCount: _journalEntryCount,
                                  ),
                                ),
                            ],
                            if (_archiveProofCounter != null &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                PostSaveCompletionCopyGates.showArchiveProofCounter(
                                  counterHasProof:
                                      _archiveProofCounter!.hasProof,
                                  doneReceiptVisible:
                                      _doneForTodayReceipt != null &&
                                      _doneForTodayReceipt!.hasReceipt,
                                  suppressNoisyFirstSaveCards:
                                      suppressNoisyFirstSaveCards ||
                                      suppressNoisyRepeatPostSaveCards,
                                )) ...[
                              const SizedBox(height: 16),
                              ArchiveProofCounterCard(
                                counter: _archiveProofCounter!,
                              ),
                            ],
                            if (shareableProof != null &&
                                shareableProof.hasProof &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              ShareableArchiveProofCard(proof: shareableProof),
                            ],
                            if (_valueMomentBridge != null &&
                                _valueMomentBridge!.show &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              ValueMomentProBridge(
                                bridge: _valueMomentBridge!,
                                onSeePro: () {
                                  setState(() => _valueMomentBridge = null);
                                  context.push(
                                    '/subscription',
                                    extra: PaywallRouteArgs(
                                      source: PaywallSource.valueMoment,
                                      sourceRoute: '/record',
                                    ),
                                  );
                                },
                                onDismiss: () => setState(() {
                                  ValueMomentPaywallTrigger
                                          .dismissedThisSession =
                                      true;
                                  _valueMomentBridge = null;
                                }),
                              ),
                            ],
                            if (_showEvidenceContextTag &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              CaptureContextTagCard(
                                onSaveTag: _saveEvidenceContextTag,
                                onSkip: () => setState(
                                  () => _showEvidenceContextTag = false,
                                ),
                              ),
                            ],
                            if (stack.showInputQualityCoach &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              InputQualityCoachCard(
                                result: _inputQuality!,
                                originalText: _inputQualityText,
                                onAddSentence: _onInputQualityAddSentence,
                                onUseAnyway: _onInputQualityUseAnyway,
                                languageCode: _languageCode,
                              ),
                            ],
                            if (!stack.showInputQualityCoach &&
                                stack.showCompletedResult &&
                                _returnDayJustClosed &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              ReturnDayClosedCard(
                                resultHeadline:
                                    _completedCheckInToday!.resultHeadline,
                                usefulLine:
                                    _completedCheckInToday!.whatThisMeans,
                                nextCheck: _completedCheckInToday!
                                    .tomorrowsBetterQuestion,
                                onDone: () => setState(
                                  () => _returnDayJustClosed = false,
                                ),
                                onRecordAnother: _keepRecording,
                              ),
                              // First session never reaches here; only surface a fresh
                              // progress moment so the payoff stays one card deep.
                              if (stack.showArchiveProofCards &&
                                  _patternProgress != null) ...[
                                const SizedBox(height: 16),
                                PatternProgressAfterSaveCard(
                                  progress: _patternProgress!,
                                ),
                              ],
                            ] else if (!stack.showInputQualityCoach &&
                                stack.showCompletedResult &&
                                !suppressDegradedTranscriptPostSaveCompetitors &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards) ...[
                              const SizedBox(height: 16),
                              CheckInCompletedCard(
                                checkIn: _completedCheckInToday!,
                                weakInput: _weakInput,
                                languageCode: _languageCode,
                                betterResultIntensity:
                                    ScreenshotMode.screenshotBetterResult
                                    ? ScreenshotMode
                                          .screenshotBetterResultIntensity
                                    : ScreenshotMode.completedCheckInPreview
                                    ? HookRescueIntensity.elevated
                                    : _hookRescue?.intensityFor(
                                            HookRescueAction.betterResult,
                                          ) ??
                                          HookRescueIntensity.normal,
                                notUsefulReason: _hookRescueNotUsefulReason,
                                nextCheckSlot: stack.showResultNextCheck
                                    ? ResultNextCheckCard(
                                        checkIn: _completedCheckInToday!,
                                        notUsefulReason:
                                            _hookRescueNotUsefulReason,
                                        feedbackHint: _feedbackHint,
                                        showFeedback: stack.showFeedback,
                                        routineAnchorPicker:
                                            stack.showRoutineAnchor
                                            ? () => RoutineAnchorChooser.show(
                                                context,
                                              )
                                            : null,
                                        onRoutineAnchorChosen:
                                            stack.showRoutineAnchor
                                            ? (anchor) =>
                                                  RoutineAnchorStore.instance()
                                                      .saveForDate(
                                                        _tomorrowDateKey,
                                                        anchor,
                                                      )
                                            : null,
                                        onCreateCheckIn: (question) async {
                                          await TomorrowCheckInCoordinator.createForTomorrow(
                                            patternTitle:
                                                _completedCheckInToday!
                                                    .patternTitle,
                                            specificPrompt:
                                                _completedCheckInToday!.prompt,
                                            checkInQuestion: question,
                                          );
                                          final anchor =
                                              await RoutineAnchorStore.instance()
                                                  .loadForDate(
                                                    _tomorrowDateKey,
                                                  );
                                          final active =
                                              await TomorrowCheckInCoordinator.loadActive();
                                          if (active != null) {
                                            await RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
                                              active,
                                              hasRoutineAnchor: anchor != null,
                                            );
                                          }
                                          if (!mounted) return;
                                          setState(() {
                                            _retentionNextCheckJustChosen =
                                                true;
                                            _retentionDismissed = false;
                                            _activeCheckInForTomorrow = active;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              if (shouldShowKinderAngle(
                                _inputQualityText,
                                resultHint:
                                    _completedCheckInToday!.selectedOptionId ??
                                    'same',
                              ))
                                KinderAngleCard(
                                  reflectionText: _inputQualityText,
                                  resultHint:
                                      _completedCheckInToday!
                                          .selectedOptionId ??
                                      'same',
                                  patternTitle:
                                      _completedCheckInToday!.patternTitle,
                                  specificPrompt:
                                      _completedCheckInToday!.prompt,
                                  languageCode: _languageCode,
                                  compact: true,
                                )
                              else
                                PerspectiveShiftCard(
                                  reflectionText: _inputQualityText,
                                  resultHint:
                                      _completedCheckInToday!
                                          .selectedOptionId ??
                                      'same',
                                  checkInQuestion:
                                      _completedCheckInToday!.question,
                                  patternTitle:
                                      _completedCheckInToday!.patternTitle,
                                  specificPrompt:
                                      _completedCheckInToday!.prompt,
                                  languageCode: _languageCode,
                                  compact: true,
                                ),
                              if (stack.showArchiveProofCards &&
                                  _patternMemory != null) ...[
                                const SizedBox(height: 16),
                                PatternMemoryAfterSaveCard(
                                  memory: _patternMemory!,
                                  onUseNext:
                                      _patternNextAction == null &&
                                          !suppressPostResultNextCheckCompetitors
                                      ? () => _usePatternMemoryNext(
                                          _patternMemory!,
                                        )
                                      : null,
                                ),
                              ],
                              if (stack.showArchiveProofCards &&
                                  _patternProgress != null) ...[
                                const SizedBox(height: 16),
                                PatternProgressAfterSaveCard(
                                  progress: _patternProgress!,
                                ),
                              ],
                              if (stack.showArchiveProofCards &&
                                  _patternNextAction != null &&
                                  !suppressPostResultNextCheckCompetitors) ...[
                                const SizedBox(height: 16),
                                PatternNextActionCard(
                                  action: _patternNextAction!,
                                  onUse: () => _usePatternNextAction(
                                    _patternNextAction!,
                                  ),
                                ),
                              ],
                              if (stack.showArchiveProofCards &&
                                  _habitProof != null &&
                                  !suppressPostResultNextCheckCompetitors) ...[
                                const SizedBox(height: 16),
                                HabitProofCard(
                                  proof: _habitProof!,
                                  onKeepGoing: () =>
                                      _keepHabitProofGoing(_habitProof!),
                                ),
                              ],
                              if (stack.showArchiveProofCards &&
                                  _weeklyRecap != null) ...[
                                const SizedBox(height: 16),
                                WeeklyPatternRecapCard(
                                  recap: _weeklyRecap!,
                                  onUseNext:
                                      suppressPostResultNextCheckCompetitors
                                      ? null
                                      : () =>
                                            _useWeeklyRecapNext(_weeklyRecap!),
                                ),
                              ],
                              if (stack.showArchiveProofCards &&
                                  _shareRecap != null) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _copyShareRecap(_shareRecap!),
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).recordingCopyRecap,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            if (!stack.showInputQualityCoach &&
                                _tomorrowReturnLoop != null &&
                                !_returnDayJustClosed &&
                                !suppressNoisyFirstSaveCards &&
                                !suppressNoisyRepeatPostSaveCards &&
                                !suppressEarlyPatternClaimCards &&
                                !suppressEarlyRepeatPayoffCompetitors &&
                                !showFirstProofMoment &&
                                !showReturnCheckPayoff &&
                                !showWhatChangedV2) ...[
                              if (_secondSessionComparison?.hasEnoughData ==
                                      true &&
                                  secondSessionPayoff == null &&
                                  _postSaveComparisonController?.uiState
                                      is! ComparisonSuccess) ...[
                                const SizedBox(height: 12),
                                SecondSessionComparisonCard(
                                  comparison: _secondSessionComparison!,
                                  onGoDeeper: () {
                                    final prompt = _secondSessionComparison!
                                        .whatToTestNext;
                                    if (prompt == null || prompt.isEmpty) {
                                      return;
                                    }
                                    unawaited(_onSecondSessionEvidence(prompt));
                                  },
                                  onRecordNextEvidence: () {
                                    final prompt = _secondSessionComparison!
                                        .whatToTestNext;
                                    if (prompt == null || prompt.isEmpty) {
                                      return;
                                    }
                                    unawaited(_onSecondSessionEvidence(prompt));
                                  },
                                  onNotTheSame: () => setState(
                                    () => _secondSessionComparison = null,
                                  ),
                                ),
                              ],
                              if (!_patternHypothesisDismissed &&
                                  _patternHypothesis?.hasEnoughData ==
                                      true) ...[
                                const SizedBox(height: 12),
                                PatternHypothesisCard(
                                  hypothesis: _patternHypothesis!,
                                  onFeelsRight: () async {
                                    final selected =
                                        await SelectedSignalCoordinator.loadCurrent();
                                    if (selected != null) {
                                      await SignalFeedbackCoordinator.track(
                                        action: PostSaveSignalAction.accepted,
                                        signalId: selected.id,
                                        signalTitle: selected.title,
                                        categoryId: selected.categoryId,
                                      );
                                    }
                                    if (!mounted) return;
                                    setState(
                                      () => _patternHypothesisDismissed = true,
                                    );
                                  },
                                  onNotMe: () async {
                                    final selected =
                                        await SelectedSignalCoordinator.loadCurrent();
                                    if (selected != null) {
                                      await SignalFeedbackCoordinator.track(
                                        action: PostSaveSignalAction.rejected,
                                        signalId: selected.id,
                                        signalTitle: selected.title,
                                        categoryId: selected.categoryId,
                                      );
                                    }
                                    if (!mounted) return;
                                    setState(
                                      () => _patternHypothesisDismissed = true,
                                    );
                                  },
                                  onRecordNext: () => _keepRecording(
                                    nextEvidencePrompt:
                                        _patternHypothesis!.watchNext,
                                  ),
                                  onViewArchive: () =>
                                      context.go('/archive-belief'),
                                ),
                              ],
                              if (_postSavePattern != null) ...[
                                const SizedBox(height: 12),
                                PostSaveInsightChoiceCard(
                                  pattern: _postSavePattern!,
                                  entry: _lastSavedEntry,
                                  priorEntries: _entriesAfterSave.length > 1
                                      ? _entriesAfterSave.sublist(1)
                                      : const [],
                                  feedback: _postSaveInsightFeedback,
                                  selectedSignal: _postSaveSelectedSignal,
                                  audienceWedge: _audienceWedge,
                                  activeLoop: _activeLoop,
                                  reflectionCount: _entriesAfterSave.length
                                      .clamp(1, 3),
                                  categoryRepeated:
                                      _secondSessionComparison
                                          ?.possibleRepeat ==
                                      true,
                                  entryId: _lastSavedEntry?.id,
                                  onSaveSignal: (pattern) async {
                                    if (_isFirstSessionPostSave) {
                                      final thread =
                                          await FirstSessionCoordinator.acceptForTomorrow(
                                            pattern,
                                            reflectionText:
                                                _lastSavedEntry?.transcript ??
                                                '',
                                            sourceReflectionId:
                                                _lastSavedEntry?.id,
                                          );
                                      if (!mounted) return;
                                      if (TrialMode.enabled) {
                                        _watchForAcceptPending = false;
                                        await ActivationTracker.clearWatchForAcceptPending();
                                      }
                                      setState(
                                        () => _activePatternThread = thread,
                                      );
                                    }
                                  },
                                  onUsePrompt: _saveNextEvidencePrompt,
                                  onRecordNext: _keepRecording,
                                  onRecordNextEvidence: (prompt) =>
                                      _keepRecording(
                                        nextEvidencePrompt: prompt,
                                      ),
                                  onViewPatterns: () =>
                                      context.go('/archive-belief'),
                                ),
                              ] else if (_isFirstSessionPostSave) ...[
                                const SizedBox(height: 12),
                                FirstReflectionResultCard(
                                  onRecordAnother: _keepRecording,
                                  onViewPatterns: () =>
                                      context.go('/archive-belief'),
                                ),
                              ] else ...[
                                if (_activePatternThread != null &&
                                    _completedWatchForToday != null) ...[
                                  const SizedBox(height: 12),
                                  ActivePatternThreadCard(
                                    thread: _activePatternThread!,
                                    compact: true,
                                  ),
                                ],
                                if (_completedWatchForToday != null) ...[
                                  const SizedBox(height: 12),
                                  WatchForResultCard(
                                    completed: _completedWatchForToday!,
                                    headline: ScreenshotMode.enabled
                                        ? ScreenshotSampleData
                                              .watchForCompletedHeadline
                                        : null,
                                    body: ScreenshotMode.enabled
                                        ? ScreenshotSampleData
                                              .watchForCompletedBody
                                        : null,
                                  ),
                                ],
                                if (_postSavePattern == null) ...[
                                  const SizedBox(height: 12),
                                  PotentialSignalsCard(
                                    signals: _postSaveSignals(),
                                    noticedToday:
                                        _tomorrowReturnLoop!.noticedToday,
                                    showPatternHint:
                                        _postSaveShowsPossiblePattern(),
                                  ),
                                ],
                                if (_firstThreeJourney != null &&
                                    !_firstThreeJourney!.completed &&
                                    _showFirstThreeJourneyOnRecord) ...[
                                  const SizedBox(height: 12),
                                  FirstThreeJourneyCard(
                                    model: _firstThreeJourney!,
                                    compact: true,
                                  ),
                                ],
                                if (_showAdvancedRetentionPostSave) ...[
                                  if (_returnComparison != null) ...[
                                    const SizedBox(height: 12),
                                    ReturnComparisonCard(
                                      comparison: _returnComparison!,
                                    ),
                                  ],
                                  if (_returnStreak != null &&
                                      _journalEntryCount >= 2 &&
                                      _returnStreak!.currentStreakDays >=
                                          2) ...[
                                    const SizedBox(height: 12),
                                    ReturnStreakCard(
                                      streak: _returnStreak!,
                                      showCta: false,
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 12),
                                TomorrowReturnCard(loop: _tomorrowReturnLoop!),
                                if (_suggestedWatchForTomorrow != null) ...[
                                  const SizedBox(height: 12),
                                  WatchForTomorrowCard(
                                    suggestion: _suggestedWatchForTomorrow!,
                                    onChooseAnother: () {
                                      setState(() {
                                        _watchForAlternativeIndex =
                                            (_watchForAlternativeIndex + 1) % 3;
                                        _suggestedWatchForTomorrow =
                                            WatchForCoordinator.buildSuggestedWatchForAfterSave(
                                              entries: _entriesAfterSave,
                                              loop: _tomorrowReturnLoop,
                                              signals: _postSaveSignals(),
                                              alternativeIndex:
                                                  _watchForAlternativeIndex,
                                            );
                                      });
                                    },
                                  ),
                                ],
                                if (_showAdvancedRetentionPostSave) ...[
                                  const SizedBox(height: 16),
                                  TomorrowCommitmentCard(
                                    loop: _tomorrowReturnLoop!,
                                  ),
                                ],
                              ],
                            ],
                          ],
                          if (_localSaveTitle != null &&
                              !_lastSavedEntryIsDegraded) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: VoiceMemoryColors.captureSuccess,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localSaveTitle!,
                                        style:
                                            VoiceMemoryTypography.cardTitleStyle(
                                              color: VoiceMemoryColors
                                                  .captureSuccess,
                                            ),
                                      ),
                                      if (syncNote != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          syncNote,
                                          style: const TextStyle(
                                            color:
                                                VoiceMemoryColors.textSecondary,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 8),
                        if (showCoreValueFeedbackOnRecordPostFirstProof) ...[
                          CoreValueFeedbackCard(
                            source:
                                CoreValueFeedbackSource.recordPostFirstProof,
                            entryCount: postSaveEntryCount,
                            hasConfirmedRepeat: postSaveHasConfirmedRepeat,
                            hasFirstProof: postSaveHasFirstProof,
                            onChanged: () {
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showWhatChangedV2Display &&
                            whatChangedV2Display != null) ...[
                          WhatChangedV2Card(
                            key: ValueKey(whatChangedV2Display.entryId),
                            prompt: whatChangedV2Display,
                            source: 'record_post_save',
                            onSomethingHelped: () {
                              if (mounted) setState(() {});
                            },
                            onChanged: () {
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showHelpedTracking) ...[
                          HelpedTrackingCard(
                            key: ValueKey(helpedTrackingPrompt.entryId),
                            prompt: helpedTrackingPrompt,
                            source: 'record_post_save',
                            onChanged: () {
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showReturnCheckPayoff &&
                            returnCheckPayoffCandidate != null) ...[
                          ReturnCheckPayoffCard(
                            payoff: returnCheckPayoffCandidate,
                            entryCount: postSaveEntryCount,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showFirstWeekProgressPostSave &&
                            firstWeekProgressPostSave != null) ...[
                          FirstWeekProgressLine(
                            progress: firstWeekProgressPostSave,
                            entryCount: postSaveEntryCount,
                            surface: 'record_post_save',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (showPostSaveCuriosityHook &&
                            _postSaveCuriosityHook != null) ...[
                          ConnectedCuriosityHookCard.fromDomain(
                            hook: _postSaveCuriosityHook!,
                            sourceEntry: _lastSavedEntry,
                            onSubmit: (responseText, {required wasGrounded}) =>
                                _saveCuriosityHookResponse(
                                  hook: _postSaveCuriosityHook!,
                                  responseText: responseText,
                                  wasGrounded: wasGrounded,
                                ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!stack.showInputQualityCoach &&
                            _postSaveComparisonController != null &&
                            (_postSaveComparisonController!.uiState
                                    is ComparisonLoading ||
                                _postSaveComparisonController!.uiState
                                    is ComparisonSuccess)) ...[
                          _buildPostSaveSection(),
                          const SizedBox(height: 16),
                        ],
                        if (showComeBackTomorrowV2PostSave &&
                            !suppressNoisyRepeatPostSaveCards &&
                            !suppressDegradedTranscriptPostSaveCompetitors &&
                            comeBackTomorrowV2PostSaveWatch != null) ...[
                          ComeBackTomorrowCard(
                            watch: comeBackTomorrowV2PostSaveWatch,
                            entryCount: postSaveEntryCount,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showReturnTomorrowCuePostSave &&
                            !suppressNoisyRepeatPostSaveCards &&
                            !suppressDegradedTranscriptPostSaveCompetitors &&
                            returnTomorrowCuePostSave != null) ...[
                          ReturnTomorrowCueCard(
                            cue: returnTomorrowCuePostSave,
                            entryCount: postSaveEntryCount,
                            surface: 'record_post_save',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showPostSaveReturnHandoff &&
                            !suppressNoisyRepeatPostSaveCards &&
                            !suppressDegradedTranscriptPostSaveCompetitors &&
                            postSaveReturnHandoffCandidate != null) ...[
                          PostSaveReturnHandoffCard(
                            handoff: postSaveReturnHandoffCandidate,
                            entryCount: postSaveEntryCount,
                          ),
                          const SizedBox(height: 16),
                        ],
                        ..._buildBottomActions(
                          context,
                          ui: ui,
                          canRecord: canRecord,
                          localSaveTitle: localSaveTitle,
                          selectedPrompt: _selectedPromptLine,
                          suppressDuplicateRecordCtas:
                              stack.suppressDuplicateRecordCtas ||
                              suppressNoisyFirstSaveCards ||
                              (suppressNoisyRepeatPostSaveCards &&
                                  !showWhatChangedV2 &&
                                  !showWhatChangedV2Display) ||
                              showDegradedTranscriptFocusedPostSave,
                          showReturningWatchTargetFocusedUi:
                              showReturningWatchTargetFocusedUi,
                          policyMicPhase: policyMic,
                          policyUserDenied: policyUserDenied,
                          recordHomeSurface: recordHomeSurface,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (showCloseButton)
              const Align(
                alignment: Alignment.topRight,
                child: RecordScreenCloseButton(),
              ),
          ],
        ),
      ),
    );
  }

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

  List<Widget> _buildPolicyPrimarySecondaryButtons(
    RecordCtaPolicyResolution policy, {
    VoidCallback? onPrimary,
    Key? primaryKey,
  }) {
    final widgets = <Widget>[];
    final primary = policy.primaryLabel;
    if (primary == null || !policy.showMainBottomCta) return widgets;

    widgets.add(
      SizedBox(
        height: 48,
        width: double.infinity,
        child: FilledButton(
          key: primaryKey,
          onPressed: onPrimary ?? _resetPostSaveToReady,
          child: Text(primary),
        ),
      ),
    );

    for (final label in policy.secondaryLabels) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              if (label == ConsumerUiCopy.doneCta) {
                _resetPostSaveToReady();
                return;
              }
              if (label == VoiceCaptureCopy.recordAgainCta ||
                  label == ConsumerUiCopy.recordAnotherCta) {
                _resetPostSaveToReady();
                return;
              }
              _resetPostSaveToReady();
            },
            child: Text(label),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildBottomActions(
    BuildContext context, {
    required RecordUiState ui,
    required bool canRecord,
    required String? localSaveTitle,
    String? selectedPrompt,
    required bool suppressDuplicateRecordCtas,
    required bool showReturningWatchTargetFocusedUi,
    RecordingPhase? policyMicPhase,
    bool? policyUserDenied,
    RecordHomeSurfacePolicy recordHomeSurface = const RecordHomeSurfacePolicy(),
  }) {
    RecordCtaPolicyResolution policyForUi() => _recordCtaPolicy(
      ui,
      micPhase: policyMicPhase,
      userDeniedThisSession: policyUserDenied,
    );
    final actions = <Widget>[];

    if (ui == RecordUiState.permissionBlocked) {
      return actions;
    }
    if (ui == RecordUiState.ready) {
      if (showReturningWatchTargetFocusedUi) {
        return actions;
      }
      if (_showBottomRetentionCards) {
        // Invited User Welcome: replaces (never joins) the generic
        // first-session explainer for invited installs, so the pre-first-save
        // screen never gets more crowded. Only before the first save.
        final showInvitedWelcome =
            _invitedWelcomeSource != null && _journalEntryCount == 0;
        if (showInvitedWelcome) {
          actions.add(
            InvitedUserWelcomeCard(
              source: _invitedWelcomeSource!,
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() => _invitedWelcomeSource = null),
            ),
          );
        }
        // Record once intro: zero saved entries only — one supporting line
        // and one record CTA. Leads the stack but never blocks recording.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            RecordOnceIntroCard.shouldShow(_journalEntryCount)) {
          actions.add(
            RecordOnceIntroCard(
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First-session explainer: brand-new users (no entries / no pressure
        // check-ins yet) get a clear, emotionally framed starting point.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            FirstSessionExplanationCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSessionExplanationCard(
              onLogPressure: () => context.push('/pressure-check-in'),
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Save Rescue: a 10-second, deletable test recording for users
        // with an empty archive. One CTA into the existing recording flow —
        // sits alongside (never instead of) the explainer above.
        if (_showLegacyEmptyOnboarding &&
            FirstSaveRescueCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSaveRescueCard(
              onStart: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Recording Sample: one tiny editable starter sentence for an
        // empty archive. The CTA seeds the existing recording flow (the line
        // shows as the "Try saying" helper) — never a new flow, never a list.
        if (_showLegacyEmptyOnboarding &&
            FirstRecordingSampleCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstRecordingSampleCard(
              onUseStarter: () =>
                  _onStartHereSelected(FirstRecordingSample.sample),
            ),
          );
        }
        if (RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: _journalEntryCount,
          justSaved: _recordReturnProJustSaved,
          hiddenThisSession: RepeatRecordingNudgeSession.secondEntryHidden,
        )) {
          actions.add(
            SecondEntryNudgeCard(
              source: 'record',
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards &&
            AhaMomentGates.shouldShow(
              candidate: _ahaCandidate,
              entryCount: _journalEntryCount,
            )) {
          actions.add(
            FirstAhaMomentCard(
              candidate: _ahaCandidate!,
              source: 'record',
              onChanged: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards && AhaProofShareEligibility.shouldShow) {
          actions.add(
            AhaProofShareCard(
              entryCount: _journalEntryCount,
              source: 'record',
              onDismiss: () => setState(() {}),
            ),
          );
        }
        // Calm 2-day path: the plan before the first save, the return moment
        // on day 2, nothing once the loop is running. Passive — never blocks
        // recording.
        final twoDayPath = const TwoDayActivationEngine().build(
          entryCount: _journalEntryCount,
          entryDates: _entryDates,
        );
        if (twoDayPath.show && _showTwoDayActivationCard) {
          // Invited Day 2 return copy: the second visit matches the reason the
          // user was invited. Replaces (never joins) the generic Day 2 card so
          // the return moment never gets more crowded.
          if (InvitedDayTwoReturn.shouldShow(
            inviteSource: _inviteSource,
            stage: twoDayPath.stage,
          )) {
            actions.add(
              InvitedDayTwoReturnCard(
                source: _inviteSource!,
                entryCount: _journalEntryCount,
                onCheck: () => unawaited(_onRecordPressed(source: 'main')),
              ),
            );
          } else if (twoDayPath.stage == TwoDayActivationStage.dayTwoReturn &&
              RepeatRecordingNudgeGates.showDay2ReturnReason(
                entryCount: _journalEntryCount,
                twoDayPath: twoDayPath,
                hasRealChangeInsight: _hasRealChangeInsight,
                hiddenThisSession: RepeatRecordingNudgeSession.day2Hidden,
              )) {
            actions.add(
              Day2ReturnReasonCard(
                source: 'record',
                onRecord: () => unawaited(_onRecordPressed(source: 'main')),
                memoryOff: MemoryScopePolicy.scope == MemoryScope.off,
                onDismiss: () => setState(() {}),
              ),
            );
          } else if (twoDayPath.stage != TwoDayActivationStage.dayTwoReturn) {
            actions.add(TwoDayActivationCard(path: twoDayPath));
          }
        }
        // Change can begin: two or more entries, no real insight yet, and
        // the generic card has not been seen — passive, never blocks recording.
        if (_recordReturnProState != null &&
            RecordReturnProGates.showChangeCanBegin(
              entryCount: _journalEntryCount,
              changeStartSeen: _recordReturnProState!.changeStartSeen,
              hasRealChangeInsight: _hasRealChangeInsight,
            )) {
          actions.add(
            ChangeStartsCard(
              entryCount: _journalEntryCount,
              onViewArchive: () => context.go('/archive-belief'),
              onSearchArchive: () => context.go('/archive-belief'),
              onSeen: () => unawaited(_markChangeStartSeen()),
            ),
          );
        }
        // Day 7 continuity: after the Day 2 return (2+ entries), a calm note
        // on where the archive is — passive until the existing weekly review
        // is genuinely ready, then a single CTA into it. Never blocks
        // recording.
        final continuityLoop = const DaySevenContinuityEngine().build(
          entryCount: _journalEntryCount,
          hasWeeklyReview: _hasWeeklyReviewForContinuity,
        );
        if (continuityLoop.show && recordHomeSurface.showDaySevenContinuity) {
          actions.add(
            DaySevenContinuityCard(
              loop: continuityLoop,
              entryCount: _journalEntryCount,
              hasConnectedThread: _hasConnectedThreadForContinuity,
              onViewWeeklyReview: () => context.push('/pressure-insights'),
            ),
          );
        }
        // Compact return-trigger reminder for users who accepted it; never
        // shown alongside the first-session card.
        if (PressureReturnTriggerReminder.shouldShow(
              accepted: _returnTriggerAccepted,
              entryCount: _journalEntryCount,
            ) &&
            !showReturningWatchTargetFocusedUi) {
          actions.add(
            PressureReturnTriggerReminder(
              onLogPressure: () => context.push('/pressure-check-in'),
            ),
          );
        }
        if (recordHomeSurface.showEntryDirectionStarters) {
          actions.add(
            EntryDirectionStarters(
              selectedPrompt: _selectedPromptLine,
              onSelect: (prompt) {
                ActivationTracker.trackActivationStarterPromptSelected();
                setState(() => _selectedPromptLine = prompt);
              },
            ),
          );
          actions.add(const SizedBox(height: 8));
        }
      }
      final readyPolicy = policyForUi();
      final firstUseSimplifiedRecord =
          RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
          );
      if (!_shouldPromoteMicCaptureActions(readyPolicy) &&
          !firstUseSimplifiedRecord &&
          !showReturningWatchTargetFocusedUi) {
        actions.add(
          _buildCaptureEntryActions(
            context: context,
            selectedPrompt: selectedPrompt,
            policy: readyPolicy,
            suppressLogPressureMoment: showReturningWatchTargetFocusedUi,
          ),
        );
      }
      if (recordHomeSurface.showReturnRitual &&
          ReturnRitualGates.showOnRecord(
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
            isPostSave: _isPostSaveSurface,
            isReadyOrIdle: true,
          )) {
        actions.add(
          ReturnRitualCard(
            entryCount: _journalEntryCount,
            onAddMoment: () => unawaited(_onRecordPressed(source: 'main')),
          ),
        );
      }
      if (recordHomeSurface.showArchiveReturnChanges &&
          ArchiveReturnChangesGates.showOnRecord(
            loaded: _journalEntryCountLoaded,
            entryCount: _journalEntryCount,
            isPostSave: _isPostSaveSurface,
            sampleMode: false,
            result: _archiveReturnChangesResult,
          )) {
        actions.add(
          ArchiveReturnChangesCard(
            result: _archiveReturnChangesResult!,
            onMarkSeen: () => unawaited(_markArchiveReturnChangesSeen()),
          ),
        );
      }
      if (recordHomeSurface.showArchiveDepth &&
          ArchiveDepthGates.showCompactOnRecord(
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
            isPostSave: _isPostSaveSurface,
          )) {
        actions.add(
          ArchiveDepthCompactHint(
            result: const ArchiveDepthEngine().build(entries: _journalEntries),
          ),
        );
      }
      if (_journalEntryCountReady &&
          _journalEntryCount > 0 &&
          !showReturningWatchTargetFocusedUi) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
      if (_purchaseIntentCue != null &&
          _showBottomRetentionCards &&
          recordHomeSurface.showProBridge) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PurchaseIntentReturnCueCard(
              intent: _purchaseIntentCue!,
              onSeePro: () {
                final intent = _purchaseIntentCue!;
                setState(() => _purchaseIntentCue = null);
                context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source:
                        PaywallSource.fromId(intent.source) ??
                        PaywallSource.generalPro,
                    sourceRoute: '/record',
                  ),
                );
              },
              onDismiss: () => setState(() => _purchaseIntentCue = null),
            ),
          ),
        );
      }
    }
    if (ui == RecordUiState.recording) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _stopAndProcess,
            icon: const Icon(Icons.stop),
            label: Text(
              policyForUi().primaryLabel ?? ConsumerUiCopy.stopRecordingCta,
            ),
          ),
        ),
      );
      // Still changeable while recording — the choice applies at save.
      if (_journalEntryCountReady && _journalEntryCount > 0) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
    }
    // Fresh-entry receipt: only when the save carried "Treat this as new".
    if (ui == RecordUiState.done && TreatAsNew.lastSaveWasFresh) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: FreshEntrySavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        EntryAboutnessSession.lastSaveWasNonPersonal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: NotAboutMeReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasDoNotSurface) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: DoNotSurfaceReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasSensitive) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SensitiveSurfacingReceipt(),
        ),
      );
    }
    // Exact-evidence receipt: only when the save carried "Keep exact details".
    if (ui == RecordUiState.done && KeepExactDetails.lastSaveKeptExact) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ExactDetailsSavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        PreserveOriginalSession.lastSavePreservedOriginal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CuratedMemoryReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        ArchiveTrustReceipt.shouldShow(entryCount: _journalEntryCount) &&
        !_lastSavedEntryIsDegraded) {
      actions.add(
        ArchivePrivateReceiptCard(
          entryCount: _journalEntryCount,
          source: 'record',
          onDismiss: () => setState(() {}),
        ),
      );
    }
    if (_showPostSaveLoop && _tomorrowReturnLoop != null) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      );
    } else if (_showPostSaveLoop && _postSaveFollowUp != null) {
      actions.addAll([
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _enoughForNow,
            child: Text(AppLocalizations.of(context).recordingEnoughForNow),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      ]);
    }
    if (ui == RecordUiState.done && !_showPostSaveLoop) {
      final policy = policyForUi();
      if (policy.state == RecordCtaPolicyState.postSaveDegraded) {
        if (DegradedTranscriptPostSaveUiGates.suppressBottomPolicyCtas(
          showFocusedRecoverySurface:
              DegradedTranscriptPostSaveUiGates.showFocusedRecoverySurface(
                isDegradedPostSave: _lastSavedEntryIsDegraded,
              ),
        )) {
          actions.add(
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const Key('post_save_degraded_done_tertiary'),
                onPressed: _resetPostSaveToReady,
                child: const Text(ConsumerUiCopy.doneCta),
              ),
            ),
          );
        } else {
          actions.addAll(
            _buildPolicyPrimarySecondaryButtons(
              policy,
              primaryKey: const Key('post_save_type_what_you_said'),
              onPrimary: () =>
                  unawaited(_openPendingTranscriptRecoveryForLastVoiceEntry()),
            ),
          );
        }
      } else if (policy.state == RecordCtaPolicyState.postSaveSuccess) {
        if (!suppressDuplicateRecordCtas) {
          actions.addAll(_buildPolicyPrimarySecondaryButtons(policy));
        }
      }
    }
    if (ui == RecordUiState.error) {
      actions.addAll(_buildPolicyPrimarySecondaryButtons(policyForUi()));
    }
    if (!canRecord && ui == RecordUiState.idle) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _requestMic,
            child: const Text(MicrophonePermissionCopy.requestMicrophoneCta),
          ),
        ),
      );
      actions.add(const SizedBox(height: 8));
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            key: const Key('record_idle_type_instead_cta'),
            onPressed: () => unawaited(_typeInsteadFromPermission()),
            child: const Text(MicrophonePermissionCopy.typeInsteadCta),
          ),
        ),
      );
    }
    return actions;
  }
}

/// Gentle post-save Pro nudge shown after a recording that started from a
/// daily suggestion. Dismissible, shows at most once per session, and never
/// appears for Pro users or before three saved entries.
class _SuggestionProNudgeCard extends StatelessWidget {
  const _SuggestionProNudgeCard({
    required this.onUnlock,
    required this.onDismiss,
  });

  final VoidCallback onUnlock;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('suggestion_pro_nudge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your daily archive prompts improving',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ArchiveMe uses what you record to surface sharper things '
            'worth checking each day.',
            style: TextStyle(
              fontSize: 13,
              color: VoiceMemoryColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  // Compact override: the app-wide FilledButton theme is
                  // full-width, which cannot live inside this Row.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onUnlock,
                  child: const Text(
                    'Unlock Pro',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}
