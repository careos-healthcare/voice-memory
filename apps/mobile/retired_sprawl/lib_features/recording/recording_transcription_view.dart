part of 'recording_screen.dart';

/// Compact, semantics-aware status/transcription surface used while capture is
/// active. Keeping this independent prevents waveform repainting from owning
/// transcription presentation concerns.
class RecordingTranscriptionView extends StatelessWidget {
  const RecordingTranscriptionView({
    super.key,
    required this.text,
    this.isLive = false,
  });

  final String text;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: isLive,
      label: text,
      child: Text(
        text,
        key: const Key('recording_transcription_view'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// Screen actions owned by the transcription responsibility.
extension _RecordingTranscriptionStateActions on _RecordScreenState {
  Future<void> _typeInsteadFromPermission() async {
    await navigateToTypeInsteadCapture(
      context,
      prompt: _selectedPromptLine,
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openPendingTranscriptRecoveryForLastVoiceEntry() async {
    if (_entriesAfterSave.isEmpty) return;
    _recoveryController.showPendingTranscriptRecovery();
    final entry = _lastSavedEntry!;
    final result = await PendingTranscriptRecovery.open(
      context,
      entry: entry,
      source: 'record_post_save',
      entryCount: _entriesAfterSave.length,
    );
    _recoveryController.hidePendingTranscriptRecovery();
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(PendingTranscriptRecoveryCopy.savedSuccess)),
    );
    await _finishSuccessfulCapture(result);
  }

  Future<void> _retryRemoteProcessingForLastEntry() async {
    final entry = _lastSavedEntry;
    if (entry == null) return;
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return;
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) return;

    setState(() => _ui = RecordUiState.processing);
    try {
      final outcome = await _accountDeps.pipeline.run(
        audioFile: audioFile,
        durationSeconds: entry.durationSeconds,
      );
      if (!mounted) return;
      await outcome.match(
        (_) {
          setState(() {
            _ui = RecordUiState.done;
            _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
          });
        },
        (result) async {
          if (result.localSaved) {
            await _finishSuccessfulCapture(result);
          } else {
            setState(() {
              _ui = RecordUiState.done;
              _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
            });
          }
        },
      );
    } catch (_, stackTrace) {
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.done;
        _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
      });
    }
  }

  Future<void> _openCaptureMode(RecordCaptureMode mode) async {
    await navigateToCaptureMode(
      context,
      mode: mode,
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openFirstUseWordingOpening(FirstUseWordingPrompt prompt) async {
    await navigateToFirstUseWordingOpening(
      context,
      prompt: prompt,
      source: 'record',
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openCorrectTranscriptForEntry(JournalEntry entry) async {
    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: 'record_post_save_heard',
      entryCount: _journalEntryCount,
    );
    if (updated == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(TranscriptCorrectionCopy.savedSuccess)),
    );
    await _refreshAfterTranscriptCorrection(updated);
  }

  Future<void> _refreshAfterTranscriptCorrection(JournalEntry corrected) async {
    final all = await _accountDeps.journalStore.loadAll();
    if (!mounted) return;
    _setRecordingState(() {
      _journalEntries = all;
      _journalEntryCount = all.length;
      if (_entriesAfterSave.isNotEmpty &&
          _entriesAfterSave.first.id == corrected.id) {
        _entriesAfterSave = [corrected, ..._entriesAfterSave.skip(1)];
      }
    });
  }

  JournalEntry? get _lastSavedEntry =>
      _entriesAfterSave.isNotEmpty ? _entriesAfterSave.first : null;

  bool get _auditDegradedVoicePostSave {
    if (!VisualAuditOverrides.active) return false;
    return VisualAuditOverrides.peekRecordPresentation()
            ?.degradedVoicePostSave ==
        true;
  }

  bool get _lastSavedEntryIsDegraded =>
      _auditDegradedVoicePostSave ||
      VoiceCapturePostSave.showTypedFallbackPrimary(_lastSavedEntry);

  Future<void> _openLiveVoiceSession() async {
    _recordLog('live voice session requested');
    final result = await context.push<CapturePipelineResult?>(
      '/live-voice',
      extra: widget.liveVoiceCapture ?? _liveVoice,
    );
    if (!mounted || result == null) return;
    await _finishSuccessfulCapture(result);
  }

  Future<void> _stopAndProcess({bool reachedDurationLimit = false}) async {
    if (_stopAndProcessInFlight || _ui != RecordUiState.recording) return;
    _stopAndProcessInFlight = true;
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveStarted();
    }
    _setRecordingState(() {
      _ui = RecordUiState.processing;
      _stageLabel = reachedDurationLimit
          ? RecordingDurationPolicy.processingLabel
          : 'Stopping…';
    });
    try {
      final result = await _recording.stopRecording();
      _lastCaptureLikelySilentInput = result.likelySilentInput;
      final recordingExists = await result.file.exists();
      if (!recordingExists ||
          await result.file.length() < VoiceCaptureQuality.minAudioBytes) {
        if (recordingExists) {
          await result.file.delete();
        }
        throw CapturePipelineFailure(VoiceCaptureCopy.notEnoughAudio);
      }
      final stageSubscription = _accountDeps.pipeline.pipelineStates.listen(
        (state) {
          if (!mounted) return;
          _setRecordingState(() {
            _stageLabel = switch (state.stage) {
              PipelineStage.attesting => 'Uploading audio…',
              PipelineStage.transcribing => 'Transcribing…',
              PipelineStage.analyzing => 'Finding patterns…',
              PipelineStage.saving => 'Saving…',
              PipelineStage.done => 'Done',
            };
          });
        },
      );
      final pipelineOutcome = await _accountDeps.pipeline.run(
        audioFile: result.file,
        durationSeconds: result.durationSeconds,
      );
      await stageSubscription.cancel();
      if (!mounted) return;
      await pipelineOutcome.match(
        (failure) async {
          throw failure;
        },
        _finishSuccessfulCapture,
      );
    } on CapturePipelineFailure catch (e, stackTrace) {
      if (e.message == VoiceCaptureCopy.notEnoughAudio) {
        _setRecordingState(() {
          _ui = RecordUiState.ready;
          _error = e.message;
          _localSaveTitle = null;
          _syncNote = null;
          _stageLabel = '';
        });
        return;
      }
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.saveFailed;
        _localSaveTitle = null;
        _syncNote = null;
      });
    } on RecordingException {
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    } catch (e, stackTrace) {
      _setRecordingState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.saveFailed;
        _localSaveTitle = null;
        _syncNote = null;
      });
    } finally {
      _stopAndProcessInFlight = false;
      _syncNavigationActivity();
    }
  }

  Future<void> _finishSuccessfulCapture(
    CapturePipelineResult pipelineResult,
  ) async {
    final savedFromTriggerPrompt = ConfirmedRepeatTriggerCapture.resolveSave(
      capturePrompt: _selectedPromptLine,
    );
    final savedFromHelpfulActionPrompt = savedFromTriggerPrompt
        ? false
        : ConfirmedRepeatHelpfulActionCapture.resolveSave(
            capturePrompt: _selectedPromptLine,
          );
    final cloudOk = pipelineResult.syncSucceeded;
    final savedEntry = pipelineResult.entry;
    final all = await _accountDeps.journal.loadAll();
    final hasSavedTranscript = VoiceCaptureQuality.hasUsableSpokenText(
      savedEntry,
    );
    final state = buildArchiveStateObjectV3(entries: all);
    final priorEntries = all.length > 1
        ? all.sublist(1)
        : const <JournalEntry>[];
    final instantResponse = const InstantReflectionResponseEngine().respond(
      entry: savedEntry,
      priorEntries: priorEntries,
    );

    final prefs = _accountDeps.prefs;
    final discoveryFuture = const DailyDiscoveryEngine()
        .detectImmediateDiscovery(
          store: DailyDiscoveryStore(prefs),
          entries: all,
          state: state,
        );
    final evolutionFuture = const ArchiveEvolutionCoordinator()
        .detectAfterRecording(entries: all, state: state);
    final completedCheckIn = await TomorrowCheckInCoordinator.completeAfterSave(
      entries: all,
    );
    final patternMemory = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadActive()
        : null;
    final patternProgress = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestProgress()
        : null;
    final patternNextAction = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestNextAction()
        : null;
    final habitProof = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestHabitProof()
        : null;
    final weeklyRecap = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestWeeklyRecap()
        : null;
    final canShareRecap =
        completedCheckIn != null &&
        (weeklyRecap != null ||
            patternProgress != null ||
            (patternMemory != null && patternMemory.checkInCount >= 2));
    final shareRecap = canShareRecap
        ? await PatternMemoryCoordinator.buildShareRecap()
        : null;

    final latestReflectionText =
        resolveEntryDisplayText(savedEntry).text.isNotEmpty
        ? resolveEntryDisplayText(savedEntry).text
        : savedEntry.transcript;
    // Detect reflection language so post-save cards can speak the same
    // language. Screenshot mode forces a language for marketing captures.
    final detected = ScreenshotMode.language != null
        ? DetectedLanguage.userSelected(ScreenshotMode.languageCode)
        : detectReflectionLanguage(latestReflectionText);
    final languageCode = detected.uiLanguageCode;
    unawaited(
      ReflectionLanguageStore(
        _accountDeps.prefs,
      ).recordDetection(detected, originalText: latestReflectionText),
    );
    final inputQuality = assessReflectionQuality(latestReflectionText);
    unawaited(
      InputQualityStore(_accountDeps.prefs).recordAssessment(inputQuality),
    );

    if (!mounted) return;
    _setRecordingState(() {
      _ui = RecordUiState.done;
      _entriesAfterSave = all;
      // First 60 Seconds: usable first entry only — degraded voice waits for typed recovery.
      _recordReturnProJustSaved =
          all.length == 1 &&
          !VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry);
      _inputQuality = inputQuality;
      _inputQualityText = latestReflectionText;
      _inputQualityResolved = false;
      _languageCode = languageCode;
      _detectedLanguageCode = languageCode;
      _immediateDiscovery = null;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _firstSessionAlternativeIndex = 0;
      _completedCheckInToday = completedCheckIn;
      _patternMemory = patternMemory;
      _patternProgress = patternProgress;
      _patternNextAction = patternNextAction;
      _habitProof = habitProof;
      _weeklyRecap = weeklyRecap;
      _shareRecap = shareRecap;
      _dueCheckInToday = completedCheckIn != null ? null : _dueCheckInToday;
      _trackInstantReflectionSurfaced(instantResponse);
      _error = null;
      if (VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry)) {
        _localSaveTitle = null;
        _syncNote = null;
        _stageLabel = VoiceCaptureCopy.savedLocallyPendingTitle;
      } else if (!cloudOk &&
          hasSavedTranscript &&
          !pipelineResult.analysisSucceeded) {
        _localSaveTitle = VoiceCaptureCopy.recordingSavedTitle;
        _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
        _stageLabel = VoiceCaptureCopy.recordingSavedTitle;
      } else {
        _localSaveTitle = cloudOk
            ? null
            : CaptureSaveMessages.savedPrivatelyOnDevice;
        _syncNote = cloudOk
            ? null
            : ConsumerCopyGuard.userFacingSyncNote(pipelineResult.syncNote) ??
                  CaptureSaveMessages.addAnotherMomentTomorrow;
        _stageLabel = cloudOk
            ? 'Saved'
            : CaptureSaveMessages.savedPrivatelyOnDevice;
      }
      if (pipelineResult.attachedTypedTextToVoiceEntry) {
        RecordPipelineLog.typedFallbackInsightShown();
      }
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _entryDates = all.map((e) => e.createdAt).toList();
      _showPostSaveLoop = cloudOk;
      _lastCaptureAnalysisSucceeded = pipelineResult.analysisSucceeded;
      _lastCaptureLowQualityTranscript = pipelineResult.lowQualityTranscript;
      _postSaveFollowUp = null;
      _postSaveCuriosityHook = null;
      _savedFromConfirmedRepeatTrigger =
          EarlyFirstSignalEngine.buildTriggerCapturePayoff(
            entries: all,
            savedFromTriggerPrompt: savedFromTriggerPrompt,
          ) !=
          null;
      _savedFromHelpfulAction =
          !savedFromTriggerPrompt &&
          EarlyFirstSignalEngine.buildHelpfulActionPayoff(
                entries: all,
                savedFromHelpfulActionPrompt: savedFromHelpfulActionPrompt,
              ) !=
              null;
    });

    if (_savedFromConfirmedRepeatTrigger) {
      unawaited(EarlyEvidenceMilestoneStore.instance().markTriggerCaptured());
      if (mounted) {
        _setRecordingState(() => _earlyEvidenceTriggerCaptured = true);
      }
    }
    if (_savedFromHelpfulAction) {
      unawaited(
        EarlyEvidenceMilestoneStore.instance().markHelpfulActionCaptured(),
      );
      if (mounted) {
        _setRecordingState(() => _earlyEvidenceHelpfulCaptured = true);
      }
    }

    unawaited(_handleSuggestionAttributionAfterSave(all.length));
    unawaited(_buildDoneForTodayReceipt());

    // Keep a long-term Key Moment so this reflection (or closed loop) is easy
    // to find again by day. Original text is preserved verbatim.
    unawaited(
      KeyMomentCoordinator.captureAfterSave(
        reflectionText: latestReflectionText,
        patternTitle: completedCheckIn?.patternTitle,
        resultHint: completedCheckIn?.selectedOption?.comparisonHint,
        nextCheck: completedCheckIn?.question,
        languageCode: languageCode,
        source: completedCheckIn != null
            ? KeyMomentSource.checkIn
            : KeyMomentSource.reflection,
      ),
    );

    final discovery = await discoveryFuture;
    final evolution = await evolutionFuture;
    final returnLoop =
        await TomorrowReturnLoopCoordinator.persistAfterRecording(
          all,
          immediateDiscovery: discovery,
        );

    final eligibleCount = all
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .length;
    await ActivationTracker.trackReflectionMilestones(eligibleCount);
    unawaited(LoopModeCoordinator.onRecordingSaved());
    await ReturnReasonCaptureCoordinator.onReflectionSaved(
      eligibleCount: eligibleCount,
      lastReflectionAt: _lastReflectionAt,
    );
    if (eligibleCount == 1) {
      await ActivationTracker.trackActivationFirstSaveCompleted();
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveCompleted();
    }

    // Return day: recording a moment after answering closes the loop.
    if (completedCheckIn != null) {
      await ReturnDayFrictionCoordinator.markMomentSaved(completedCheckIn.id);
      await ReturnDayFrictionCoordinator.markLoopClosed(completedCheckIn.id);
    }

    if (all.isNotEmpty) {
      await FirstLoopActivationCoordinator.markFirstMomentSaved();
    }

    final firstSession = await FirstSessionCoordinator.isFirstSession(
      reflectionCount: all.length,
    );
    FirstSessionPattern? firstPattern;
    final latestHasComparableText =
        all.isNotEmpty &&
        !ComparableEvidenceText.entryHasPendingTranscript(all.last);
    if (firstSession && all.isNotEmpty && latestHasComparableText) {
      firstPattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      await FirstLoopActivationCoordinator.markFirstPatternShown(
        firstPattern.title,
      );
    }

    ReturnComparison? comparison;
    ReturnStreak? streak;
    WatchForItem? completedWatch;
    WatchForItem? suggestedWatch;
    ActivePatternThread? activeThread;
    SecondSessionComparison? secondComparison;
    FirstSessionPattern? postSavePattern;
    PatternHypothesis? patternHypothesis;

    if (firstSession && all.isNotEmpty && latestHasComparableText) {
      postSavePattern = firstPattern;
    } else if (all.isNotEmpty && latestHasComparableText) {
      postSavePattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive &&
          const SecondSessionSignalEngine().hasGroundedRepeatMatch(all)) {
        secondComparison = const SecondSessionSignalEngine().build(all);
      }
    }
    if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive &&
        ArchiveEvidenceQualityGate.allowsPatternHypothesis(all)) {
      patternHypothesis = await const PatternHypothesisEngine().build(all);
    }

    final postSaveFeedback = await SignalFeedbackStore.instance().loadAll();
    final postSaveSelected = await SelectedSignalCoordinator.loadCurrent();

    if (firstSession) {
      activeThread = await ActivePatternThreadCoordinator.loadCurrentThread();
    } else {
      completedWatch = await WatchForCoordinator.completePendingAfterSave(
        entries: all,
      );
      comparison = await ReturnComparisonCoordinator.buildAfterSaveIfDue(
        entries: all,
        loop: returnLoop,
      );
      suggestedWatch = returnLoop != null
          ? WatchForCoordinator.buildSuggestedWatchForAfterSave(
              entries: all,
              loop: returnLoop,
              signals: ArchiveBeliefsPresenter.potentialSignalsFromEntry(
                all.last,
              ),
              alternativeIndex: _watchForAlternativeIndex,
            )
          : null;
      streak = comparison != null
          ? await ReturnRetentionCoordinator.loadStreak()
          : null;
      activeThread = completedWatch != null
          ? await ActivePatternThreadCoordinator.loadCurrentThread()
          : await ActivePatternThreadCoordinator.loadCurrentThread();
    }

    if (!mounted) return;
    final postSaveCuriosityHook = await CuriosityHookCoordinator.instance()
        .persistAfterVoiceSave(savedEntry: savedEntry, allEntries: all);
    if (!mounted) return;
    _setRecordingState(() {
      _immediateDiscovery = discovery;
      _isFirstSessionPostSave = firstSession;
      _postSavePattern = postSavePattern ?? firstPattern;
      _postSaveInsightFeedback = postSaveFeedback;
      _postSaveSelectedSignal = postSaveSelected;
      _secondSessionComparison = secondComparison;
      _patternHypothesis = patternHypothesis;
      _patternHypothesisDismissed = false;
      _returnDayJustClosed = completedCheckIn != null;
      if (TrialMode.enabled && firstSession && firstPattern != null) {
        _watchForAcceptPending = true;
        unawaited(ActivationTracker.markWatchForAcceptPending());
      }
      _returnComparison = comparison;
      _returnStreak = streak;
      _tomorrowReturnLoop = returnLoop;
      _completedWatchForToday = completedWatch;
      _suggestedWatchForTomorrow = suggestedWatch;
      _pendingWatchForToday = null;
      _activePatternThread = activeThread;
      if (returnLoop != null) {
        _postSaveFollowUp = returnLoop.watchForNextTime;
      }
      _postSaveCuriosityHook = postSaveCuriosityHook;
      if (evolution != null) {
        _localSaveTitle = null;
        _stageLabel = '';
      }
    });
    unawaited(ProductAnalytics.trackStrings('immediate_discovery_surfaced', {
      'has_discovery': discovery != null ? 'yes' : 'no',
      if (discovery != null) 'type': discovery.type.name,
    }));
    unawaited(ProductAnalytics.trackStrings('archive_evolution_after_recording', {
      'has_evolution': evolution != null ? 'yes' : 'no',
      if (evolution != null) 'kind': evolution.kind.name,
    }));
    await _loadFirstThreeJourney();
    unawaited(_loadSignalArchive());
  }

  void _trackInstantReflectionSurfaced(InstantReflectionResponse? response) {
    unawaited(ProductAnalytics.trackStrings('instant_reflection_surfaced', {
      'has_response': response != null ? 'yes' : 'no',
      if (response != null) 'signal': response.signal.name,
    }));
  }

  bool get _showInputQualityCoach =>
      _inputQuality != null &&
      _inputQuality!.shouldAskForSharpening &&
      !_inputQualityResolved;

  bool get _weakInput =>
      _inputQuality != null && _inputQuality!.shouldAskForSharpening;

  void _onInputQualityUseAnyway() {
    _setRecordingState(() => _inputQualityResolved = true);
    unawaited(InputQualityStore(_accountDeps.prefs).recordAcceptedWeak());
  }

  void _onLanguageSelected(String code) {
    if (code == _languageCode) return;
    _setRecordingState(() => _languageCode = code);
    if (AppServices.isInitialized) {
      unawaited(
        ReflectionLanguageStore(_accountDeps.prefs).recordOverride(code),
      );
    }
  }

  Future<void> _onInputQualityAddSentence(String combinedText) async {
    final quality = assessReflectionQuality(combinedText);
    final store = InputQualityStore(_accountDeps.prefs);
    await store.recordSharpened();
    await store.recordAssessment(quality);
    if (!mounted) return;
    _setRecordingState(() {
      _inputQuality = quality;
      _inputQualityText = combinedText;
      _inputQualityResolved = true;
    });
  }
}