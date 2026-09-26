import 'dart:async';

import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/capture/entry_image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:archiveme_mobile/core/config/live_conversation_feature_flags.dart';
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
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:archiveme_mobile/widgets/record/correct_transcript_sheet.dart';
import 'package:archiveme_mobile/widgets/record/moment_save_receipt_card.dart';
import 'package:archiveme_mobile/widgets/record/pending_transcript_recovery_sheet.dart';
import 'package:archiveme_mobile/services/app_services.dart';
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
    this.autoRecord = false,
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
  final bool autoRecord;
  final Future<void> Function()? stopBackgroundCapture;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late final CaptureFlowController _controller;
  late final TextEditingController _typedController;
  var _reflect = false;

  V1AccountDependencies get _accountDeps =>
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CaptureFlowController(
      widget.dependencies ?? CaptureFlowDependencies.fromAccount(_accountDeps),
      attachToEntryId: widget.attachToEntryId,
      routineKindOverride:
          widget.routineKindOverride ??
          CaptureRoutineLaunchController.takePendingRoutine(),
      stopBackgroundCapture: widget.stopBackgroundCapture,
    );
    _typedController = TextEditingController(
      text: widget.initialTypedText ?? '',
    );
    _controller.addListener(_syncNavigationActivity);
    _controller.setInputMode(widget.initialInputMode);
    unawaited(_loadReflectChoice());
    unawaited(
      _controller.initialize().then((_) {
        if (!mounted) return;
        if (widget.adoptBackgroundCapture) {
          _controller.showBackgroundRecordingUi();
        } else if (widget.autoRecord) {
          unawaited(_controller.startVoiceCapture());
        }
      }),
    );
  }

  Future<void> _loadReflectChoice() async {
    if (!LiveConversationFeatureFlags.enabled) return;
    final stored = AppServices.isInitialized
        ? await AppServices.instance.prefs.readBool('reflect_with_me')
        : null;
    if (!mounted) return;
    final enabled = stored ?? false;
    _controller.setReflectWithMe(enabled);
    setState(() => _reflect = enabled);
  }

  Future<void> _setReflect(bool value) async {
    _controller.setReflectWithMe(value);
    setState(() => _reflect = value);
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool('reflect_with_me', value);
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
      CaptureFlowPhase.processingRemote => RecordNavigationActivity.processing,
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
          color: context.palette.backgroundPrimary,
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
        microphoneGranted: snapshot.microphoneGranted,
        onPromptContext: _handlePromptContext,
        errorMessage: snapshot.errorMessage,
        typedController: _typedController,
        saving: false,
        routinePrompt: snapshot.showsRoutinePrompt
            ? snapshot.routinePrompt
            : null,
        routinePromptLoading: snapshot.routinePromptLoading,
        onSelectRoutinePrompt: _handleRoutinePromptSelected,
        onDismissRoutinePrompt: _controller.dismissRoutinePrompt,
        onAddPhoto: _addPhoto,
        imageCount: snapshot.attachedImages.length,
        leading: _reflectToggle(),
      ),
      CaptureFlowPhase.requestingPermission ||
      CaptureFlowPhase.stopping ||
      CaptureFlowPhase.savingLocal ||
      CaptureFlowPhase.processingRemote => CaptureBusyPanel(
        label: snapshot.stageLabel,
        savedOnDevice: snapshot.deviceSaveVisible,
        transcript: snapshot.savedEntry?.transcript,
      ),
      CaptureFlowPhase.recording => CaptureRecordingPanel(
        duration: snapshot.recordingDuration,
        levels: snapshot.amplitudeBars,
        paused: snapshot.recordingPaused,
        draftText: snapshot.draftTranscript,
        turns: snapshot.conversationTurns,
        chatLines: snapshot.chatLines,
        onStop: _controller.stopVoiceCapture,
        onPause: _controller.pauseVoiceCapture,
        onResume: _controller.resumeVoiceCapture,
        onCancel: _controller.cancelVoiceCapture,
        onTakePhoto: () => _addPhoto(ImageSource.camera),
        onChoosePhoto: () => _addPhoto(ImageSource.gallery),
        imagePaths: snapshot.attachedImages,
        onThatsAll: _reflect ? () => unawaited(_controller.endReflect()) : null,
      ),
      CaptureFlowPhase.recoverableFailure => CaptureFailurePanel(
        message: snapshot.errorMessage ?? 'Something went wrong.',
        hasLocalSave: snapshot.hasLocalSave,
        onRetry: snapshot.hasLocalSave
            ? _controller.retryRemoteProcessing
            : null,
        onDismiss: _controller.resetToReady,
      ),
      CaptureFlowPhase.savedLocal ||
      CaptureFlowPhase.savedWithReflection => const SizedBox.shrink(),
    };
  }

  Widget? _reflectToggle() {
    if (!LiveConversationFeatureFlags.enabled) return null;
    return SwitchListTile(
      key: const Key('reflect_with_me_toggle'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Reflect with me'),
      value: _reflect,
      onChanged: (value) => unawaited(_setReflect(value)),
    );
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
            onChooseWhatLeaves: () => context.push('/privacy-trust-centre'),
            onRetryRemote:
                remoteStatus == MomentSaveRemoteStatus.failedRetryable
                ? _controller.retryRemoteProcessing
                : null,
            onCorrectText: TranscriptCorrectionGate.entryAllowsCorrection(entry)
                ? () => unawaited(_openTranscriptCorrection(entry))
                : null,
            onTypeWhatYouSaid: VoiceCaptureQuality.isDegradedVoiceCapture(entry)
                ? () => unawaited(_openPendingTranscriptRecovery(entry))
                : null,
          ),
          if (V1CapabilityRegistry.photoAttachments)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('receipt_add_photo'),
                onPressed: () => unawaited(_addPhoto()),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Add a photo'),
              ),
            ),
        ],
      ),
    );
  }

  String? _promptContext;

  Future<void> _addPhoto([ImageSource source = ImageSource.gallery]) async {
    final saved = _controller.snapshot.savedEntry;
    final paths = await pickEntryImages(source: source, entryId: saved?.id);
    if (saved == null) {
      _controller.addPhotos(paths);
      return;
    }
    await _controller.attachPhotosToSavedEntry(paths);
  }

  void _handlePromptContext(String line) {
    _promptContext = line.trim();
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
