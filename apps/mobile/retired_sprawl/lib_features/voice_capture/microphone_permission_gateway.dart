import 'package:permission_handler/permission_handler.dart';

/// Platform microphone permission reads — injectable for tests.
abstract class MicrophonePermissionGateway {
  Future<PermissionStatus> get status;
  Future<PermissionStatus> request();
}

class PermissionHandlerMicrophoneGateway
    implements MicrophonePermissionGateway {
  @override
  Future<PermissionStatus> get status => Permission.microphone.status;

  @override
  Future<PermissionStatus> request() => Permission.microphone.request();
}

/// Test double — simulates permission_handler + optional recorder mismatch.
class FakeMicrophonePermissionGateway implements MicrophonePermissionGateway {
  FakeMicrophonePermissionGateway({
    required this.statusValue,
    this.requestResult,
    this.hasRecorder = true,
    this.requestDelay,
  });

  PermissionStatus statusValue;
  PermissionStatus? requestResult;
  bool hasRecorder;
  Duration? requestDelay;

  int requestCallCount = 0;

  @override
  Future<PermissionStatus> get status async => statusValue;

  @override
  Future<PermissionStatus> request() async {
    requestCallCount++;
    if (requestDelay != null) {
      await Future<void>.delayed(requestDelay!);
    }
    final next = requestResult ?? statusValue;
    statusValue = next;
    return next;
  }
}