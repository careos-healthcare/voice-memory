import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/app_routine_prompt_adapter.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/prefs_routine_anchor_loader.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/journal_transcript_correction_adapter.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/pipeline_capture_adapters.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/prefs_pending_capture_recovery_store.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/record_pipeline_capture_telemetry.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/recording_service_audio_adapter.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_choice_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';

/// Narrow dependency bundle for the strangler capture flow.
///
/// Does not import the legacy recording dependency barrel — only direct ports.
class CaptureFlowDependencies {
  const CaptureFlowDependencies({
    required this.audio,
    required this.moments,
    required this.consent,
    required this.transcription,
    required this.reflection,
    required this.recovery,
    required this.telemetry,
    required this.transcriptCorrection,
    required this.routinePrompts,
    required this.routineAnchors,
    required this.transcriptionCapability,
  });

  factory CaptureFlowDependencies.fromAccount(
    V1AccountDependencies account, {
    AudioRecorderAdapter? audio,
    CaptureTelemetry? telemetry,
    PendingCaptureRecoveryStore? recovery,
    TranscriptCorrectionPort? transcriptCorrection,
    RoutinePromptGateway? routinePrompts,
    RoutineAnchorLoader? routineAnchors,
    TranscriptionCapabilityPort? transcriptionCapability,
  }) {
    final consentPolicy = StoreRemoteConsentPolicy(account.pipeline.consentStore);
    return CaptureFlowDependencies(
      audio: audio ?? RecordingServiceAudioAdapter(account.recording),
      moments: PipelineLocalMomentRepository(
        pipeline: account.pipeline,
        journalStore: account.journalStore,
      ),
      consent: consentPolicy,
      transcription: PipelineRemoteTranscriptionGateway(consentPolicy),
      reflection: PipelineRemoteReflectionGateway(consentPolicy),
      recovery:
          recovery ?? PrefsPendingCaptureRecoveryStore(account.prefs),
      telemetry: telemetry ?? RecordPipelineCaptureTelemetry(),
      transcriptCorrection: transcriptCorrection ??
          JournalTranscriptCorrectionAdapter(account.journalStore),
      routinePrompts: routinePrompts ??
          AppRoutinePromptAdapter(journalStore: account.journalStore),
      routineAnchors: routineAnchors ??
          PrefsRoutineAnchorLoader(account.prefs),
      transcriptionCapability: transcriptionCapability ??
          StoreTranscriptionCapabilityPolicy(
            consentStore: account.pipeline.consentStore,
            choiceStore: LocalTranscriptionChoiceStore(account.prefs),
            speechLocaleStore: SpeechLocaleStore(account.prefs),
            consentPolicy: consentPolicy,
          ),
    );
  }

  final AudioRecorderAdapter audio;
  final LocalMomentRepository moments;
  final RemoteConsentPolicy consent;
  final RemoteTranscriptionGateway transcription;
  final RemoteReflectionGateway reflection;
  final PendingCaptureRecoveryStore recovery;
  final CaptureTelemetry telemetry;
  final TranscriptCorrectionPort transcriptCorrection;
  final RoutinePromptGateway routinePrompts;
  final RoutineAnchorLoader routineAnchors;
  final TranscriptionCapabilityPort transcriptionCapability;
}
