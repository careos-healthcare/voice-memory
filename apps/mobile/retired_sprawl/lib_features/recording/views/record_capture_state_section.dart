part of '../recording_screen.dart';

extension RecordCaptureStateSection on _RecordScreenState {
  bool _usesV1MomentSaveReceipt(RecordBuildContext ctx) {
    return V1FeatureFlags.enableV1Only &&
        ctx.ui == RecordUiState.done &&
        ctx.entriesAfterSave.isNotEmpty;
  }

  List<Widget> _buildRecordCaptureStateSection(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
      if (ctx.ui == RecordUiState.recording) ...[
        _RecordingStatusCard(stageLabel: ctx.stageLabel),
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
        if (ctx.ui == RecordUiState.ready &&
            _showReadyToRecordStatus &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          Semantics(
            label: 'Recording status',
            child: Text(
              ctx.stageLabel.isEmpty
                  ? _statusTextFor(ctx.ui, ctx.localSaveTitle!)
                  : ctx.stageLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
        if (ctx.ui == RecordUiState.processing) ...[
          const SizedBox(height: 12),
          PostSaveListeningCard(stageLabel: ctx.stageLabel),
        ],
        if (_selectedPromptLine != null &&
            _showBottomRetentionCards &&
            !ctx.showReturningWatchTargetFocusedUi &&
            (ctx.ui == RecordUiState.ready ||
                ctx.ui == RecordUiState.recording)) ...[
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
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.recordHomeSurface.showNextEvidencePrompt &&
            _nextEvidencePrompt != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warmSurface,
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
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
            ctx.stack.showActivePatternThread &&
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
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
            ctx.stack.showFirstThreeJourney &&
            _firstThreeJourney != null &&
            _firstThreeJourney!.showOnRecord &&
            _showFirstThreeJourneyOnRecord) ...[
          const SizedBox(height: 12),
          FirstThreeJourneyCard(model: _firstThreeJourney!),
        ],
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
            _postSavePattern == null &&
            !ctx.stack.showReturnDayJourneyCard &&
            _showRetentionJourneyCards &&
            _signalJourney != null &&
            _signalJourney!.isActive) ...[
          const SizedBox(height: 12),
          SignalJourneyCard(
            journey: _signalJourney!,
            activeLoop: _activeLoop,
            compact: true,
          ),
        ] else if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
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
        ] else if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
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
        ] else if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
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
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveProgressCards &&
            ctx.stack.showPendingWatchFor &&
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
        if (ctx.ui == RecordUiState.ready &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.recordHomeSurface.showOneSmallRecordingCard &&
            ctx.stack.showStarterPrompts &&
            ctx.recordHomeSurface.showWorthCheckingToday) ...[
          if (_oneSmallRecording.hasRecording) ...[
            const SizedBox(height: 12),
            OneSmallRecordingCard(
              recording: _oneSmallRecording,
              showRecordCta: !_shouldHideCardRecordButtons(
                ctx.ui,
              ),
              ctaLabel:
                  _recordCtaPolicy(
                    ctx.ui,
                    micPhase: ctx.policyMic,
                    userDeniedThisSession: ctx.policyUserDenied,
                  ).primaryLabel ??
                  OneSmallRecording.recordCtaLabel,
              onRecordThis: (p) {
                unawaited(ActivationTracker.trackActivationStarterPromptSelected());
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
              ctx.recordHomeSurface.showWorthCheckingToday) ...[
            const SizedBox(height: 12),
            DailyReturnSuggestionsCard(
              suggestionSet: _dailyReturnSuggestions,
              selectedPrompt: _selectedPromptLine,
              onSuggestionTap: _onDailySuggestionTapped,
              onSelectPrompt: (p) {
                unawaited(ActivationTracker.trackActivationStarterPromptSelected());
                setState(() => _selectedPromptLine = p);
              },
            ),
          ],
          if (ctx.recordHomeSurface.showTrySayingPrompts) ...[
            const SizedBox(height: 12),
            ConsumerRecordPromptsSection(
              selectedPrompt: _selectedPromptLine,
              personalPrompts: _personalReturnPrompts,
              deemphasized: _oneSmallRecording.hasRecording,
              onSelectPrompt: (p) {
                unawaited(ActivationTracker.trackActivationStarterPromptSelected());
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
        ..._buildRecordPostSaveCards(context, ctx),
        if (ctx.error! != null) ...[
          const SizedBox(height: 12),
          Text(
            ctx.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
      const SizedBox(height: 8),
      if (!_usesV1MomentSaveReceipt(ctx)) ...[
      if (ctx.showCoreValueFeedbackOnRecordPostFirstProof) ...[
        CoreValueFeedbackCard(
          source:
              CoreValueFeedbackSource.recordPostFirstProof,
          entryCount: ctx.postSaveEntryCount,
          hasConfirmedRepeat: ctx.postSaveHasConfirmedRepeat,
          hasFirstProof: ctx.postSaveHasFirstProof,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 16),
      ],
      if (ctx.showWhatChangedV2Display &&
          ctx.whatChangedV2Display! != null) ...[
        WhatChangedV2Card(
          key: ValueKey(ctx.whatChangedV2Display!.entryId),
          prompt: ctx.whatChangedV2Display!,
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
      if (ctx.showHelpedTracking && ctx.helpedTrackingPrompt! != null) ...[
        HelpedTrackingCard(
          key: ValueKey(ctx.helpedTrackingPrompt!.entryId),
          prompt: ctx.helpedTrackingPrompt!,
          source: 'record_post_save',
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 16),
      ],
      if (ctx.showReturnCheckPayoff &&
          ctx.returnCheckPayoffCandidate! != null) ...[
        ReturnCheckPayoffCard(
          payoff: ctx.returnCheckPayoffCandidate!,
          entryCount: ctx.postSaveEntryCount,
        ),
        const SizedBox(height: 16),
      ],
      if (ctx.showFirstWeekProgressPostSave &&
          ctx.firstWeekProgressPostSave! != null) ...[
        FirstWeekProgressLine(
          progress: ctx.firstWeekProgressPostSave!,
          entryCount: ctx.postSaveEntryCount,
          surface: 'record_post_save',
        ),
        const SizedBox(height: 12),
      ],
      if (ctx.showPostSaveCuriosityHook &&
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
      if (ctx.showComeBackTomorrowV2PostSave &&
          !ctx.suppressNoisyRepeatPostSaveCards &&
          !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
          ctx.comeBackTomorrowV2PostSaveWatch! != null) ...[
        ComeBackTomorrowCard(
          watch: ctx.comeBackTomorrowV2PostSaveWatch!,
          entryCount: ctx.postSaveEntryCount,
        ),
        const SizedBox(height: 16),
      ],
      if (ctx.showReturnTomorrowCuePostSave &&
          !ctx.suppressNoisyRepeatPostSaveCards &&
          !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
          ctx.returnTomorrowCuePostSave! != null) ...[
        ReturnTomorrowCueCard(
          cue: ctx.returnTomorrowCuePostSave!,
          entryCount: ctx.postSaveEntryCount,
          surface: 'record_post_save',
        ),
        const SizedBox(height: 16),
      ],
      if (ctx.showPostSaveReturnHandoff &&
          !ctx.suppressNoisyRepeatPostSaveCards &&
          !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
          ctx.postSaveReturnHandoffCandidate! != null) ...[
        PostSaveReturnHandoffCard(
          handoff: ctx.postSaveReturnHandoffCandidate!,
          entryCount: ctx.postSaveEntryCount,
        ),
        const SizedBox(height: 16),
      ],
      ],
    ];
  }
}
