import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MicrophonePermissionEnvironment.resetForTest);

  test('RecordingException exposes message', () {
    final e = RecordingException('mic denied');
    expect(e.toString(), 'mic denied');
  });

  test('RecordingPhase enum covers permission states', () {
    expect(RecordingPhase.permissionDenied, isNot(RecordingPhase.ready));
    expect(RecordingPhase.values, contains(RecordingPhase.permissionDenied));
  });

  test(
    'simulator policy: permanentlyDenied + hasRecorder prefers recorder when flagged',
    () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.permanentlyDenied,
          hasRecorder: true,
          preferRecorderOnIosSimulator: true,
        ),
        MicrophonePermissionState.granted,
      );
    },
  );

  test(
    'simulator policy: restricted + hasRecorder prefers recorder when flagged',
    () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.restricted,
          hasRecorder: true,
          preferRecorderOnIosSimulator: true,
        ),
        MicrophonePermissionState.granted,
      );
    },
  );

  test(
    'simulator policy: denied platform status stays not ready without prefer flag',
    () {
      final state = MicrophonePermissionResolver.resolve(
        status: PermissionStatus.denied,
        hasRecorder: true,
      );
      expect(
        MicrophonePermissionResolver.toRecordingPhase(state),
        isNot(RecordingPhase.ready),
      );
    },
  );

  test(
    'permanentlyDenied does not start recording from a recorder override',
    () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final recording = RecordingService.create(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.permanentlyDenied,
        ),
        hasRecorderOverride: true,
      );

      await expectLater(
        recording.startRecording(),
        throwsA(isA<RecordingException>()),
      );
      expect(recording.recorderStartCallCount, 0);
    },
  );

  test(
    'physical iOS uses the OS status when the recorder plugin disagrees',
    () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final recording = RecordingService.create(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.permanentlyDenied,
        ),
        hasRecorderOverride: true,
      );

      final resolution = await recording.evaluateMicrophonePermission();
      expect(resolution.state, MicrophonePermissionState.deniedOpenSettings);
      expect(
        resolution.phase,
        RecordingPhase.permissionPermanentlyDenied,
      );
    },
  );

  test(
    'RecordingService does not start when microphone is denied',
    () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final recording = RecordingService.create(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.denied,
          hasRecorder: false,
        ),
        hasRecorderOverride: false,
      );
      await expectLater(
        recording.startRecording(),
        throwsA(isA<RecordingException>()),
      );
      expect(recording.recorderStartCallCount, 0);
    },
  );
}
