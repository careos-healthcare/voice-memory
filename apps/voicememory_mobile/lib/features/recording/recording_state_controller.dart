part of '../../screens/record_screen.dart';

/// Thin presentation adapter for the V1 recording application services.
class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  late final RecordingPermissionCoordinator _permission;
  late final CaptureSessionCoordinator _capture;
  late final ProtectedTemporaryAudioService _temporaryAudio;
  late final VaultPersistenceCoordinator _vaultPersistence;
  late final RemoteTranscriptionCoordinator _remoteTranscription;
  late final PostCaptureDispositionCoordinator _disposition;
  late final InterpretationDispositionCoordinator _interpretation;
  late final TranscriptEditingService _transcriptEditing;
  late final SaveMomentCoordinator _saveMoment;
  late PostSaveExperienceCoordinator _postSaveExperience;
  late final RecordingRecoveryService _recovery;
  late final StreamSubscription<TranscriptionQueueCompletion>
  _transcriptionSubscription;

  RecordUiState _ui = RecordUiState.idle;
  RecordingPhase _mic = RecordingPhase.idle;
  bool _requiresSettings = false;
  bool _stopInFlight = false;
  int _entryCount = 0;
  String? _error;
  String _stage = '';
  String? _recoveryMessage;
  SavedMomentResult? _lastSaved;
  PostSaveExperience? _postSave;
  final Set<String> _foregroundEntryIds = <String>{};
  bool _typeInsteadRequested = false;

  RecordNavigationActivityController get _navigation =>
      widget.navigationActivityController ?? recordNavigationActivityController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final services = AppServices.instance;
    _permission = RecordingPermissionCoordinator(
      recording: services.recording,
      gateway:
          widget.microphonePermissionGateway ??
          PermissionHandlerMicrophoneGateway(),
      stateStore:
          widget.onboardingMicStateStore ??
          OnboardingMicStateStore(services.prefs),
    );
    _capture = CaptureSessionCoordinator(recording: services.recording);
    _temporaryAudio = ProtectedTemporaryAudioService(
      vault: services.journalAudioVault,
    );
    _vaultPersistence = VaultPersistenceCoordinator(
      services.transcriptionLedger,
    );
    _remoteTranscription = RemoteTranscriptionCoordinator(
      disclosure: services.remoteTranscriptionDisclosure,
      executor: services.transcriptionQueueExecutor,
      schedule: services.transcriptionWorkScheduler.schedule,
    );
    final processingPreferences = ProcessingPreferencesStore(
      prefs: () => services.prefs,
      archiveId: () => services.journalStore.ownerArchiveId,
    );
    _disposition = PostCaptureDispositionCoordinator(
      vault: services.journalAudioVault,
      journal: () => services.journalStore,
      onDeviceEngine: services.onDeviceTranscription,
      disclosure: services.remoteTranscriptionDisclosure,
      remoteQueue: _vaultPersistence,
      // Draining through the coordinator keeps the account-transition
      // pause/resume hooks in charge of when work actually runs.
      startRemoteQueue: () async => _remoteTranscription.start(),
      onlineOnlyPreference: OnlineOnlyTranscriptionPreferenceStore(
        () => services.prefs,
      ),
      preferences: processingPreferences,
    );
    _interpretation = InterpretationDispositionCoordinator(
      journal: () => AppServices.instance.journalStore,
      runner: RemoteInterpretationAnalysisRunner(
        api: services.voiceCaptureApi,
        attest: services.attest,
      ),
      disclosure: services.remoteTranscriptionDisclosure,
      preferences: processingPreferences,
    );
    _transcriptEditing = TranscriptEditingService(services.journalStore);
    _saveMoment = SaveMomentCoordinator(services.journalStore);
    // Commercial state is read at save time, from the cache if the billing
    // module has not activated yet. Capture never waits on monetization.
    _postSaveExperience = const PostSaveExperienceCoordinator();
    _recovery = RecordingRecoveryService(
      temporaryAudio: SensitiveTemporaryAudioStore.production,
      ownerId: 'archive:${services.journalStore.ownerArchiveId}',
    );
    _transcriptionSubscription = _remoteTranscription.completions.listen(
      _onTranscriptionCompleted,
    );
    _capture.listen((_) {
      if (mounted) setState(() {});
    }, onLimit: () => _stopAndPersist(reachedDurationLimit: true));
    // A quick-capture result arrives here from an already committed save.
    if (widget.initialSavedResult != null) {
      services.capturePerformance.markSaveCommitted();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The first painted frame already carries a live Record action, so this
      // is the point capture becomes usable.
      AppServices.instance.capturePerformance.markRecordInteractive();
    });
    unawaited(
      _initialize().then((_) async {
        final initial = widget.initialSavedResult;
        if (initial != null && mounted) await _presentSavedResult(initial);
      }),
    );
  }

  Future<void> _initialize() async {
    await Future.wait<void>([_refreshPermission(), _refreshEntryCount()]);
    try {
      final snapshot = await _recovery.inspect();
      if (!mounted || !snapshot.hasRecoverableAudio) return;
      setState(() {
        _recoveryMessage =
            '${snapshot.recoverableCount} protected recording'
            '${snapshot.recoverableCount == 1 ? '' : 's'} waiting to recover.';
      });
    } on Object {
      // Recovery inspection never blocks a new capture.
    }
  }

  Future<void> _refreshEntryCount() async {
    final entries = await AppServices.instance.journalStore.loadAll();
    if (!mounted) return;
    setState(() => _entryCount = entries.length);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermission(afterResume: true));
    }
  }

  Future<void> _refreshPermission({bool afterResume = false}) async {
    try {
      final result = afterResume
          ? await _permission.refreshAfterResume()
          : await _permission.refresh();
      if (!mounted) return;
      _applyPermission(result);
    } on Object catch (error) {
      _showFailure(error);
    }
  }

  void _applyPermission(RecordingPermissionResult result) {
    setState(() {
      _mic = result.phase;
      _requiresSettings = result.requiresSettings;
      _ui = RecordingUiStateMapper.forPermission(
        result.phase,
        deniedByUser: result.deniedByUser,
      );
      _error = null;
    });
    _syncNavigation();
    if (widget.autostartWithPrompt && result.canRecord) {
      AppServices.instance.capturePerformance.markRecordTapped();
      unawaited(_startCapture());
    }
  }

  Future<void> _onRecordPressed() async {
    if (_stopInFlight) return;
    final performance = AppServices.instance.capturePerformance;
    performance.markRecordTapped();
    if (_mic == RecordingPhase.ready) {
      await _startCapture();
      return;
    }
    if (_requiresSettings ||
        _mic == RecordingPhase.permissionPermanentlyDenied) {
      await _openSettings();
      return;
    }
    setState(() {
      _ui = RecordUiState.requestingPermission;
      _stage = 'Waiting for microphone access…';
    });
    _syncNavigation();
    try {
      final result = await _permission.request();
      if (!mounted) return;
      _applyPermission(result);
      if (result.canRecord && _ui != RecordUiState.recording) {
        // The system permission sheet is the user's time, not the app's, so
        // the measured span restarts once access is resolved.
        performance.markRecordTapped();
        await _startCapture();
      }
    } on Object catch (error) {
      _showFailure(error);
    }
  }

  Future<void> _openSettings() async {
    final opened = await (widget.openAppSettings ?? openAppSettings)();
    if (opened) return;
    if (!mounted) return;
    setState(() => _error = MicrophonePermissionCopy.deniedBody);
  }

  Future<void> _startCapture() async {
    if (_ui == RecordUiState.recording || _stopInFlight) return;
    try {
      await _capture.start();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _ui = RecordUiState.recording;
        _stage = 'Recording';
        _error = null;
        _lastSaved = null;
        _postSave = null;
      });
      AppServices.instance.capturePerformance.markRecordingStarted();
      _syncNavigation();
    } on Object catch (error) {
      _showFailure(error);
    }
  }

  Future<void> _stopAndPersist({bool reachedDurationLimit = false}) async {
    if (_stopInFlight || _ui != RecordUiState.recording) return;
    _stopInFlight = true;
    AppServices.instance.capturePerformance.markStopTapped();
    setState(() {
      _ui = RecordUiState.processing;
      _stage = reachedDurationLimit ? 'Saving…' : 'Stopping…';
    });
    _syncNavigation();
    try {
      final recording = await _capture.stop();
      await _temporaryAudio.requireUsable(recording.file);
      if (mounted) setState(() => _stage = 'Saving audio safely…');
      final outcome = await _disposition.resolve(
        audio: recording.file,
        durationSeconds: recording.durationSeconds,
        requestChoice: _requestDisposition,
        requestRemoteDisclosure: _requestRemoteTranscriptionDisclosure,
        confirmDelete: _confirmDeleteRecording,
      );
      // Covers the dispositions that never open the choice sheet.
      AppServices.instance.capturePerformance.markLocalSaveComplete();
      if (!mounted) return;
      await _applyDispositionOutcome(outcome);
    } on Object catch (error) {
      AppServices.instance.capturePerformance.markCaptureAbandoned();
      _showFailure(error);
    } finally {
      _stopInFlight = false;
      _syncNavigation();
    }
  }

  Future<void> _applyDispositionOutcome(PostCaptureOutcome outcome) async {
    final typeInsteadRequested = _typeInsteadRequested;
    _typeInsteadRequested = false;
    if (outcome.kind == PostCaptureOutcomeKind.queuedForOnlineTranscription) {
      final entry = outcome.entry;
      if (entry != null) _foregroundEntryIds.add(entry.id);
    }
    if (outcome.kind == PostCaptureOutcomeKind.transcribedOnDevice &&
        outcome.entry != null) {
      await _presentSavedResult(
        CapturePipelineResult(
          entry: outcome.entry!,
          localSaved: true,
          syncSucceeded: false,
        ),
      );
      return;
    }
    if (typeInsteadRequested && outcome.entry != null && mounted) {
      _resetReady();
      final typed = await context.push<CapturePipelineResult>(
        '/quick-capture',
        extra: {'entryId': outcome.entry!.id, 'focusedRecordTypeEntry': true},
      );
      if (typed != null && mounted) {
        await _presentSavedResult(typed);
      } else {
        await _refreshEntryCount();
      }
      return;
    }
    _resetReady();
    await _refreshEntryCount();
    if (!mounted) return;
    final note = outcome.note;
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    }
  }

  Future<PostCaptureDisposition?> _requestDisposition(
    PostCaptureChoiceOptions options,
  ) async {
    // The audio is already sealed in the encrypted vault and committed to the
    // journal by the time this sheet is offered, so local persistence is done.
    AppServices.instance.capturePerformance.markLocalSaveComplete();
    if (!mounted) return null;
    return showPostCaptureChoiceSheet(context: context, options: options);
  }

  Future<bool> _confirmDeleteRecording() async {
    if (!mounted) return false;
    return showPostCaptureDeleteConfirmation(context: context);
  }

  Future<bool> _requestRemoteTranscriptionDisclosure() async {
    if (!mounted) return false;
    final result = await showRemoteTranscriptionDisclosure(
      context: context,
      store: AppServices.instance.remoteTranscriptionDisclosure,
    );
    _typeInsteadRequested =
        result == RemoteTranscriptionDisclosureAction.typeInstead;
    return result == RemoteTranscriptionDisclosureAction.continueOnline;
  }

  Future<void> _onTranscriptionCompleted(
    TranscriptionQueueCompletion completion,
  ) async {
    if (!_foregroundEntryIds.remove(completion.job.entryId)) return;
    await _presentSavedResult(completion.result);
  }

  Future<void> _presentSavedResult(CapturePipelineResult result) async {
    if (!mounted) return;
    setState(() {
      _ui = RecordUiState.processing;
      _stage = 'Saved. Finishing this moment…';
      _error = null;
    });
    _syncNavigation();
    var current = await _reviewTranscriptBeforeInterpretation(result);
    if (!mounted) return;
    final services = AppServices.instance;
    final subscription =
        services.subscriptionRepository.currentState ??
        await services.subscriptionRepository.loadCachedState() ??
        SubscriptionState.free();
    var productValue = const ProductValueState();
    var legacyGrandfathered = false;
    try {
      final migration = await MonetizationLocalMigration(
        services.prefs,
      ).run(subscription: subscription);
      productValue = migration.productValue;
      legacyGrandfathered = migration.legacyGrandfathered;
    } on Object {
      // Local commercial state must never block a saved user-owned moment.
    }
    if (!mounted) return;
    final interpretation = await _interpretation.resolveForNewCapture(
      entryId: current.entry.id,
      requestChoice: _requestInterpretationChoice,
      requestDisclosure: _requestInterpretationDisclosure,
      entitlement: EntitlementSnapshot.fromSubscriptionState(
        subscription,
        legacyGrandfathered: legacyGrandfathered,
      ),
      productValue: productValue,
    );
    if (!mounted) return;
    final interpretedEntry = interpretation.entry;
    if (interpretedEntry != null) {
      current = CapturePipelineResult(
        entry: interpretedEntry,
        localSaved: true,
        syncSucceeded: current.syncSucceeded,
        analysisSucceeded:
            interpretation.kind == InterpretationOutcomeKind.generated ||
            interpretation.kind == InterpretationOutcomeKind.alreadyPresent,
        syncNote: interpretation.note,
        attachedTypedTextToVoiceEntry: current.attachedTypedTextToVoiceEntry,
        lowQualityTranscript: current.lowQualityTranscript,
      );
    }
    final saved = await _saveMoment.conclude(current);
    await InsightFeedbackStore.ensureLoaded();
    final deliveryLedger = await ProductValueDeliveryRecorder.ensureLoaded();
    if (!mounted) return;
    _postSaveExperience = PostSaveExperienceCoordinator.forSubscription(
      subscription,
      productValue: productValue,
      deliveryLedger: deliveryLedger,
      legacyGrandfathered: legacyGrandfathered,
    );
    final experience = _postSaveExperience.build(
      saved,
      feedback: InsightFeedbackStore.cached,
    );
    if (!experience.hasConclusion) {
      unawaited(
        FocusedReturnAnalytics.noConclusionShown(FocusedReturnSurface.postSave),
      );
    }
    setState(() {
      _lastSaved = saved;
      _entryCount = saved.entries.length;
      _postSave = experience;
      _ui = RecordUiState.done;
      _stage = interpretation.note;
      _error = null;
    });
    final performance = services.capturePerformance;
    if (saved.entry.transcript.trim().isNotEmpty) {
      performance.markTranscriptVisible();
    }
    if (experience.hasConclusion) {
      performance.markFirstValidObservationVisible();
    }
    _syncNavigation();
  }

  Future<InterpretationDisposition?> _requestInterpretationChoice() async {
    if (!mounted) return null;
    return showInterpretationChoiceSheet(context: context);
  }

  Future<bool> _requestInterpretationDisclosure() async {
    if (!mounted) return false;
    final action = await showRemoteTranscriptionDisclosure(
      context: context,
      store: AppServices.instance.remoteTranscriptionDisclosure,
      purpose: RemoteProcessingPurpose.interpretation,
    );
    return action == RemoteTranscriptionDisclosureAction.continueOnline;
  }

  Future<CapturePipelineResult> _reviewTranscriptBeforeInterpretation(
    CapturePipelineResult result,
  ) async {
    final entry = result.entry;
    final transcript = entry.transcript.trim();
    if (!mounted ||
        entry.durationSeconds <= 0 ||
        result.attachedTypedTextToVoiceEntry ||
        transcript.isEmpty ||
        transcript.startsWith('[draft]') ||
        entry.reflection.explainableConclusion != null) {
      return result;
    }
    final controller = TextEditingController(text: entry.transcript);
    final reviewed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('post_transcription_review_dialog'),
        title: const Text('Review your transcript'),
        content: TextField(
          key: const Key('post_transcription_review_field'),
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
        ),
        actions: [
          FilledButton(
            key: const Key('post_transcription_review_continue'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    final text = reviewed?.trim();
    if (text == null || text.isEmpty || text == transcript) return result;
    final updated = await _transcriptEditing.replace(
      entry: entry,
      transcript: text,
    );
    return CapturePipelineResult(
      entry: updated,
      localSaved: true,
      syncSucceeded: result.syncSucceeded,
      analysisSucceeded: false,
      syncNote: result.syncNote,
      attachedTypedTextToVoiceEntry: result.attachedTypedTextToVoiceEntry,
      lowQualityTranscript: result.lowQualityTranscript,
    );
  }

  Future<void> _editTranscript() async {
    final saved = _lastSaved;
    if (saved == null) return;
    final controller = TextEditingController(text: saved.entry.transcript);
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit what you said'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    final updated = await _transcriptEditing.replace(
      entry: saved.entry,
      transcript: text,
    );
    final entries = await AppServices.instance.journalStore.loadAll();
    if (!mounted) return;
    final next = SavedMomentResult(
      entry: updated,
      entries: entries,
      analysisSucceeded: saved.analysisSucceeded,
      syncSucceeded: saved.syncSucceeded,
    );
    await InsightFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _lastSaved = next;
      _postSave = _postSaveExperience.build(
        next,
        feedback: InsightFeedbackStore.cached,
      );
    });
  }

  Future<void> _typeInstead() async {
    final result = await context.push<CapturePipelineResult>(
      '/quick-capture',
      extra: {
        'focusedRecordTypeEntry': true,
        if (widget.initialPrompt != null) 'prompt': widget.initialPrompt,
      },
    );
    if (result == null) {
      await _refreshEntryCount();
      return;
    }
    // Typed capture commits its own save; the clock for the post-save spans
    // starts when that result comes back.
    AppServices.instance.capturePerformance.markSaveCommitted();
    await _presentSavedResult(result);
  }

  void _showFailure(Object error) {
    if (!mounted) return;
    final mapped = RecordingUiStateMapper.failure(error);
    setState(() {
      _error = mapped.message;
      _stage = '';
      _ui = mapped.kind == RecordingFailureKind.insufficientAudio
          ? RecordUiState.ready
          : RecordUiState.error;
    });
    _syncNavigation();
  }

  void _resetReady() {
    _capture.reset();
    setState(() {
      _ui = RecordUiState.ready;
      _stage = '';
      _error = null;
      _postSave = null;
      _lastSaved = null;
    });
    _syncNavigation();
  }

  void _syncNavigation() {
    final activity = switch (_ui) {
      RecordUiState.requestingPermission =>
        RecordNavigationActivity.requestingPermission,
      RecordUiState.recording => RecordNavigationActivity.recording,
      RecordUiState.processing => RecordNavigationActivity.processing,
      _ => RecordNavigationActivity.idle,
    };
    _navigation.update(activity);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_transcriptionSubscription.cancel());
    unawaited(_capture.dispose());
    _navigation.update(RecordNavigationActivity.idle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          key: const Key('record_screen_scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              sliver: SliverList.list(
                children: [
                  Text(
                    'Record a moment',
                    key: const Key('record_screen_framing_title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _entryCount == 0
                        ? 'Ten seconds is enough. You can edit the transcript before keeping it.'
                        : 'Add one real moment to your private archive.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _buildPrimarySurface(theme),
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      key: const Key('recording_error_message'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (_recoveryMessage case final message?) ...[
                    const SizedBox(height: 12),
                    Text(message, key: const Key('recording_recovery_message')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          context.push(RouteCatalog.recordingRecovery),
                      child: const Text('Review unsaved recordings'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildActions(),
                  if (_postSave != null) ...[
                    const SizedBox(height: 24),
                    _buildConclusion(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimarySurface(ThemeData theme) {
    return Container(
      key: const Key('recording_primary_surface'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            _ui == RecordUiState.recording ? Icons.mic : Icons.mic_none,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            _ui == RecordUiState.recording
                ? _formatDuration(_capture.seconds)
                : _stage.isEmpty
                ? 'Ready when you are'
                : _stage,
            style: theme.textTheme.titleLarge,
          ),
          if (_ui == RecordUiState.processing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_ui == RecordUiState.recording) {
      return FilledButton.icon(
        key: const Key('recording_stop_cta'),
        onPressed: _stopAndPersist,
        icon: const Icon(Icons.stop),
        label: const Text('Stop and save'),
      );
    }
    if (_ui == RecordUiState.processing ||
        _ui == RecordUiState.requestingPermission) {
      return const SizedBox.shrink();
    }
    if (_ui == RecordUiState.done) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('capture_entry_record_cta'),
            onPressed: _onRecordPressed,
            icon: const Icon(Icons.mic),
            label: Text(
              _requiresSettings
                  ? MicrophonePermissionCopy.openSettingsCta
                  : 'Start recording',
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('record_idle_type_instead_cta'),
          onPressed: _typeInstead,
          child: const Text('Type instead'),
        ),
      ],
    );
  }

  Widget _buildConclusion(ThemeData theme) {
    return FocusedAuditablePostSaveSection(
      experience: _postSave!,
      onEditTranscript: _editTranscript,
      onOpenSavedMoment: () {
        final entryId = _postSave!.entry.id;
        context.push('/entry/$entryId');
      },
      onRecordNext: (_) => _resetReady(),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
