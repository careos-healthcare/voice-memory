import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_state.dart';

void main() {
  const initial = LiveVoiceSessionState(
    phase: LiveVoiceUiPhase.starting,
    sessionState: LiveSessionState.connecting,
    errorState: LiveVoiceErrorState.none,
  );

  test('session snapshots expose action and speaking transitions', () {
    final active = initial.copyWith(
      phase: LiveVoiceUiPhase.active,
      sessionState: LiveSessionState.streaming,
      playbackQueueDepth: 2,
      transcript: 'I noticed the pattern earlier.',
    );

    expect(active.showActions, isTrue);
    expect(active.transcript, contains('earlier'));
    expect(active.playbackQueueDepth, 2);
    expect(active.visualState, isNotNull);
  });

  test('fault snapshots suppress session actions', () {
    final failed = initial.copyWith(
      phase: LiveVoiceUiPhase.error,
      errorState: LiveVoiceErrorState.unknown,
    );

    expect(failed.hasError, isTrue);
    expect(failed.showActions, isFalse);
  });
}
