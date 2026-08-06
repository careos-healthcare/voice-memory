import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/recording/v1/record_view_state.dart';
import 'package:voicememory_mobile/features/recording/v1/record_view_state_mapper.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';

void main() {
  test('maps recording UI to V1 phases', () {
    expect(
      RecordViewStateMapper.phaseFromUi(RecordUiState.recording),
      RecordViewPhase.recording,
    );
    expect(
      RecordViewStateMapper.phaseFromUi(
        RecordUiState.done,
        hasVerifiedProof: true,
      ),
      RecordViewPhase.verifiedResultAvailable,
    );
  });
}
