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
    required RecordingSessionController session,
    required MicrophonePermissionController microphone,
    required CaptureProcessingController capture,
    required PostSaveResultController postSave,
    required RecordingRecoveryController recovery,
    RecordUiState ui = RecordUiState.idle,
    this.errorMessage,
  }) : _session = session,
       _microphone = microphone,
       _capture = capture,
       _postSave = postSave,
       _recovery = recovery,
       _ui = ui;

  final RecordingSessionController _session;
  final MicrophonePermissionController _microphone;
  final CaptureProcessingController _capture;
  final PostSaveResultController _postSave;
  final RecordingRecoveryController _recovery;

  RecordUiState _ui;
  String? errorMessage;

  RecordUiState get ui => _ui;
  set ui(RecordUiState value) => _ui = value;

  RecordingSessionController get session => _session;
  MicrophonePermissionController get microphone => _microphone;
  CaptureProcessingController get capture => _capture;
  PostSaveResultController get postSave => _postSave;
  RecordingRecoveryController get recovery => _recovery;

  RecordViewState get viewState {
    return RecordViewStateMapper.fromUi(
      ui: _ui,
      recordingDuration: Duration(seconds: _session.seconds),
      statusMessage: _capture.stageLabel,
      errorMessage: errorMessage,
      savedEntryId: _postSave.savedEntryId,
      hasVerifiedProof: _postSave.hasVerifiedProof,
    );
  }

  bool get showsRecoveryOffer => _recovery.pendingTranscriptRecoveryVisible;
}
