part of '../recording_screen.dart';

extension RecordPostSaveCards on _RecordScreenState {
  List<Widget> _buildRecordPostSaveCards(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    if (V1FeatureFlags.enableV1Only &&
        ctx.ui == RecordUiState.done &&
        ctx.entriesAfterSave.isNotEmpty) {
      return _buildV1MomentSaveReceipt(context, ctx);
    }

    return [
        if (ctx.ui == RecordUiState.done &&
            ctx.entriesAfterSave.isNotEmpty) ...[
          if (ctx.justSavedFirstEntry &&
              !ctx.showDegradedTranscriptFocusedPostSave) ...[
            const SizedBox(height: 16),
            PostSaveRecordedSummaryCard(
              entry: ctx.entriesAfterSave.first,
              allEntries: ctx.entriesAfterSave,
              showAnalysisPendingNote: false,
              mirror: ctx.postSaveDailyMirror!,
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
          if (!ctx.suppressNoisyFirstSaveCards &&
                  !ctx.suppressNoisyRepeatPostSaveCards ||
              ctx.showDegradedTranscriptFocusedPostSave) ...[
            if (!VoiceCaptureQuality.isDegradedVoiceCapture(
              ctx.entriesAfterSave.first,
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
              entry: ctx.entriesAfterSave.first,
              allEntries: ctx.entriesAfterSave,
              degradedBodyCopy:
                  _lastCaptureLowQualityTranscript
                  ? VoiceCaptureCopy.lowQualityTranscriptIssue
                  : null,
              showSilentInputWarning:
                  _lastCaptureLikelySilentInput,
              showAnalysisPendingNote: false,
              mirror: ctx.postSaveDailyMirror!,
              primaryArchiveResult:
                  ctx.postSaveArchiveHierarchy?.kind,
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
                  ctx.suppressLatestSaveArchiveInsight
                  ? () => unawaited(
                      navigateToTypeInsteadCapture(
                        context,
                        onSaved: _finishSuccessfulCapture,
                      ),
                    )
                  : null,
              onBackToRecord:
                  ctx.showDegradedTranscriptFocusedPostSave
                  ? _resetPostSaveToReady
                  : ctx.entriesAfterSave.length == 1
                  ? _resetPostSaveToReady
                  : ctx.suppressLatestSaveArchiveInsight
                  ? _resetPostSaveToReady
                  : null,
            ),
            const SizedBox(height: 16),
            if (!ctx.suppressDegradedTranscriptPostSaveCompetitors) ...[
              if (MomentQualityFeedbackGates.shouldShow(
                entry: ctx.entriesAfterSave.first,
                showFirstProofMoment: ctx.showFirstProofMoment,
                hierarchyAllowsFeedback:
                    (ctx.postSaveArchiveHierarchy
                            ?.showMomentQualityFeedback ??
                        true) &&
                    !ctx.showComeBackTomorrowV2PostSave,
              )) ...[
                MomentQualityFeedbackCard(
                  entry: ctx.entriesAfterSave.first,
                ),
              ],
              if (ctx.showFirstProofPayoff &&
                  ctx.firstProofPayoffCandidate! != null) ...[
                const SizedBox(height: 16),
                FirstProofPayoffCard(
                  payoff: ctx.firstProofPayoffCandidate!,
                  entryCount: ctx.postSaveEntryCount,
                  patternConfidence:
                      ctx.firstProofPatternConfidence!,
                  suppressCtas:
                      ctx.firstProofActionLoopContent! != null,
                  showProPackagingBridge:
                      !ctx.showProBridgeVisibilityPostSave &&
                      !ctx.showProEvidenceValuePostSave,
                  onWatchThisNext:
                      _handleFirstProofWatchThisNext,
                  onViewPatternDetails:
                      ctx.firstProofPayoffCandidate!
                          .canShowPatternDetail
                      ? _openFirstProofPatternDetail
                      : null,
                ),
                if (ctx.showBetaProofLiftOnFirstProofPayoff &&
                    ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                  const SizedBox(height: 12),
                  BetaProofLiftCard(
                    result: ctx.betaProofLiftFirstProofCandidate,
                    source: 'record_post_save',
                    surface: 'record_post_save_first_proof',
                  ),
                ],
                if (ctx.showReturnAfterProofLiftV2OnPostSave) ...[
                  const SizedBox(height: 12),
                  ReturnAfterProofLiftV2Card(
                    result:
                        ctx.returnAfterProofLiftV2PostSaveCandidate,
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
                ] else if (ctx.showReturnAfterProofOnFirstProofPayoff) ...[
                  const SizedBox(height: 12),
                  ReturnAfterProofCard(
                    result: ctx.returnAfterProofPostSaveCandidate,
                    useStrengthenedLayout:
                        ctx.showReturnAfterProofStrengthenedOnFirstProofPayoff,
                    onPromptSelected: (prompt) {
                      setState(
                        () => _selectedPromptLine = prompt,
                      );
                    },
                  ),
                ],
                if (ctx.showProUnderstandingLiftOnPostSave &&
                    ctx.proUnderstandingLiftPostSaveResult! !=
                        null) ...[
                  const SizedBox(height: 12),
                  ProUnderstandingLiftCard(
                    result:
                        ctx.proUnderstandingLiftPostSaveResult!,
                    onSeePro: () =>
                        _openProEvidenceValueSubscription(
                          analyticsSource:
                              'record_post_save_pro_understanding_lift',
                        ),
                  ),
                ] else if (ctx.showProVisibilityLiftOnPostSave &&
                    ctx.proVisibilityLiftPostSaveResult! !=
                        null) ...[
                  const SizedBox(height: 12),
                  ProVisibilityLiftCard(
                    result: ctx.proVisibilityLiftPostSaveResult!,
                    onSeePro: () =>
                        _openProEvidenceValueSubscription(
                          analyticsSource:
                              'record_post_save_pro_visibility_lift',
                        ),
                  ),
                ] else if (ctx.showProPreviewPostSave &&
                    ctx.proPreviewPostSaveResult! != null) ...[
                  const SizedBox(height: 12),
                  ProPreviewCard(
                    result: ctx.proPreviewPostSaveResult!,
                    onSeePro: () =>
                        _openProEvidenceValueSubscription(
                          analyticsSource:
                              'record_post_save_pro_preview',
                        ),
                    onDismiss: () => unawaited(
                      _dismissProEvidenceValueBridge(),
                    ),
                  ),
                ] else if (ctx.showProBridgeVisibilityPostSave &&
                    ctx.proBridgeVisibilityPostSaveResult! !=
                        null) ...[
                  const SizedBox(height: 12),
                  ProBridgeVisibilityCard(
                    result: ctx.proBridgeVisibilityPostSaveResult!,
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
                  showFirstProofPayoff: ctx.showFirstProofPayoff,
                  firstProofPayoffVisible: true,
                  entryCount: ctx.postSaveEntryCount,
                  hasConfirmedRepeat:
                      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                        ctx.entriesAfterSave,
                      ),
                  isRecording: ctx.ui == RecordUiState.recording,
                  isPostSaveDegraded:
                      ctx.entriesAfterSave.isNotEmpty &&
                      VoiceCaptureQuality.isDegradedVoiceCapture(
                        ctx.entriesAfterSave.last,
                      ),
                  whatChangedQuestionActive:
                      ctx.showWhatChangedV2,
                  patternReviewInboxHasActiveItems:
                      ctx.patternReviewInboxActivePostSave,
                ))
                  BetaProofFeedbackRow(
                    surface: BetaProofFeedbackSurface
                        .firstProofPayoff,
                    source: 'record_post_save',
                    entryCount: ctx.postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          ctx.entriesAfterSave,
                        ),
                    parentVisible: true,
                    isRecording:
                        ctx.ui == RecordUiState.recording,
                    isPostSaveDegraded:
                        ctx.entriesAfterSave.isNotEmpty &&
                        VoiceCaptureQuality.isDegradedVoiceCapture(
                          ctx.entriesAfterSave.last,
                        ),
                    whatChangedQuestionActive:
                        ctx.showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        ctx.patternReviewInboxActivePostSave,
                    onChanged: () => setState(() {}),
                  ),
                if (ctx.showProofQualityResponseOnFirstProofPayoff) ...[
                  const SizedBox(height: 12),
                  ProofQualityResponseCard(
                    result:
                        ctx.proofQualityResponseFirstProofCandidate,
                    source: 'record_post_save',
                    onChanged: () => setState(() {}),
                  ),
                ] else if (ctx.showProofSpecificityBoostOnFirstProofPayoff) ...[
                  const SizedBox(height: 12),
                  ProofSpecificityBoostCard(
                    result:
                        ctx.proofSpecificityBoostPostSaveCandidate,
                    surface: ProofSpecificityBoostSurface
                        .firstProofPayoff,
                    source: 'record_post_save',
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          ctx.entriesAfterSave,
                        ),
                    proofKey:
                        CurrentRelevanceStore.proofKeyFor(
                          ctx.entriesAfterSave,
                        ),
                    onChanged: () => setState(() {}),
                  ),
                ],
              ],
              if (ctx.showTimelineProofMomentOnFirstProofPayoff &&
                  ctx.timelineProofMomentPostSaveCandidate! !=
                      null) ...[
                const SizedBox(height: 12),
                TimelineProofMomentCard(
                  result:
                      ctx.timelineProofMomentPostSaveCandidate!,
                  source: 'record_post_save_first_proof',
                ),
                if (ctx.showBetaProofLiftUnderTimelineProofPostSave &&
                    ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                  const SizedBox(height: 12),
                  BetaProofLiftCard(
                    result:
                        ctx.betaProofLiftTimelinePostSaveCandidate,
                    source: 'record_post_save_first_proof',
                    surface: 'record_post_save_first_proof',
                  ),
                ],
                if (BetaProofFeedbackEngine.shouldShow(
                  surface: BetaProofFeedbackSurface
                      .timelineProofMoment,
                  parentVisible: true,
                  entryCount: ctx.postSaveEntryCount,
                  hasConfirmedRepeat:
                      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                        ctx.entriesAfterSave,
                      ),
                  isRecording: ctx.ui == RecordUiState.recording,
                  isPostSaveDegraded:
                      ctx.entriesAfterSave.isNotEmpty &&
                      VoiceCaptureQuality.isDegradedVoiceCapture(
                        ctx.entriesAfterSave.last,
                      ),
                  whatChangedQuestionActive:
                      ctx.showWhatChangedV2,
                  patternReviewInboxHasActiveItems:
                      ctx.patternReviewInboxActivePostSave,
                ))
                  BetaProofFeedbackRow(
                    surface: BetaProofFeedbackSurface
                        .timelineProofMoment,
                    source: 'record_post_save_first_proof',
                    entryCount: ctx.postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          ctx.entriesAfterSave,
                        ),
                    parentVisible: true,
                    isRecording:
                        ctx.ui == RecordUiState.recording,
                    isPostSaveDegraded:
                        ctx.entriesAfterSave.isNotEmpty &&
                        VoiceCaptureQuality.isDegradedVoiceCapture(
                          ctx.entriesAfterSave.last,
                        ),
                    whatChangedQuestionActive:
                        ctx.showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        ctx.patternReviewInboxActivePostSave,
                    onChanged: () => setState(() {}),
                  ),
                if (ctx.showProofQualityResponseOnTimelineProofPostSave) ...[
                  const SizedBox(height: 12),
                  ProofQualityResponseCard(
                    result:
                        ctx.proofQualityResponseTimelinePostSaveCandidate,
                    source: 'record_post_save_first_proof',
                    onChanged: () => setState(() {}),
                  ),
                ] else if (ctx.showProofSpecificityBoostOnTimelineProofPostSave) ...[
                  const SizedBox(height: 12),
                  ProofSpecificityBoostCard(
                    result:
                        ctx.proofSpecificityBoostPostSaveCandidate,
                    surface: ProofSpecificityBoostSurface
                        .timelineProofMoment,
                    source: 'record_post_save_first_proof',
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          ctx.entriesAfterSave,
                        ),
                    proofKey:
                        CurrentRelevanceStore.proofKeyFor(
                          ctx.entriesAfterSave,
                        ),
                    onChanged: () => setState(() {}),
                  ),
                ],
                if (ctx.showBetaInviteLoopPostSave &&
                    ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                    ctx.betaInviteLoopPostSaveResult! != null) ...[
                  const SizedBox(height: 12),
                  BetaInviteCard(
                    result: ctx.betaInviteLoopPostSaveResult!,
                    onDismiss: () =>
                        unawaited(_dismissBetaInviteLoop()),
                  ),
                ],
              ],
              if (ctx.showProofSpecificityOnFirstProofPayoff &&
                  ctx.proofSpecificityPostSaveCandidate
                      .shouldShow) ...[
                const SizedBox(height: 12),
                ProofSpecificityCard(
                  result: ctx.proofSpecificityPostSaveCandidate,
                ),
              ],
              // Post-save Pro upsell cards removed from the capture-interrupt
              // path: a save should never be followed by a billing prompt. Pro
              // is presented only on the paywall/settings surfaces. (Pre-capture
              // and record-ready upsells are intentionally left in place.)
              if (ctx.betaFeedbackIntelligenceSurfacePostSave! !=
                      null &&
                  ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) ...[
                const SizedBox(height: 12),
                BetaFeedbackIntelligenceCard(
                  surface:
                      ctx.betaFeedbackIntelligenceSurfacePostSave!,
                  entryCount: ctx.postSaveEntryCount,
                  reachedFirstProof:
                      ctx.showFirstProofPayoff &&
                      ctx.firstProofPayoffCandidate! != null,
                  onSubmitted: () {
                    if (mounted) setState(() {});
                  },
                ),
              ],
              if (ctx.showBetaFeedbackCapturePostSave &&
                  ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
                  ctx.betaFeedbackCapturePostSaveResult! !=
                      null) ...[
                const SizedBox(height: 12),
                BetaFeedbackCaptureCard(
                  result: ctx.betaFeedbackCapturePostSaveResult!,
                  proofFeedbackSurface:
                      ctx.betaFeedbackCapturePostSaveResult!
                              .moment ==
                          BetaFeedbackCaptureMoment
                              .afterTimelineProof
                      ? (ctx.showTimelineProofMomentOnFirstProofPayoff &&
                                ctx.timelineProofMomentPostSaveCandidate! !=
                                    null
                            ? BetaProofFeedbackSurface
                                  .timelineProofMoment
                            : null)
                      : null,
                  onChanged: () => setState(() {}),
                ),
              ],
              if (ctx.showFirstProofTruth) ...[
                const SizedBox(height: 12),
                FirstProofTruthCard(
                  proofKey: ctx.firstProofTruthProofKey,
                  entryCount: ctx.postSaveEntryCount,
                  hasSnippets:
                      ctx.firstProofPayoffCandidate!.hasSnippets,
                  onAnswered: () {
                    if (mounted) setState(() {});
                  },
                ),
              ],
              if (ctx.firstProofActionLoopContent! != null) ...[
                const SizedBox(height: 12),
                FirstProofActionLoopCard(
                  content: ctx.firstProofActionLoopContent!,
                  entryCount: ctx.postSaveEntryCount,
                  onWatchThisNext:
                      _handleFirstProofWatchThisNext,
                  onViewPatternDetails:
                      ctx.firstProofActionLoopContent!
                          .canShowPatternDetails
                      ? _openFirstProofPatternDetail
                      : null,
                  onRenamePattern:
                      ctx.firstProofActionLoopContent!
                          .canRenamePattern
                      ? _openFirstProofRenamePattern
                      : null,
                  onKeepRecording: _keepRecording,
                  onCorrectTranscript:
                      ctx.firstProofActionLoopContent!
                          .canCorrectTranscript
                      ? () {
                          final entry = ctx.entriesAfterSave.last;
                          unawaited(
                            _openCorrectTranscriptForEntry(
                              entry,
                            ),
                          );
                        }
                      : null,
                  onRemoveFromPattern:
                      ctx.firstProofActionLoopContent!
                          .canRemoveFromPattern
                      ? () => unawaited(
                          _excludeLatestFromFirstProofPattern(),
                        )
                      : null,
                  onOpenPatternCorrection:
                      ctx.firstProofActionLoopContent!
                          .canShowPatternCorrection
                      ? () => unawaited(
                          _openFirstProofPatternCorrection(),
                        )
                      : null,
                ),
              ],
              if (ctx.confirmedRepeatTriggerPayoff! != null) ...[
                const SizedBox(height: 16),
                ConfirmedRepeatTriggerPayoffCard(
                  payoff: ctx.confirmedRepeatTriggerPayoff!,
                  analyticsSurface: 'record',
                  entryCount: ctx.entriesAfterSave.length,
                  entriesForWhy: ctx.entriesAfterSave,
                  onKeepWatching: _resetPostSaveToReady,
                  onViewEvidence: () => context.push(
                    BeliefEvidenceNavigation.route,
                  ),
                ),
              ],
              if (ctx.confirmedRepeatHelpfulActionPayoff! !=
                  null) ...[
                const SizedBox(height: 16),
                ConfirmedRepeatHelpfulActionPayoffCard(
                  payoff: ctx.confirmedRepeatHelpfulActionPayoff!,
                  analyticsSurface: 'record',
                  entryCount: ctx.entriesAfterSave.length,
                  entriesForWhy: ctx.entriesAfterSave,
                  onKeepWatching: _resetPostSaveToReady,
                  onViewEvidence: () => context.push(
                    BeliefEvidenceNavigation.route,
                  ),
                ),
              ],
              if (ctx.confirmedRepeatChangeNotice! != null) ...[
                const SizedBox(height: 16),
                ConfirmedRepeatChangeNoticeCard(
                  notice: ctx.confirmedRepeatChangeNotice!,
                  analyticsSurface: 'record',
                  entryCount: ctx.entriesAfterSave.length,
                  entriesForWhy: ctx.entriesAfterSave,
                  onRecordWhatHelped: () {
                    ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                    setState(
                      () => _selectedPromptLine =
                          ctx.confirmedRepeatChangeNotice!
                              .guidedRecordPrompt,
                    );
                    _resetPostSaveToReady();
                  },
                  onViewEvidence: () => context.push(
                    BeliefEvidenceNavigation.route,
                  ),
                ),
              ],
              if (ctx.repeatReturnCheckOffer! != null &&
                  !ctx.showReturnCheckPayoff &&
                  !ctx.showWhatChangedV2) ...[
                const SizedBox(height: 12),
                RepeatReturnCheckCard(
                  entryId: ctx.repeatReturnCheckOffer!.entryId,
                  entryCount:
                      ctx.repeatReturnCheckOffer!.entryCount,
                  surface: 'record',
                  onChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
              ],
              if (ctx.postSaveArchiveHierarchy
                      ?.showMomentQualityFeedback ??
                  true)
                Builder(
                  builder: (context) {
                    if (ctx.suppressLatestSaveArchiveInsight) {
                      return const SizedBox.shrink();
                    }
                    final returnTrigger =
                        const CapacityReturnTriggerEngine()
                            .buildFromJournal(
                              entries: ctx.entriesAfterSave,
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
          if (ctx.postSaveArchiveHierarchy
                      ?.showBeliefUpdateCard ==
                  true &&
              ctx.beliefUpdatePayoff! != null &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.showFirstProofMoment &&
              !ctx.showReturnCheckPayoff &&
              !ctx.showWhatChangedV2) ...[
            const SizedBox(height: 16),
            BeliefUpdatePayoffCard(
              payoff: ctx.beliefUpdatePayoff!,
              showInlineActions: false,
              onAddAnother: _goToRecordTab,
              onViewEvidence: () => context.push(
                BeliefEvidenceNavigation.route,
              ),
            ),
          ],
          if (ctx.postSaveArchiveHierarchy! != null &&
              ctx.postSaveArchiveHierarchy!
                  .showFocusedActionsBar &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards &&
              !ctx.suppressEarlyRepeatPayoffCompetitors &&
              !ctx.showFirstProofMoment &&
              !ctx.showReturnCheckPayoff &&
              !ctx.showWhatChangedV2) ...[
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
          if (ctx.returnLoopPayoff! != null &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            DayTwoReturnLoopCard(
              payoff: ctx.returnLoopPayoff!,
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
          if (ctx.suppressNoisyRepeatPostSaveCards &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              ctx.postSaveDailyMirror! != null &&
              ctx.entriesAfterSave.isNotEmpty) ...[
            const SizedBox(height: 16),
            RepeatPostSaveCard(
              entry: ctx.entriesAfterSave.first,
              allEntries: ctx.entriesAfterSave,
              mirror: ctx.postSaveDailyMirror!,
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
                  ctx.repeatPostSaveThoughtMapPreview
                          ?.shouldShow ==
                      true
                  ? () => context.go('/archive-belief')
                  : null,
            ),
          ],
          if (_saveReceipt != null &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            StartHereSaveReceiptCard(
              receipt: _saveReceipt!,
              onDismiss: () =>
                  setState(() => _saveReceipt = null),
            ),
          ] else if (_suggestionProNudgeSource != null &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            SuggestionProNudgeCard(
              onUnlock: () {
                final source = _suggestionProNudgeSource!;
                setState(
                  () => _suggestionProNudgeSource = null,
                );
                unawaited(context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source: source,
                    sourceRoute: '/record',
                  ),
                ));
              },
              onDismiss: () => setState(
                () => _suggestionProNudgeSource = null,
              ),
            ),
          ],
          if (_doneForTodayReceipt != null &&
              _doneForTodayReceipt!.hasReceipt &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            DoneForTodayReceiptCard(
              receipt: ctx.showFirstProofMoment
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
                if (!path.show || ctx.returnLoopPayoff! != null) {
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
                ctx.returnLoopPayoff! == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: DayTwoReminderCard(),
              ),
            // Tomorrow's-check preview — passive, no CTA,
            // safe labels only.
            if (_dayTwoReturnPreview != null &&
                _dayTwoReturnPreview!.show &&
                ctx.returnLoopPayoff! == null &&
                !ctx.justSavedFirstEntry &&
                !ctx.suppressNoisyFirstSaveCards)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DayTwoReturnPreviewCard(
                  preview: _dayTwoReturnPreview!,
                  entryCount: _journalEntryCount,
                ),
              ),
          ],
          if (_archiveProofCounter != null &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              PostSaveCompletionCopyGates.showArchiveProofCounter(
                counterHasProof:
                    _archiveProofCounter!.hasProof,
                doneReceiptVisible:
                    _doneForTodayReceipt != null &&
                    _doneForTodayReceipt!.hasReceipt,
                suppressNoisyFirstSaveCards:
                    ctx.suppressNoisyFirstSaveCards ||
                    ctx.suppressNoisyRepeatPostSaveCards,
              )) ...[
            const SizedBox(height: 16),
            ArchiveProofCounterCard(
              counter: _archiveProofCounter!,
            ),
          ],
          if (ctx.shareableProof! != null &&
              ctx.shareableProof!.hasProof &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            ShareableArchiveProofCard(proof: ctx.shareableProof!),
          ],
          // The post-save value-moment Pro bridge (ValueMomentProBridge) is
          // removed from the capture-interrupt path — a save is never followed
          // by a billing prompt. `_valueMomentBridge` is still computed only so
          // FirstWeekLoopGates can suppress the (non-post-save) first-week loop.
          if (_showEvidenceContextTag &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            CaptureContextTagCard(
              onSaveTag: _saveEvidenceContextTag,
              onSkip: () => setState(
                () => _showEvidenceContextTag = false,
              ),
            ),
          ],
          if (ctx.stack.showInputQualityCoach &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
            const SizedBox(height: 16),
            InputQualityCoachCard(
              result: _inputQuality!,
              originalText: _inputQualityText,
              onAddSentence: _onInputQualityAddSentence,
              onUseAnyway: _onInputQualityUseAnyway,
              languageCode: _languageCode,
            ),
          ],
          if (!ctx.stack.showInputQualityCoach &&
              ctx.stack.showCompletedResult &&
              _returnDayJustClosed &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
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
            if (ctx.stack.showArchiveProofCards &&
                _patternProgress != null) ...[
              const SizedBox(height: 16),
              PatternProgressAfterSaveCard(
                progress: _patternProgress!,
              ),
            ],
          ] else if (!ctx.stack.showInputQualityCoach &&
              ctx.stack.showCompletedResult &&
              !ctx.suppressDegradedTranscriptPostSaveCompetitors &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards) ...[
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
              nextCheckSlot: ctx.stack.showResultNextCheck
                  ? ResultNextCheckCard(
                      checkIn: _completedCheckInToday!,
                      notUsefulReason:
                          _hookRescueNotUsefulReason,
                      feedbackHint: _feedbackHint,
                      showFeedback: ctx.stack.showFeedback,
                      routineAnchorPicker:
                          ctx.stack.showRoutineAnchor
                          ? () => RoutineAnchorChooser.show(
                              context,
                            )
                          : null,
                      onRoutineAnchorChosen:
                          ctx.stack.showRoutineAnchor
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
            if (ctx.stack.showArchiveProofCards &&
                _patternMemory != null) ...[
              const SizedBox(height: 16),
              PatternMemoryAfterSaveCard(
                memory: _patternMemory!,
                onUseNext:
                    _patternNextAction == null &&
                        !ctx.suppressPostResultNextCheckCompetitors
                    ? () => _usePatternMemoryNext(
                        _patternMemory!,
                      )
                    : null,
              ),
            ],
            if (ctx.stack.showArchiveProofCards &&
                _patternProgress != null) ...[
              const SizedBox(height: 16),
              PatternProgressAfterSaveCard(
                progress: _patternProgress!,
              ),
            ],
            if (ctx.stack.showArchiveProofCards &&
                _patternNextAction != null &&
                !ctx.suppressPostResultNextCheckCompetitors) ...[
              const SizedBox(height: 16),
              PatternNextActionCard(
                action: _patternNextAction!,
                onUse: () => _usePatternNextAction(
                  _patternNextAction!,
                ),
              ),
            ],
            if (ctx.stack.showArchiveProofCards &&
                _habitProof != null &&
                !ctx.suppressPostResultNextCheckCompetitors) ...[
              const SizedBox(height: 16),
              HabitProofCard(
                proof: _habitProof!,
                onKeepGoing: () =>
                    _keepHabitProofGoing(_habitProof!),
              ),
            ],
            if (ctx.stack.showArchiveProofCards &&
                _weeklyRecap != null) ...[
              const SizedBox(height: 16),
              WeeklyPatternRecapCard(
                recap: _weeklyRecap!,
                onUseNext:
                    ctx.suppressPostResultNextCheckCompetitors
                    ? null
                    : () =>
                          _useWeeklyRecapNext(_weeklyRecap!),
              ),
            ],
            if (ctx.stack.showArchiveProofCards &&
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
          if (!ctx.stack.showInputQualityCoach &&
              _tomorrowReturnLoop != null &&
              !_returnDayJustClosed &&
              !ctx.suppressNoisyFirstSaveCards &&
              !ctx.suppressNoisyRepeatPostSaveCards &&
              !ctx.suppressEarlyPatternClaimCards &&
              !ctx.suppressEarlyRepeatPayoffCompetitors &&
              !ctx.showFirstProofMoment &&
              !ctx.showReturnCheckPayoff &&
              !ctx.showWhatChangedV2) ...[
            if (_secondSessionComparison?.hasEnoughData ==
                    true &&
                ctx.secondSessionPayoff! == null) ...[
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
                      ctx.localSaveTitle!,
                      style:
                          VoiceMemoryTypography.cardTitleStyle(
                            color: VoiceMemoryColors
                                .captureSuccess,
                          ),
                    ),
                    if (ctx.syncNote! != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        ctx.syncNote!,
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
    ];
  }

  List<Widget> _buildV1MomentSaveReceipt(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    final entry = ctx.entriesAfterSave.first;
    final remoteStatus = resolveMomentSaveRemoteStatus(
      analysisSucceeded: ctx.lastCaptureAnalysisSucceeded == true,
      syncNote: ctx.syncNote?.toString(),
    );
    final syncNoteForDisplay = remoteStatus == MomentSaveRemoteStatus.none
        ? ctx.syncNote?.toString()
        : null;

    return [
      const SizedBox(height: 16),
      MomentSaveReceiptCard(
        entry: entry,
        entryCount: ctx.entriesAfterSave.length,
        mirror: ctx.postSaveDailyMirror!,
        remoteStatus: remoteStatus,
        syncNote: syncNoteForDisplay,
        onRecordAnother: _resetPostSaveToReady,
        onViewArchive: () => context.go('/archive-belief'),
        onCorrectText:
            _lastSavedEntry != null &&
                !VoiceCaptureQuality.isDegradedVoiceCapture(entry) &&
                TranscriptCorrectionGate.entryAllowsCorrection(_lastSavedEntry!)
            ? () => unawaited(_openCorrectTranscriptForEntry(_lastSavedEntry!))
            : null,
        onTypeWhatYouSaid: VoiceCaptureQuality.isDegradedVoiceCapture(entry)
            ? () => unawaited(_openPendingTranscriptRecoveryForLastVoiceEntry())
            : null,
        onRetryRemote:
            remoteStatus == MomentSaveRemoteStatus.failedRetryable &&
                _lastSavedEntry != null
            ? () => unawaited(_retryRemoteProcessingForLastEntry())
            : null,
      ),
    ];
  }
}
