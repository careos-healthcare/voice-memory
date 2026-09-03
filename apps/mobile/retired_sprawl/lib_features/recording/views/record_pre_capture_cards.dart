part of '../recording_screen.dart';

extension RecordPreCaptureCards on _RecordScreenState {
  List<Widget> _buildRecordPreCaptureCards(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
      if (kDebugMode)
        SizedBox(
          key: ValueKey(
            'record_empty_gate_${_journalEntryCount}_'
            '$_journalEntryCountLoaded',
          ),
          width: 0,
          height: 0,
        ),
      if (ctx.firstUseSimplifiedRecord &&
          ctx.ui == RecordUiState.ready &&
          _journalEntryCountReady) ...[
        RecordFirstRunScreenCard(
          onRecord: () =>
              unawaited(_onRecordPressed(source: 'main')),
          recordButtonLabel: _recordEntryCtaLabel(
            ctx.readyCapturePolicy,
          ),
          onTextThoughtSaved: _finishSuccessfulCapture,
        ),
      ] else if (ctx.showFirstSessionOnboarding) ...[
        FirstSessionOnboardingCard(
          onStartMoment: () =>
              unawaited(_onRecordPressed(source: 'main')),
          onExploreFirst: () =>
              unawaited(_dismissFirstSessionOnboarding()),
        ),
        const SizedBox(height: 16),
      ] else if (ctx.showFraming &&
          ctx.ui == RecordUiState.ready &&
          _journalEntryCountReady &&
          _journalEntryCount == 0) ...[
        const RecordTopArchivePromiseHero(),
        const SizedBox(height: 16),
      ],
      if (ctx.showTesterMissionFull &&
          ctx.testerMission != null &&
          !ctx.showReturningWatchTargetFocusedUi) ...[
        TesterMissionCard(
          mission: ctx.testerMission!,
          onDismissed: () => setState(() {}),
        ),
        const SizedBox(height: 12),
      ],
      if (ctx.recordHomeSurface.showDailyMapPrompt &&
          ctx.dailyArchiveExercise != null &&
          !ctx.showReturningWatchTargetFocusedUi) ...[
        DailyArchiveExerciseRecordCard(
          exercise: ctx.dailyArchiveExercise!,
          onPrimary: () => _handleDailyArchiveExerciseAction(
            ctx.dailyArchiveExercise!.primaryRoute,
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (ctx.showReturningWatchTargetFocusedUi &&
          ctx.dailyArchiveMemoryCandidate != null) ...[
        DailyArchiveMemoryCard(
          memory: ctx.dailyArchiveMemoryCandidate!,
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
      if (ctx.showReturningWatchTargetFocusedUi &&
          _journalEntryCountReady &&
          ReturningRecordWatchTargetUiGates.showProUpgradePromptOnReturn(
            entryCount: _journalEntryCount,
          ) &&
          ctx.showProBridgeBelowProofOnRecord &&
          ctx.proBridgeVisibilityRecordResult != null) ...[
        ProBridgeVisibilityCard(
          result: ctx.proBridgeVisibilityRecordResult!,
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
                ctx.showReturningWatchTargetFocusedUi,
          )) ...[
        if (ctx.ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            _journalEntryCount == 0 &&
            _showFirstRunPrivacyReassurance &&
            !ctx.firstUseSimplifiedRecord) ...[
          const RecordFirstRunPrivacyReassurance(),
          const SizedBox(height: 12),
        ],
        if (ctx.showFraming &&
            ctx.stack.showFramingTitle &&
            !ctx.showReturningWatchTargetFocusedUi &&
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
        if (ctx.recordHomeSurface.showReturningUserToday &&
            ctx.returningUserToday != null &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          ReturningUserTodayCard(
            model: ctx.returningUserToday!,
            onPrimary: () => _handleReturningUserTodayAction(
              ctx.returningUserToday!.primaryAction,
            ),
            onSecondary: () =>
                _handleReturningUserTodayAction(
                  ctx.returningUserToday!.secondaryAction,
                ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.recordHomeSurface.showNextMomentPrompt &&
            ctx.nextMomentPrompt != null &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          NextMomentPromptCard(
            prompt: ctx.nextMomentPrompt!,
            onPrimary: () => _handleNextMomentPromptAction(
              ctx.nextMomentPrompt!.primaryAction,
            ),
            onSecondary: ctx.nextMomentPrompt!.secondaryCta != null
                ? () => _handleNextMomentPromptAction(
                    ctx.nextMomentPrompt!.secondaryAction,
                  )
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.recordHomeSurface.showTodaysOneQuestion &&
            ctx.todaysOneQuestion != null &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          TodaysOneQuestionCard(
            question: ctx.todaysOneQuestion!,
            onPrimary: () => _handleTodaysOneQuestionAction(
              ctx.todaysOneQuestion!,
            ),
            onViewFull: _openTodaysOneQuestionScreen,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showFirstUseWordingHelper &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstUseWordingHelperCard(
            onUseOpening: (prompt) => unawaited(
              _openFirstUseWordingOpening(prompt),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.ui == RecordUiState.ready &&
            !ctx.firstUseSimplifiedRecord) ...[
          if (ArchiveJourneyExplainerGates.showFirstProofJourneyStripOnRecord(
                loaded: _journalEntryCountReady,
                entryCount: _journalEntryCount,
                isPostSave: _isPostSaveSurface,
                entries: _journalEntries,
              ) &&
              !ctx.recordReadySuppressStreakPressure) ...[
            const FirstProofJourneyStripCard(),
            const SizedBox(height: 12),
          ],
          if (!ctx.showReturningWatchTargetFocusedUi)
            Builder(
              builder: (context) {
                final readyPolicy = ctx.readyCapturePolicy;
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
                          ctx.showReturningWatchTargetFocusedUi,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
        ],
        if (ctx.ui == RecordUiState.ready &&
            RecordCaptureModeEngine.shouldShow(
              loaded: _journalEntryCountReady,
              isReady: true,
              isPostSave: _isPostSaveSurface,
            ) &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          RecordCaptureModesCard(
            onModeTap: (mode) =>
                unawaited(_openCaptureMode(mode)),
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.recordReadySurfacePriority != null) ...[
          SurfacePriorityDebugBadge(
            result: ctx.recordReadySurfacePriority!,
          ),
        ],
        if (ctx.showFirstSessionCaptureRepairCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstSessionCaptureRepairCard(
            result: ctx.firstSessionCaptureRepairCandidate,
            onTypeOneSentence: () => unawaited(
              navigateToTypeInsteadCapture(
                context,
                prompt: ctx.firstSessionCaptureRepairCandidate
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
        if (ctx.showFirstSessionLiftCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstSessionLiftCard(
            result: ctx.firstSessionLiftCandidate,
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
        if (ctx.showFirstSaveLiftCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstSaveLiftCard(
            result: ctx.firstSaveLiftCandidate,
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
        if (ctx.showBetaActivationPathCard &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
            ctx.betaActivationPathResult != null &&
            !ctx.firstUseSimplifiedRecord) ...[
          BetaActivationPathCard(
            result: ctx.betaActivationPathResult!,
            onPrimaryCta: () =>
                _handleBetaActivationPathPrimaryCta(
                  ctx.betaActivationPathResult!,
                ),
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showThreeMomentCompletionCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          ThreeMomentCompletionCard(
            result: ctx.threeMomentCompletionCandidate,
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
        if (ctx.showSecondMomentReturnCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          SecondMomentReturnCard(
            result: ctx.secondMomentReturnCandidate,
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
        if (ctx.showFirstMomentCaptureCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstMomentCaptureCard(
            result: ctx.firstMomentCaptureCandidate,
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
        if (ctx.showFirstRunPositioningCard &&
            !ctx.firstUseSimplifiedRecord) ...[
          FirstRunPositioningCard(
            result: ctx.firstRunPositioningCandidate,
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showOpenCapturePromptChips &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
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
        if (ctx.showReturnAfterProofLiftV2InGuidanceStack &&
            !ctx.firstUseSimplifiedRecord) ...[
          ReturnAfterProofLiftV2Card(
            result: ctx.returnAfterProofLiftV2Candidate,
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
        if (ctx.showReturnAfterProofInGuidanceStack &&
            !ctx.firstUseSimplifiedRecord) ...[
          ReturnAfterProofCard(
            result: ctx.returnAfterProofRecordCandidate,
            useStrengthenedLayout:
                ctx.showReturnAfterProofStrengthenedOnRecordReady,
            onPromptSelected: (prompt) {
              setState(() => _selectedPromptLine = prompt);
            },
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showLowFrictionReturnCard &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.showReturningWatchTargetFocusedUi &&
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
        if (ctx.showBetaTodaySummaryCard &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
            !ctx.firstUseSimplifiedRecord) ...[
          BetaTodaySummaryCard(
            result: ctx.betaTodaySummaryCandidate,
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showWhatToNoticeNextCard &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.recordReadySuppressStreakPressure) ...[
          WhatToNoticeNextCard(
            result: ctx.whatToNoticeNextCandidate,
            onPromptSelected: (prompt) {
              setState(() => _selectedPromptLine = prompt);
            },
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showCaptureFreedomLine &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          CaptureFreedomLine(
            source: 'record',
            entryCount: _journalEntryCount,
            compact: _journalEntryCount > 0,
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showTimelinePositioningOnRecordReady &&
            !ctx.firstUseSimplifiedRecord) ...[
          TimelinePositioningCard(
            result: ctx.timelinePositioningCandidate,
            source: 'record',
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showThreeDayChallengeOnRecord &&
            ctx.threeDayChallengeCandidate != null &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.recordReadySuppressStreakPressure) ...[
          ThreeDayChallengeCard(
            challenge: ctx.threeDayChallengeCandidate!,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.ui == RecordUiState.ready &&
            ctx.showNextBestActionOnRecord &&
            ctx.nextBestActionCandidate != null &&
            !ctx.firstUseSimplifiedRecord &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          NextBestActionLine(
            action: ctx.nextBestActionCandidate!,
            surface: NextBestActionSurface.record,
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.ui == RecordUiState.ready &&
            ctx.recordHomeSurface.showStartHereTodayPrompt &&
            _dailyReturnSuggestions.hasSuggestions &&
            !ctx.recordReadySuppressStreakPressure) ...[
          DailyReturnSuggestionsCard(
            startHereOnly: true,
            suggestionSet: _dailyReturnSuggestions,
            selectedPrompt: _selectedPromptLine,
            onSuggestionTap: _onDailySuggestionTapped,
            onSelectPrompt: (p) {
              unawaited(ActivationTracker.trackActivationStarterPromptSelected());
              setState(() => _selectedPromptLine = p);
            },
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showReturnedAfterDelayRecovery &&
            !ctx.recordReadySuppressStreakPressure) ...[
          const CaptureRecoveryHintStrip.returnedAfterDelay(),
          const SizedBox(height: 12),
        ],
        if (ctx.showReturnDayFlow &&
            ctx.returnDayFlowCandidate != null &&
            !ctx.recordReadySuppressStreakPressure) ...[
          ReturnDayFlowCard(
            flow: ctx.returnDayFlowCandidate!,
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
        if (ctx.showQuietSignalOnRecord &&
            ctx.quietSignalCandidate != null &&
            !ctx.recordReadySuppressStreakPressure) ...[
          QuietSignalRecordCard(
            signal: ctx.quietSignalCandidate!,
            entryCount: _journalEntryCount,
            onKeepWatching: () {
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showReturnTomorrowCueReady &&
            ctx.returnTomorrowCueReady != null &&
            !ctx.recordReadySuppressStreakPressure) ...[
          ReturnTomorrowCueCard(
            cue: ctx.returnTomorrowCueReady!,
            entryCount: _journalEntryCount,
            surface: 'record_ready',
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showFirstWeekProgressReady &&
            ctx.firstWeekProgressReady != null &&
            !ctx.recordReadySuppressStreakPressure) ...[
          FirstWeekProgressLine(
            progress: ctx.firstWeekProgressReady!,
            entryCount: _journalEntryCount,
            surface: 'record_ready',
          ),
          const SizedBox(height: 8),
        ],
        if (ctx.showLowEvidenceGuidanceOnRecord &&
            !ctx.recordReadyShowsWatchTargetOnly) ...[
          LowEvidenceGuidanceCard(
            guidance: ctx.lowEvidenceGuidance!,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showDailyArchiveMemory &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.dailyArchiveMemoryCandidate != null) ...[
          DailyArchiveMemoryCard(
            memory: ctx.dailyArchiveMemoryCandidate!,
            entryCount: _journalEntryCount,
            source: 'record',
            onRecord: () => unawaited(
              _onRecordPressed(
                source: 'daily_archive_memory',
              ),
            ),
            onViewPatternDetails:
                ctx.dailyArchiveMemoryCandidate!
                    .canShowPatternDetail
                ? _openPatternDetailFromRecord
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            ctx.recordProofStack.showEarlyFirstSignalCard &&
            !ctx.showEarlyEvidenceTimelineOnRecord) ...[
          if (EarlyFirstSignalEngine.build(
                entries: _journalEntries,
              )
              case final signal?) ...[
            EarlyFirstSignalCard(
              signal: signal,
              showPrimaryCta:
                  !_shouldHideCardRecordButtons(ctx.ui) &&
                  FirstThreeSessionGates.showEarlyFirstSignalCardPrimaryCta(
                    signal.kind,
                  ),
              showInsightFeedback:
                  !ctx.suppressConfirmedRepeatInlineFeedback,
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
        if (ctx.showPatternChanged &&
            ctx.patternChangedCandidate != null) ...[
          PatternChangedCard(
            result: ctx.patternChangedCandidate!,
            entryCount: _journalEntryCount,
            surface: 'record',
            showRecordCta: ctx.showPatternChangedRecordCta,
            onRecord: () => _handlePatternChangedRecord(
              ctx.patternChangedCandidate!,
            ),
            onDismissed: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showArchiveCurrentBeliefOnRecord &&
            ctx.ui == RecordUiState.ready &&
            ctx.archiveBeliefSurfaceCandidate.shouldShow) ...[
          ArchiveBeliefSurfaceCard(
            surface: ctx.archiveBeliefSurfaceCandidate,
            onRecordNext: () => unawaited(
              _onRecordPressed(
                source: 'archive_current_belief',
              ),
            ),
          ),
          if (ctx.patternNamePrompt != null) ...[
            const SizedBox(height: 12),
            PatternNameConfirmationCard(
              prompt: ctx.patternNamePrompt!,
              source: 'record',
              entryCount: _journalEntryCount,
              onChanged: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (ctx.showTimelineProofMomentOnRecord &&
            ctx.timelineProofMomentCandidate != null) ...[
          TimelineProofMomentCard(
            result: ctx.timelineProofMomentCandidate!,
            source: 'record',
          ),
          if (ctx.showBetaProofLiftUnderTimelineProof &&
              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
            const SizedBox(height: 12),
            BetaProofLiftCard(
              result: ctx.betaProofLiftTimelineCandidate,
              source: 'record',
              surface: 'record_ready',
            ),
          ],
          if (ctx.showBetaRepairLabProofOnRecord &&
              ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
              ctx.betaRepairLabProofResult.shouldShow) ...[
            const SizedBox(height: 12),
            BetaRepairLabProofCard(
              result: ctx.betaRepairLabProofResult,
              onNotRelevantAnswered: () =>
                  NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                    entries: _journalEntries,
                    source: 'record',
                  ),
              onChanged: () => setState(() {}),
            ),
          ] else if (ctx.showProofFloorRescueOnRecord &&
              ctx.proofFloorRescueResult.shouldShow) ...[
            const SizedBox(height: 12),
            ProofFloorRescueCard(
              result: ctx.proofFloorRescueResult,
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
          ] else if (ctx.showProofQualityRepairOnRecord &&
              ctx.proofQualityRepairResult.shouldShow) ...[
            const SizedBox(height: 12),
            ProofQualityRepairCard(
              result: ctx.proofQualityRepairResult,
              onNotRelevantAnswered: () =>
                  NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                    entries: _journalEntries,
                    source: 'record',
                  ),
              onChanged: () => setState(() {}),
            ),
          ] else if (!ctx.showProofFloorRescueOnRecord) ...[
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
              isRecording: ctx.ui == RecordUiState.recording,
              isPostSaveDegraded: false,
              whatChangedQuestionActive: ctx.showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  ctx.patternReviewInboxActiveOnRecord,
              onNotRelevantAnswered: () =>
                  NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                    entries: _journalEntries,
                    source: 'record',
                  ),
              onChanged: () => setState(() {}),
            ),
          ],
          if (ctx.showProofQualityResponseUnderTimelineProof) ...[
            const SizedBox(height: 12),
            ProofQualityResponseCard(
              result: ctx.proofQualityResponseTimelineCandidate,
              source: 'record',
              onChanged: () => setState(() {}),
            ),
          ] else ...[
            if (ctx.showNotRelevantRecoveryUnderTimelineProof) ...[
              const SizedBox(height: 12),
              NotRelevantRecoveryCard(
                result: ctx.notRelevantRecoveryCandidate,
                source: 'record',
                onChanged: () => setState(() {}),
              ),
            ],
            if (ctx.showProofSpecificityBoostOnTimelineProof) ...[
              const SizedBox(height: 12),
              ProofSpecificityBoostCard(
                result: ctx.proofSpecificityBoostCandidate,
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
        if (ctx.showReturnAfterProofLiftV2BelowProofOnRecord &&
            ctx.showTimelineProofMomentOnRecord &&
            ctx.timelineProofMomentCandidate != null) ...[
          ReturnAfterProofLiftV2Card(
            result: ctx.returnAfterProofLiftV2Candidate,
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
        ] else if (ctx.showReturnAfterProofBelowProofOnRecord &&
            ctx.showTimelineProofMomentOnRecord &&
            ctx.timelineProofMomentCandidate != null) ...[
          ReturnAfterProofCard(
            result: ctx.returnAfterProofRecordCandidate,
            useStrengthenedLayout:
                ctx.showReturnAfterProofStrengthenedOnRecordReady,
            onPromptSelected: (prompt) {
              setState(() => _selectedPromptLine = prompt);
            },
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showBetaFeedbackCaptureRecordReady &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.betaFeedbackCaptureRecordReadyResult != null) ...[
          BetaFeedbackCaptureCard(
            result: ctx.betaFeedbackCaptureRecordReadyResult!,
            proofFeedbackSurface:
                ctx.betaFeedbackCaptureRecordReadyResult!.moment ==
                    BetaFeedbackCaptureMoment
                        .afterTimelineProof
                ? BetaProofFeedbackSurface.timelineProofMoment
                : null,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showArchiveTimelineSpineOnRecord &&
            ctx.archiveTimelineSpineCandidate != null) ...[
          ArchiveTimelineSpineCard(
            result: ctx.archiveTimelineSpineCandidate!,
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
            isRecording: ctx.ui == RecordUiState.recording,
            isPostSaveDegraded: false,
            whatChangedQuestionActive: ctx.showWhatChangedV2,
            patternReviewInboxHasActiveItems:
                ctx.patternReviewInboxActiveOnRecord,
            onNotRelevantAnswered: () =>
                NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                  entries: _journalEntries,
                  source: 'record',
                ),
            onChanged: () => setState(() {}),
          ),
          if (ctx.showProofQualityResponseUnderArchiveSpine) ...[
            const SizedBox(height: 12),
            ProofQualityResponseCard(
              result: ctx.proofQualityResponseSpineCandidate,
              source: 'record',
              onChanged: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (ctx.showBetaTesterReportOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          BetaTesterReportCard(
            result: ctx.betaTesterReportCandidate,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showReturnAfterProofLiftV2BelowProofOnRecord) ...[
          ReturnAfterProofLiftV2Card(
            result: ctx.returnAfterProofLiftV2Candidate,
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
        ] else if (ctx.showReturnAfterProofBelowProofOnRecord &&
            !ctx.showTimelineProofMomentOnRecord &&
            ctx.showBetaTesterReportOnRecord) ...[
          ReturnAfterProofCard(
            result: ctx.returnAfterProofRecordCandidate,
            useStrengthenedLayout:
                ctx.showReturnAfterProofStrengthenedOnRecordReady,
            onPromptSelected: (prompt) {
              setState(() => _selectedPromptLine = prompt);
            },
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          EvidenceTrailClarityCard(
            result: ctx.betaRepairLabEvidenceTrailClarityResult,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_beta_repair_lab_evidence_trail_clarity',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showBetaRepairLabPricingValidationBelowProofOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          PricingValidationCard(
            result: ctx.betaRepairLabPricingValidationResult,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_beta_repair_lab_pricing_validation',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showBetaRepairLabPricingValueFramingBelowProofOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          PricingValueFramingCard(
            result: ctx.betaRepairLabPricingValueFramingResult,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_beta_repair_lab_pricing_value_framing',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showBetaRepairLabPaywallValueBelowProofOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          PaywallValueRepairCard(
            result: ctx.betaRepairLabPaywallValueResult,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_beta_repair_lab_paywall_value',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showBetaRepairLabProPlacementBelowProofOnRecord &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
          BetaRepairLabProPlacementCard(
            result: ctx.betaRepairLabProPlacementResult,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_beta_repair_lab_pro_placement',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProUnderstandingLiftBelowProofOnRecord &&
            ctx.proUnderstandingLiftRecordReadyResult !=
                null) ...[
          ProUnderstandingLiftCard(
            result: ctx.proUnderstandingLiftRecordReadyResult!,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_pro_understanding_lift',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProVisibilityLiftBelowProofOnRecord &&
            ctx.proVisibilityLiftRecordReadyResult != null) ...[
          ProVisibilityLiftCard(
            result: ctx.proVisibilityLiftRecordReadyResult!,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource: 'record_pro_visibility_lift',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProBridgeBelowProofOnRecord &&
            ctx.proBridgeVisibilityRecordResult != null) ...[
          ProBridgeVisibilityCard(
            result: ctx.proBridgeVisibilityRecordResult!,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource: 'record_pro_bridge_visibility',
            ),
            onDismiss: () =>
                unawaited(_dismissProEvidenceValueBridge()),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showShareableNonPrivateProofOnRecord) ...[
          ShareableProofCard(
            result: ctx.shareableNonPrivateProofResult,
            source: 'record',
            surface: 'record_ready',
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showCurrentRelevanceOnRecordReady &&
            ctx.currentRelevanceCandidate != null) ...[
          CurrentRelevanceCard(
            state: ctx.currentRelevanceCandidate!,
            source: 'record',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showCorrectionMemoryOnRecordReady &&
            ctx.correctionMemoryCandidate != null) ...[
          CorrectionMemoryCard(
            result: ctx.correctionMemoryCandidate!,
            source: 'record',
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showProofQualityResponseOnRecordReady &&
            !ctx.showProofQualityResponseUnderTimelineProof &&
            !ctx.showProofQualityResponseUnderArchiveSpine &&
            ctx.proofQualityResponseTimelineCandidate
                .shouldShow) ...[
          ProofQualityResponseCard(
            result: ctx.proofQualityResponseTimelineCandidate,
            source: 'record',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showNotRelevantRecoveryOnRecordReady &&
            !ctx.showNotRelevantRecoveryUnderTimelineProof &&
            ctx.notRelevantRecoveryCandidate.shouldShow) ...[
          NotRelevantRecoveryCard(
            result: ctx.notRelevantRecoveryCandidate,
            source: 'record',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showEvidenceWeightingOnRecordReady &&
            ctx.evidenceWeightingCandidate != null) ...[
          EvidenceWeightingCard(
            result: ctx.evidenceWeightingCandidate!,
            source: 'record',
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showProofSpecificityOnRecordReady &&
            ctx.proofSpecificityCandidate.shouldShow) ...[
          ProofSpecificityCard(
            result: ctx.proofSpecificityCandidate,
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showPresentDayRelevanceOnRecordReady &&
            ctx.presentDayRelevanceCandidate != null) ...[
          PresentDayRelevanceCard(
            result: ctx.presentDayRelevanceCandidate!,
            source: 'record',
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.suppressLegacyEducationCardsForSpineOnRecord &&
            ctx.showPatternConfidenceExplanationOnRecordReady &&
            ctx.patternConfidenceExplanationCandidate !=
                null) ...[
          PatternConfidenceCard(
            result: ctx.patternConfidenceExplanationCandidate!,
            source: 'record',
            compact: true,
          ),
          const SizedBox(height: 12),
        ],
        if (!ctx.showReturningWatchTargetFocusedUi &&
            ctx.showArchiveSummaryOnRecord &&
            ctx.ui == RecordUiState.ready &&
            ctx.archiveSummary != null) ...[
          ArchiveSummaryCard(
            summary: ctx.archiveSummary!,
            showRecordNextCta: ctx.showArchiveSummaryRecordCta,
            watching: ctx.archiveWatching!,
            onRecordNext: () =>
                _handleArchiveSummaryRecordNext(
                  ctx.archiveSummary!,
                ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showDailyReturnReasonOnRecord &&
            ctx.dailyReturnReason != null) ...[
          DailyReturnReasonCard(
            reason: ctx.dailyReturnReason!,
            showRecordCta: ctx.showDailyReturnReasonRecordCta,
            onRecord: () =>
                _handleDailyReturnReason(ctx.dailyReturnReason!),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showEarlyEvidenceTimelineOnRecord) ...[
          EarlyEvidenceTimelineCard(
            timeline: ctx.earlyEvidenceTimeline!,
            compact: true,
            nearbyConfirmedRepeat:
                ctx.proofSurfaceLayout.timelineNearby,
            suppressEvidencePhrases: ctx.proofSurfaceLayout
                .suppressTimelineEvidencePhrases,
            analyticsSurface: 'record',
            entryCount: _journalEntryCount,
            entriesForWhy: _journalEntries,
            onRecordWhatHelped:
                ctx.earlyEvidenceTimeline!.showsSofterReturn &&
                    !ctx.earlyEvidenceTimeline!.showsHelpfulAction
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
        if (ctx.showWeeklyArchiveReviewOnRecord &&
            ctx.weeklyArchiveReview != null) ...[
          weekly_review_surface.WeeklyArchiveReviewCard(
            review: ctx.weeklyArchiveReview!,
            onViewReview: () =>
                _openWeeklyArchiveReview(ctx.weeklyArchiveReview!),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showPrivateArchiveReportOnRecord &&
            ctx.privateArchiveReportCandidate != null) ...[
          PrivateArchiveReportCard(
            report: ctx.privateArchiveReportCandidate!,
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
            isRecording: ctx.ui == RecordUiState.recording,
            isPostSaveDegraded: false,
            whatChangedQuestionActive: ctx.showWhatChangedV2,
            patternReviewInboxHasActiveItems:
                ctx.patternReviewInboxActiveOnRecord,
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
              isRecording: ctx.ui == RecordUiState.recording,
              isPostSaveDegraded: false,
              whatChangedQuestionActive: ctx.showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  ctx.patternReviewInboxActiveOnRecord,
              onChanged: () => setState(() {}),
            ),
          const SizedBox(height: 12),
        ],
        if (ctx.showProEvidenceValuePrivateReportOnRecord) ...[
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
        if (ctx.showConfirmedRepeatWhyMattersOnRecord) ...[
          ConfirmedRepeatWhyMattersCard(
            onDismissed: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showConfirmedRepeatThoughtMapOnRecord &&
            ctx.confirmedRepeatThoughtMap != null) ...[
          ConfirmedRepeatThoughtMapCard(
            result: ctx.confirmedRepeatThoughtMap!,
            showRecordMissingPieceCta:
                ctx.showThoughtMapRecordCta,
            onRecordMissingPiece: () =>
                _handleThoughtMapMissingPiece(
                  ctx.confirmedRepeatThoughtMap!,
                ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showHelpfulActionAppearedOnRecord &&
            ctx.helpfulActionAppearedCandidate != null) ...[
          HelpfulActionAppearedCard(
            result: ctx.helpfulActionAppearedCandidate!,
            entryCount: _journalEntryCount,
            source: 'record',
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showPositiveReinforcementOnRecord &&
            ctx.positiveReinforcement != null) ...[
          PositiveReinforcementCard(
            reinforcement: ctx.positiveReinforcement!,
            showRecordAgainCta:
                ctx.showPositiveReinforcementRecordCta,
            onRecordAgain: () =>
                _handlePositiveReinforcementRecordAgain(
                  ctx.positiveReinforcement!,
                ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showChangeProofOnRecord &&
            ctx.repeatReturnChangeProof != null) ...[
          RepeatReturnCheckChangeProofCard(
            proof: ctx.repeatReturnChangeProof!,
            entryCount: _journalEntryCount,
            surface: 'record',
            onRecordNext: () => unawaited(
              _onRecordPressed(source: 'repeat_return_proof'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showConfirmedRepeatBetaFeedback &&
            !ctx.showReturningWatchTargetFocusedUi &&
            !ctx.showArchiveSummaryOnRecord) ...[
          ConfirmedRepeatBetaFeedbackCard(
            entryCount: _journalEntryCount,
            surface: 'record',
            viewingConfirmedRepeat:
                ctx.viewingConfirmedRepeatOnRecord,
            isRecording: ctx.ui == RecordUiState.recording,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showFirstWeekLoopOnRecord &&
            ctx.firstWeekLoopCandidate != null &&
            !ctx.recordReadySuppressStreakPressure) ...[
          FirstWeekLoopCard(
            loop: ctx.firstWeekLoopCandidate!,
            entryCount: _journalEntryCount,
            showRecordCta: ctx.showFirstWeekLoopRecordCta,
            onRecord: () => unawaited(
              _onRecordPressed(source: 'first_week_loop'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showBetaTestScriptCard &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
            !ctx.showReturningWatchTargetFocusedUi &&
            ctx.betaTestScriptCardCandidate != null) ...[
          BetaTestScriptCard(
            card: ctx.betaTestScriptCardCandidate!,
            onViewSteps: () {
              unawaited(BetaTestScriptSheet.show(
                context,
                entries: _journalEntries,
                source: 'record',
                onReset: () {
                  if (mounted) setState(() {});
                },
              ));
            },
            onSendFeedback:
                ctx.betaTestScriptCardCandidate!
                    .showSendFeedbackSecondary
                ? () {
                    unawaited(BetaFeedbackSheet.show(
                      context,
                      source: 'record_beta_test_script',
                      entryCount: _journalEntryCount,
                    ));
                  }
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.showProUnderstandingLiftInProSectionOnRecord &&
            ctx.proUnderstandingLiftRecordReadyResult !=
                null) ...[
          ProUnderstandingLiftCard(
            result: ctx.proUnderstandingLiftRecordReadyResult!,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource:
                  'record_pro_understanding_lift',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProVisibilityLiftInProSectionOnRecord &&
            ctx.proVisibilityLiftRecordReadyResult != null) ...[
          ProVisibilityLiftCard(
            result: ctx.proVisibilityLiftRecordReadyResult!,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource: 'record_pro_visibility_lift',
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProBridgeInProSectionOnRecord &&
            ctx.proBridgeVisibilityRecordResult != null) ...[
          ProBridgeVisibilityCard(
            result: ctx.proBridgeVisibilityRecordResult!,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource: 'record_pro_bridge_visibility',
            ),
            onDismiss: () =>
                unawaited(_dismissProEvidenceValueBridge()),
          ),
          const SizedBox(height: 12),
        ] else if (ctx.showProEvidenceValueOnRecordReady) ...[
          ProEvidenceValueCard(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: _journalEntryCount,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSeePro: () => _openProEvidenceValueSubscription(
              analyticsSource: 'record_pro_evidence_value',
            ),
            onDismiss: () =>
                unawaited(_dismissProEvidenceValueBridge()),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.betaFeedbackIntelligenceSurfaceOnRecordReady !=
                null &&
            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
            !ctx.showReturningWatchTargetFocusedUi) ...[
          BetaFeedbackIntelligenceCard(
            surface:
                ctx.betaFeedbackIntelligenceSurfaceOnRecordReady!,
            entryCount: _journalEntryCount,
            reachedFirstProof: ctx.firstProofPayoffSeenOnRecord,
            compact: ctx.proofSurfaceLayout.proBridgeCompact,
            onSubmitted: () {
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            RecordEmptyArchiveGates.showConfirmedRepeatChangeNoticeCard(
              loaded: _journalEntryCountReady,
              entryCount: _journalEntryCount,
              isPostSave: _isPostSaveSurface,
            ) &&
            !ctx.showEarlyEvidenceTimelineOnRecord &&
            !ctx.showArchiveSummaryOnRecord) ...[
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
        if (ctx.showEarlyReturnReminder) ...[
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
        if (ctx.ui == RecordUiState.ready &&
            ctx.recordHomeSurface.showDailyMirrorCard &&
            !(_journalEntryCountReady &&
                _journalEntryCount == 0)) ...[
          DailyMirrorRecordCard(
            mirror: _dailyMirror,
            onPrimaryCta: () =>
                unawaited(_onRecordPressed(source: 'moment')),
            showRecordCta: !_shouldHideCardRecordButtons(ctx.ui),
          ),
          if (_showFirstRunPrivacyReassurance) ...[
            const SizedBox(height: 8),
            const RecordFirstRunPrivacyReassurance(),
          ],
          const SizedBox(height: 12),
        ],
        if (_missedCheckInForDiagnosis != null &&
            ctx.ui == RecordUiState.ready &&
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
                (ctx.ui == RecordUiState.ready
                    ? ctx.recordHomeSurface
                          .showCurrentObjectiveCard
                    : ctx.stack.showCurrentObjectiveCard) &&
                !_shouldHideCompetingRecordCtas(ctx.ui)) ||
            (ScreenshotMode.enabled &&
                ScreenshotMode.objective != null)) ...[
          _currentObjectiveWidget(ctx.stack)!,
          const SizedBox(height: 16),
        ],
        if ((ctx.ui == RecordUiState.ready
                ? ctx.recordHomeSurface.showRetentionStateCard
                : ctx.stack.showRetentionStateCard) &&
            ctx.showArchiveProgressCards) ...[
          _retentionCardWidget(ctx.stack)!,
          const SizedBox(height: 16),
        ],
        if (ctx.stack.showDueCheckCard &&
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
        if (ctx.stack.showReturnDayJourneyCard &&
            ctx.showArchiveProgressCards &&
            _signalJourney != null &&
            ctx.ui == RecordUiState.ready) ...[
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
        if (!_shouldHideCompetingRecordCtas(ctx.ui) &&
            _activeLoop?.isCapacityYes == true &&
            CapacityLoopGates.showRecordPrompt(
              capacityWedgeActive: true,
              sampleMode: ScreenshotMode.enabled,
            ) &&
            ctx.ui == RecordUiState.ready &&
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
        if (_showDefaultBoundaryPauseOnRecord(ctx.ui)) ...[
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
        if (!_shouldHideCompetingRecordCtas(ctx.ui) &&
            ctx.stack.showFirstRecordingHandoff &&
            _activeLoop != null) ...[
          LoopModeFirstHandoffCard(
            loop: _activeLoop!,
            onStartRecording: () =>
                _onRecordPressed(source: 'main'),
            showRecordCta: !_shouldHideCardRecordButtons(ctx.ui),
          ),
          const SizedBox(height: 12),
        ] else if (!_shouldHideCompetingRecordCtas(ctx.ui) &&
            ctx.stack.showFirstRecordingHandoff) ...[
          FirstRecordingHandoffCard(
            onStartRecording: () =>
                _onRecordPressed(source: 'main'),
            wedgePrompt: _selectedPromptLine,
            showRecordCta: !_shouldHideCardRecordButtons(ctx.ui),
          ),
          const SizedBox(height: 12),
        ] else if (!_shouldHideCompetingRecordCtas(ctx.ui) &&
            _activeLoop != null &&
            ctx.showArchiveProgressCards &&
            _postSavePattern == null &&
            !ctx.stack.showReturnDayJourneyCard) ...[
          LoopModeProgressCard(
            loop: _activeLoop!,
            onRecordNext: () =>
                unawaited(_onRecordPressed(source: 'loop')),
            showRecordCta: !_shouldHideCardRecordButtons(ctx.ui),
          ),
          const SizedBox(height: 12),
        ] else if (!_shouldHideCompetingRecordCtas(ctx.ui) &&
            ctx.stack.showArchiveMemoryDemo) ...[
          ArchiveMemoryDemoCard(
            onRecord: () =>
                unawaited(_onRecordPressed(source: 'main')),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.stack.showFirstLoopStartCard &&
            !_shouldHideCompetingRecordCtas(ctx.ui)) ...[
          FirstLoopStartCard(
            onRecord: () =>
                unawaited(_onRecordPressed(source: 'loop')),
            showRecordCta: !_shouldHideCardRecordButtons(ctx.ui),
          ),
          const SizedBox(height: 12),
        ],
        if (ctx.stack.showTrialFirstMomentCard &&
            !_shouldHideCompetingRecordCtas(ctx.ui)) ...[
          TrialFirstMomentCard(
            onStartRecording: () =>
                unawaited(_onRecordPressed(source: 'main')),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }
}
