import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nativeRecorderChannel = MethodChannel('archive_me/ios_native_recorder');

  var nativeMicResponse = <String, Object>{
    'status': 'granted',
    'granted': true,
    'canRequest': false,
  };

  setUp(() {
    nativeMicResponse = <String, Object>{
      'status': 'granted',
      'granted': true,
      'canRequest': false,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRecorderChannel, (call) async {
          switch (call.method) {
            case 'isNativeRecorderAvailable':
              return true;
            case 'nativeMicrophonePermission':
            case 'requestNativeMicrophonePermission':
              return nativeMicResponse;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRecorderChannel, null);
    MicrophonePermissionEnvironment.resetForTest();
  });
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
    'simulator policy: permanentlyDenied + hasRecorder starts recording when flagged',
    () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final recording = RecordingService.create(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.permanentlyDenied,
          hasRecorder: true,
        ),
        hasRecorderOverride: true,
      );

      await recording.startRecording();
      expect(recording.recorderStartCallCount, 1);
    },
  );

  test(
    'physical iOS native permission resolves to ready when recorder grants',
    () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      nativeMicResponse = <String, Object>{
        'status': 'granted',
        'granted': true,
        'canRequest': false,
      };
      final recording = RecordingService.create(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.permanentlyDenied,
          hasRecorder: true,
        ),
        hasRecorderOverride: true,
      );

      final resolution = await recording.evaluateMicrophonePermission();
      expect(resolution.state, MicrophonePermissionState.granted);
      expect(resolution.phase, RecordingPhase.ready);
    },
  );

  test(
    'RecordingService does not start when native microphone is denied',
    () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      nativeMicResponse = <String, Object>{
        'status': 'denied',
        'granted': false,
        'canRequest': false,
      };
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
