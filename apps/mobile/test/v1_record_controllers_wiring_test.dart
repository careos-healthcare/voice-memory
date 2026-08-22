import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/recording/v1/capture_processing_controller.dart';
import 'package:archiveme_mobile/features/recording/v1/microphone_permission_controller.dart';
import 'package:archiveme_mobile/features/recording/v1/post_save_result_controller.dart';
import 'package:archiveme_mobile/features/recording/v1/record_screen_view_model.dart';
import 'package:archiveme_mobile/features/recording/v1/record_view_state.dart';
import 'package:archiveme_mobile/features/recording/v1/record_view_state_mapper.dart';
import 'package:archiveme_mobile/features/recording/v1/recording_recovery_controller.dart';
import 'package:archiveme_mobile/features/recording/v1/recording_session_controller.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('microphone permission controller tracks session denial', () {
    final mic = MicrophonePermissionController();
    mic.applyPhase(RecordingPhase.permissionDenied, userDenied: true);

    expect(mic.userDeniedThisSession, isTrue);
    expect(mic.uiState, RecordUiState.permissionBlocked);
  });

  test('capture processing controller exposes active pipeline state', () {
    final capture = CaptureProcessingController();
    capture.begin(stage: 'Transcribing…');
    expect(capture.isActive, isTrue);
    expect(capture.stageLabel, 'Transcribing…');

    capture.end();
    expect(capture.isActive, isFalse);
    expect(capture.stageLabel, isNull);
  });

  test('post-save controller marks local and verified results', () {
    final postSave = PostSaveResultController();
    postSave.markLocallySaved(entryId: 'entry-1', title: 'Saved locally');
    expect(postSave.showPostSave, isTrue);
    expect(postSave.savedEntryId, 'entry-1');
    expect(postSave.hasVerifiedProof, isFalse);

    postSave.markVerifiedResult();
    expect(postSave.hasVerifiedProof, isTrue);

    postSave.reset();
    expect(postSave.showPostSave, isFalse);
    expect(postSave.savedEntryId, isNull);
  });

  test('record view mapper reflects verified post-save phase', () {
    final view = RecordViewStateMapper.fromUi(
      ui: RecordUiState.done,
      savedEntryId: 'entry-1',
      hasVerifiedProof: true,
    );
    expect(view.phase, RecordViewPhase.verifiedResultAvailable);
    expect(view.showsPostSave, isTrue);
  });

  test('record screen view model aggregates controller state', () {
    final session = RecordingSessionController();

    final capture = CaptureProcessingController();
    capture.begin(stage: 'Saving…');

    final postSave = PostSaveResultController();
    postSave.markLocallySaved(entryId: 'entry-42', title: 'Saved');

    final viewModel = RecordScreenViewModel(
      session: session,
      microphone: MicrophonePermissionController(),
      capture: capture,
      postSave: postSave,
      recovery: RecordingRecoveryController(),
      ui: RecordUiState.processing,
    );

    expect(viewModel.viewState.statusMessage, 'Saving…');
    expect(viewModel.viewState.savedEntryId, 'entry-42');
    expect(viewModel.viewState.phase, RecordViewPhase.processing);
  });

  test('recovery controller tracks transcript recovery visibility', () {
    final recovery = RecordingRecoveryController();
    expect(recovery.pendingTranscriptRecoveryVisible, isFalse);

    recovery.showPendingTranscriptRecovery();
    expect(recovery.pendingTranscriptRecoveryVisible, isTrue);

    recovery.hidePendingTranscriptRecovery();
    expect(recovery.pendingTranscriptRecoveryVisible, isFalse);

    recovery.markInterruptedCapture();
    recovery.markVaultRecoveryScheduled();
    recovery.resetSession();
    expect(recovery.interruptedCapture, isFalse);
    expect(recovery.vaultRecoveryScheduled, isFalse);
  });
}