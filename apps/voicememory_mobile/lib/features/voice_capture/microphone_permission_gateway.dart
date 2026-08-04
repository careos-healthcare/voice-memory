import 'package:permission_handler/permission_handler.dart';

/// Platform microphone permission reads — injectable for tests.
abstract class MicrophonePermissionGateway {
  Future<PermissionStatus> get status;
  Future<PermissionStatus> request();

  /// Recorder-package permission when the gateway can model it.
  ///
  /// Production returns `null` and lets the recording adapter perform the
  /// check. Test gateways return a deterministic value without global flags.
  Future<bool?> recorderPermission({bool request = false}) async => null;
}

class PermissionHandlerMicrophoneGateway
    implements MicrophonePermissionGateway {
  @override
  Future<PermissionStatus> get status => Permission.microphone.status;

  @override
  Future<PermissionStatus> request() => Permission.microphone.request();

  @override
  Future<bool?> recorderPermission({bool request = false}) async => null;
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

  @override
  Future<bool?> recorderPermission({bool request = false}) async => hasRecorder;
}
