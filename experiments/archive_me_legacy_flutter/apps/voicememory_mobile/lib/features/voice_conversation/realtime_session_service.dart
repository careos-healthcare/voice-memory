import 'package:uuid/uuid.dart';

import '../../api/voice_capture_api_client.dart';
import '../../services/capture_attest_service.dart';
import 'realtime_session_config.dart';

abstract interface class RealtimeSessionMinter {
  Future<RealtimeSessionConfig> mint();
}

class RealtimeSessionService implements RealtimeSessionMinter {
  const RealtimeSessionService({required this.api, required this.attest});

  final VoiceCaptureApiClient api;
  final CaptureAttestService attest;

  @override
  Future<RealtimeSessionConfig> mint() async {
    final token = await attest.ensureCaptureToken();
    return api.postVoiceSession(
      captureToken: token,
      idempotencyKey: const Uuid().v4(),
    );
  }
}
