part of '../recording_screen.dart';

extension RecordingControlsWidget on _RecordScreenState {
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
                unawaited(ActivationTracker.trackActivationStarterPromptSelected());
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
                unawaited(context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source:
                        PaywallSource.fromId(intent.source) ??
                        PaywallSource.generalPro,
                    sourceRoute: '/record',
                  ),
                ));
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
      final auditEntries = VisualAuditOverrides.active
          ? VisualAuditOverrides.peekRecordPresentation()?.entriesAfterSave
          : null;
      final hasPostSaveEntries =
          _entriesAfterSave.isNotEmpty ||
          (auditEntries != null && auditEntries.isNotEmpty);
      if (V1FeatureFlags.enableV1Only && hasPostSaveEntries) {
        return actions;
      }
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
