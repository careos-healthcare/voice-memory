import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';

import 'capture_processing_controller.dart';
import 'microphone_permission_controller.dart';
import 'post_save_result_controller.dart';
import 'record_view_state.dart';
import 'record_view_state_mapper.dart';
import 'recording_recovery_controller.dart';
import 'recording_session_controller.dart';

/// Aggregates V1 record controllers into a single immutable [RecordViewState].
///
/// Widgets that only need phase/duration should listen to [viewState] rather
/// than the full record screen state object.
class RecordScreenViewModel {
  RecordScreenViewModel({
    required this.session,
    required this.microphone,
    required this.capture,
    required this.postSave,
    required this.recovery,
    this.ui = RecordUiState.idle,
    this.errorMessage,
  });

  final RecordingSessionController session;
  final MicrophonePermissionController microphone;
  final CaptureProcessingController capture;
  final PostSaveResultController postSave;
  final RecordingRecoveryController recovery;

  RecordUiState ui;
  String? errorMessage;

  RecordViewState get viewState {
    return RecordViewStateMapper.fromUi(
      ui: ui,
      recordingDuration: Duration(seconds: session.seconds),
      statusMessage: capture.stageLabel,
      errorMessage: errorMessage,
      savedEntryId: postSave.savedEntryId,
      hasVerifiedProof: postSave.hasVerifiedProof,
    );
  }

  bool get showsRecoveryOffer => recovery.pendingTranscriptRecoveryVisible;
}
