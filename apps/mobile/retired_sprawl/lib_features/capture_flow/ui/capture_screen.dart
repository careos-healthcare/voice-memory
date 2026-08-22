import 'dart:async';

import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_controller.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_routine_launch_controller.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/local_transcription_unavailable_card.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/speech_language_choice_card.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/post_save/moment_save_receipt_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/record/correct_transcript_sheet.dart';
import 'package:archiveme_mobile/widgets/record/moment_save_receipt_card.dart';
import 'package:archiveme_mobile/widgets/record/pending_transcript_recovery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Strangler capture screen — declarative UI bound to [CaptureFlowController].
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.initialInputMode = CaptureInputMode.voice,
    this.attachToEntryId,
    this.initialTypedText,
    this.routineKindOverride,
    this.accountDependencies,
    this.navigationActivityController,
    this.dependencies,
    this.allowBackgroundRecording = false,
    this.adoptBackgroundCapture = false,
    this.stopBackgroundCapture,
  });

  final CaptureInputMode initialInputMode;
  final String? attachToEntryId;
  final String? initialTypedText;
  final JournalRoutineKind? routineKindOverride;

  final V1AccountDependencies? accountDependencies;
  final RecordNavigationActivityController? navigationActivityController;
  final CaptureFlowDependencies? dependencies;
  final bool allowBackgroundRecording;
  final bool adoptBackgroundCapture;
  final Future<void> Function()? stopBackgroundCapture;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late final CaptureFlowController _controller;
  late final TextEditingController _typedController;
  late final V1AccountDependencies _accountDeps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountDeps =
        widget.accountDependencies ?? V1AccountDependencies.fromAppServices();
    _controller = CaptureFlowController(
      widget.dependencies ??
          CaptureFlowDependencies.fromAccount(_accountDeps),
      attachToEntryId: widget.attachToEntryId,
      routineKindOverride:
          widget.routineKindOverride ??
          CaptureRoutineLaunchController.takePendingRoutine(),
      stopBackgroundCapture: widget.stopBackgroundCapture,
    );
    _typedController = TextEditingController(text: widget.initialTypedText ?? '');
    _controller.addListener(_syncNavigationActivity);
    _controller.setInputMode(widget.initialInputMode);
    unawaited(_controller.initialize().then((_) {
      if (!mounted || !widget.adoptBackgroundCapture) return;
      _controller.showBackgroundRecordingUi();
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_syncNavigationActivity);
    _controller.dispose();
    _typedController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !widget.allowBackgroundRecording &&
        _controller.snapshot.phase == CaptureFlowPhase.recording) {
      unawaited(_controller.stopVoiceCapture());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.recoverPendingCapture());
    }
  }

  void _syncNavigationActivity() {
    final nav = widget.navigationActivityController;
    if (nav == null) return;
    final phase = _controller.snapshot.phase;
    final activity = switch (phase) {
      CaptureFlowPhase.requestingPermission =>
        RecordNavigationActivity.requestingPermission,
      CaptureFlowPhase.recording => RecordNavigationActivity.recording,
      CaptureFlowPhase.stopping ||
      CaptureFlowPhase.savingLocal ||
      CaptureFlowPhase.processingRemote =>
        RecordNavigationActivity.processing,
      _ => RecordNavigationActivity.idle,
    };
    nav.update(activity);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final snapshot = _controller.snapshot;
        return ColoredBox(
          color: AppColors.backgroundPrimary,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBody(context, snapshot),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CaptureFlowSnapshot snapshot) {
    if (snapshot.showsPostSave && snapshot.savedEntry != null) {
      return _buildReceipt(context, snapshot);
    }

    return switch (snapshot.phase) {
      CaptureFlowPhase.ready => CaptureReadyPanel(
        inputMode: snapshot.inputMode,
        attachMode: snapshot.isAttachMode,
        onStartVoice: _controller.startVoiceCapture,
        onSaveTyped: _controller.saveTypedCapture,
        onSwitchMode: _controller.setInputMode,
        permissionBlocked: snapshot.permissionBlocked,
        permissionRequiresSettings: snapshot.permissionRequiresSettings,
        errorMessage: snapshot.errorMessage,
        typedController: _typedController,
        saving: false,
        routinePrompt: snapshot.showsRoutinePrompt ? snapshot.routinePrompt : null,
        routinePromptLoading: snapshot.routinePromptLoading,
        onSelectRoutinePrompt: _handleRoutinePromptSelected,
        onDismissRoutinePrompt: _controller.dismissRoutinePrompt,
      ),
      CaptureFlowPhase.requestingPermission ||
      CaptureFlowPhase.stopping ||
      CaptureFlowPhase.savingLocal ||
      CaptureFlowPhase.processingRemote => CaptureBusyPanel(
        label: snapshot.stageLabel,
      ),
      CaptureFlowPhase.recording => CaptureRecordingPanel(
        duration: snapshot.recordingDuration,
        onStop: _controller.stopVoiceCapture,
        onCancel: _controller.cancelVoiceCapture,
      ),
      CaptureFlowPhase.recoverableFailure => CaptureFailurePanel(
        message: snapshot.errorMessage ?? 'Something went wrong.',
        hasLocalSave: snapshot.hasLocalSave,
        onRetry: snapshot.hasLocalSave ? _controller.retryRemoteProcessing : null,
        onDismiss: _controller.resetToReady,
      ),
      CaptureFlowPhase.savedLocal ||
      CaptureFlowPhase.savedWithReflection => const SizedBox.shrink(),
    };
  }

  Widget _buildReceipt(BuildContext context, CaptureFlowSnapshot snapshot) {
    final entry = snapshot.savedEntry!;
    final pipeline = snapshot.pipelineResult;
    final remoteStatus = pipeline == null
        ? MomentSaveRemoteStatus.none
        : resolveMomentSaveRemoteStatus(
            analysisSucceeded: pipeline.analysisSucceeded,
            syncNote: pipeline.syncNote,
          );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snapshot.transcriptionChoiceRequired)
            LocalTranscriptionUnavailableCard(
              onChoice: (allowRemote) => unawaited(
                _controller.resolveTranscriptionChoice(
                  allowRemote: allowRemote,
                ),
              ),
            ),
          if (snapshot.speechLocaleChoiceRequired)
            SpeechLanguageChoiceCard(
              onConfirmed: (locale) =>
                  unawaited(_controller.resolveSpeechLocale(locale)),
            ),
          MomentSaveReceiptCard(
            entry: entry,
            entryCount: snapshot.entryCount,
            remoteStatus: remoteStatus,
            syncNote: pipeline?.syncNote,
            onRecordAnother: _controller.resetToReady,
            onViewArchive: () => context.go('/archive-belief'),
            onRetryRemote: remoteStatus == MomentSaveRemoteStatus.failedRetryable
                ? _controller.retryRemoteProcessing
                : null,
            onCorrectText: TranscriptCorrectionGate.entryAllowsCorrection(entry)
                ? () => unawaited(_openTranscriptCorrection(entry))
                : null,
            onTypeWhatYouSaid: VoiceCaptureQuality.isDegradedVoiceCapture(entry)
                ? () => unawaited(_openPendingTranscriptRecovery(entry))
                : null,
          ),
        ],
      ),
    );
  }

  void _handleRoutinePromptSelected(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _typedController.text = trimmed;
    _controller.setInputMode(CaptureInputMode.typed);
    _controller.dismissRoutinePrompt();
  }

  Future<void> _openTranscriptCorrection(JournalEntry entry) async {
    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: 'capture_receipt',
      entryCount: _controller.snapshot.entryCount,
    );
    if (updated == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(TranscriptCorrectionCopy.savedSuccess)),
    );
    await _controller.applyTranscriptCorrection(updated);
  }

  Future<void> _openPendingTranscriptRecovery(JournalEntry entry) async {
    final result = await PendingTranscriptRecovery.open(
      context,
      entry: entry,
      source: 'capture_receipt',
      entryCount: _controller.snapshot.entryCount,
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(PendingTranscriptRecoveryCopy.savedSuccess)),
    );
    await _controller.completeReturningUserSave(result);
  }
}
