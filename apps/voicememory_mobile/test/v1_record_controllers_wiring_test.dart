import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/features/recording/v1/capture_processing_controller.dart';
import 'package:voicememory_mobile/features/recording/v1/microphone_permission_controller.dart';
import 'package:voicememory_mobile/features/recording/v1/post_save_result_controller.dart';
import 'package:voicememory_mobile/features/recording/v1/record_view_state.dart';
import 'package:voicememory_mobile/features/recording/v1/record_view_state_mapper.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';

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
}
