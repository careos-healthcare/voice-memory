// Narrow production dependencies for the V1 Record surface.
//
// Do not turn this back into a compatibility barrel: every export becomes part
// of the shipping import graph.

export 'dart:async';

export 'package:flutter/material.dart';
export 'package:flutter/services.dart';
export 'package:go_router/go_router.dart';
export 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

export '../../audio/recording_service.dart' show RecordingPhase;
export '../../features/insight_feedback/insight_feedback_store.dart';
export '../../features/monetization/data/monetization_local_migration.dart';
export '../../features/monetization/data/product_value_delivery_recorder.dart';
export '../../features/monetization/domain/access_policy_engine.dart'
    show CapabilityId, EntitlementSnapshot, ProductValueState;
export '../../features/processing_preferences/processing_preferences_store.dart';
export '../../features/remote_transcription/remote_transcription_disclosure.dart';
export '../../features/remote_transcription/remote_transcription_disclosure_dialog.dart';
export '../../features/transcription_queue/transcription_queue_executor.dart'
    show TranscriptionQueueCompletion;
export '../../features/voice_capture/microphone_permission_copy.dart';
export '../../features/voice_capture/microphone_permission_gateway.dart';
export '../../features/voice_capture/microphone_permission_state.dart';
export '../../features/voice_capture/onboarding_microphone_state.dart';
export '../../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;
export '../../router/record_navigation_activity_controller.dart';
export '../../services/app_services.dart';
export '../../services/capture_pipeline_service.dart'
    show CapturePipelineResult;
export '../../services/focused_return_analytics.dart';
export '../../services/privacy/sensitive_temporary_audio_store.dart';
export '../../subscriptions/domain/subscription_models.dart'
    show SubscriptionState;
export '../../widgets/record/focused_auditable_post_save_section.dart';
export 'domain/application/capture_session_coordinator.dart';
export 'domain/application/interpretation_disposition_coordinator.dart';
export 'domain/application/on_device_transcription_availability.dart';
export 'domain/application/post_capture_disposition_coordinator.dart';
export 'domain/application/post_save_experience_coordinator.dart';
export 'domain/application/protected_temporary_audio_service.dart';
export 'domain/application/recording_permission_coordinator.dart';
export 'domain/application/recording_recovery_service.dart';
export 'domain/application/recording_ui_state_mapper.dart';
export 'domain/application/remote_transcription_coordinator.dart';
export 'domain/application/save_moment_coordinator.dart';
export 'domain/application/transcript_editing_service.dart';
export 'domain/application/vault_persistence_coordinator.dart';
export 'post_capture_choice_sheet.dart';
