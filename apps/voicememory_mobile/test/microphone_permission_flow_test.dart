import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/microphone_permission_blocked_panel.dart';
import 'package:voicememory_mobile/widgets/record/record_screen_close_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nativeRecorderChannel = MethodChannel('archive_me/ios_native_recorder');

  var nativeMicResponse = <String, Object>{
    'status': 'granted',
    'granted': true,
    'canRequest': false,
  };

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_mic_perm_');
    VisualAuditOverrides.setRecordPresentation(null);
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
    VisualAuditOverrides.setRecordPresentation(null);
    MicrophonePermissionEnvironment.resetForTest();
  });

  group('MicrophonePermissionResolver', () {
    test('simulator policy: denied + hasRecorder prefers recorder when flagged', () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.denied,
          hasRecorder: true,
          preferRecorderOnIosSimulator: true,
        ),
        MicrophonePermissionState.granted,
      );
    });

    test('simulator policy: permanentlyDenied + hasRecorder prefers recorder when flagged', () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.permanentlyDenied,
          hasRecorder: true,
          preferRecorderOnIosSimulator: true,
        ),
        MicrophonePermissionState.granted,
      );
    });

    test('simulator policy: denied status stays requestable without prefer flag', () {
      final state = MicrophonePermissionResolver.resolve(
        status: PermissionStatus.denied,
        hasRecorder: true,
      );
      expect(state, MicrophonePermissionState.deniedCanAskAgain);
      expect(
        MicrophonePermissionResolver.toRecordingPhase(state),
        RecordingPhase.permissionDenied,
      );
    });

    test(
      'physical iOS policy: denied + record.hasPermission true => grantedWithMismatch',
      () {
        expect(
          MicrophonePermissionResolver.resolve(
            status: PermissionStatus.denied,
            hasRecorder: true,
            allowPhysicalRecorderMismatch: true,
          ),
          MicrophonePermissionState.grantedWithPermissionHandlerMismatch,
        );
        expect(
          MicrophonePermissionResolver.toRecordingPhase(
            MicrophonePermissionResolver.resolve(
              status: PermissionStatus.denied,
              hasRecorder: true,
              allowPhysicalRecorderMismatch: true,
            ),
          ),
          RecordingPhase.ready,
        );
      },
    );

    test(
      'physical iOS policy: permanentlyDenied + record.hasPermission true => grantedWithMismatch',
      () {
        expect(
          MicrophonePermissionResolver.resolve(
            status: PermissionStatus.permanentlyDenied,
            hasRecorder: true,
            allowPhysicalRecorderMismatch: true,
          ),
          MicrophonePermissionState.grantedWithPermissionHandlerMismatch,
        );
      },
    );

    test('physical iOS policy without mismatch flag stays requestable', () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.denied,
          hasRecorder: true,
        ),
        MicrophonePermissionState.deniedCanAskAgain,
      );
    });

    test(
      'physical iOS policy: permanentlyDenied + record.hasPermission false => Open Settings',
      () {
        expect(
          MicrophonePermissionResolver.resolve(
            status: PermissionStatus.permanentlyDenied,
            hasRecorder: false,
          ),
          MicrophonePermissionState.deniedOpenSettings,
        );
      },
    );

    test(
      'physical iOS policy: denied + record.hasPermission false => deniedCanAskAgain',
      () {
        expect(
          MicrophonePermissionResolver.resolve(
            status: PermissionStatus.denied,
            hasRecorder: false,
          ),
          MicrophonePermissionState.deniedCanAskAgain,
        );
      },
    );

    test('granted + record.hasPermission true => ready', () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.granted,
          hasRecorder: true,
        ),
        MicrophonePermissionState.granted,
      );
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.granted,
          hasRecorder: false,
        ),
        MicrophonePermissionState.deniedCanAskAgain,
      );
    });

    test('simulator policy: permanentlyDenied without recorder => open settings', () {
      final state = MicrophonePermissionResolver.resolve(
        status: PermissionStatus.permanentlyDenied,
        hasRecorder: false,
      );
      expect(state, MicrophonePermissionState.deniedOpenSettings);
    });

    test('simulator policy: permanentlyDenied with recorder still => open settings without prefer flag', () {
      expect(
        MicrophonePermissionResolver.resolve(
          status: PermissionStatus.permanentlyDenied,
          hasRecorder: true,
        ),
        MicrophonePermissionState.deniedOpenSettings,
      );
    });
  });

  group('RecordingService permission flow', () {
    test('simulator policy: permanentlyDenied + hasRecorder prefers recorder in service', () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.permanentlyDenied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      final resolution = await recording.evaluateMicrophonePermission();
      expect(resolution.state, MicrophonePermissionState.granted);
      expect(resolution.phase, RecordingPhase.ready);
    });

    test('simulator policy: denied + hasRecorder prefers recorder in service', () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.ready);
    });

    test('simulator policy: denied + no recorder stays requestable', () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: false,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: false,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.permissionDenied);
    });

    test('physical iOS native granted resolves to ready', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.ready);
      final resolution = await recording.evaluateMicrophonePermission();
      expect(
        resolution.state,
        MicrophonePermissionState.granted,
      );
    });

    test('physical iOS policy allows recording on mismatch denied + hasRecorder', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.ready);
      await recording.startRecording();
      expect(recording.recorderStartCallCount, 1);
    });

    test('physical iOS native granted overrides permission_handler permanentlyDenied', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.permanentlyDenied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.ready);
      final resolution = await recording.evaluateMicrophonePermission();
      expect(
        resolution.state,
        MicrophonePermissionState.granted,
      );
    });

    test('physical iOS skips permission request when recorder verified', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.requestMicrophone(), RecordingPhase.ready);
      expect(gateway.requestCallCount, 0);
    });

    test('physical iOS native permanentlyDenied without recorder is unavailable', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      nativeMicResponse = <String, Object>{
        'status': 'permanentlyDenied',
        'granted': false,
        'canRequest': false,
      };
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.permanentlyDenied,
        hasRecorder: false,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: false,
      );

      expect(
        await recording.checkMicrophone(),
        RecordingPhase.error,
      );
      final resolution = await recording.evaluateMicrophonePermission();
      expect(resolution.state, MicrophonePermissionState.unavailable);
    });

    test('startRecording does not start recorder when non-simulator policy denies', () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(false);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      await expectLater(
        recording.startRecording(),
        throwsA(isA<RecordingException>()),
      );
      expect(recording.recorderStartCallCount, 0);
    });

    test('startRecording starts recorder on simulator mismatch denied + hasRecorder', () async {
      MicrophonePermissionEnvironment.setIosSimulatorForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      await recording.startRecording();
      expect(recording.recorderStartCallCount, 1);
    });

    test('granted permission can enter recording flow in test mode', () async {
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.granted,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.checkMicrophone(), RecordingPhase.ready);
      await recording.startRecording();
      expect(recording.recorderStartCallCount, 1);
    });

    test('requestMicrophone logs request and re-checks', () async {
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        requestResult: PermissionStatus.granted,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.requestMicrophone(), RecordingPhase.ready);
      expect(gateway.requestCallCount, 1);
    });

    test('startRecording with permissionVerified allows recorder on physical mismatch', () async {
      MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      await recording.startRecording(permissionVerified: true);
      expect(recording.recorderStartCallCount, 1);
    });

    test('startRecording with permissionVerified starts when permission_handler granted', () async {
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.granted,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      await recording.startRecording(permissionVerified: true);
      expect(recording.recorderStartCallCount, 1);
    });
  });

  group('RecordMicrophonePermissionUi', () {
    test('can-ask-again before user denial keeps ready UI for first record CTA', () {
      expect(
        RecordMicrophonePermissionUi.uiForMicPhase(
          phase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        RecordUiState.ready,
      );
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: RecordUiState.ready,
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        isFalse,
      );
    });

    test('requestingPermission hides blocked panel', () {
      expect(
        RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(
          RecordUiState.requestingPermission,
        ),
        isTrue,
      );
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: RecordUiState.requestingPermission,
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: true,
        ),
        isFalse,
      );
    });

    test('user-initiated refresh applies while requestingPermission', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.ready,
        userDeniedThisSession: true,
        currentUi: RecordUiState.requestingPermission,
        ignoreAfterGrant: false,
        fromUserRequest: true,
      );
      expect(applied.ignored, isFalse);
      expect(applied.ui, RecordUiState.ready);
      expect(applied.userDenied, isFalse);
    });

    test('passive refresh is ignored while requestingPermission', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.requestingPermission,
        ignoreAfterGrant: false,
        fromUserRequest: false,
      );
      expect(applied.ignored, isTrue);
    });

    test('user denial maps to permissionBlocked with Open Settings path', () {
      expect(
        RecordMicrophonePermissionUi.uiForMicPhase(
          phase: RecordingPhase.permissionDenied,
          userDeniedThisSession: true,
        ),
        RecordUiState.permissionBlocked,
      );
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: true,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
    });

    test('permanent denial maps to permissionBlocked with Open Settings path', () {
      expect(
        RecordMicrophonePermissionUi.uiForMicPhase(
          phase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: false,
        ),
        RecordUiState.permissionBlocked,
      );
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: false,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
    });

    test('initial deniedCanAskAgain refresh keeps requestable ready UI', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.idle,
        ignoreAfterGrant: false,
        fromUserRequest: false,
      );
      expect(applied.initialDeniedCanAskAgain, isTrue);
      expect(applied.ui, RecordUiState.ready);
      expect(applied.userDenied, isFalse);
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: applied.ui!,
          micPhase: applied.mic!,
          userDeniedThisSession: applied.userDenied!,
        ),
        isFalse,
      );
    });

    test('initial deniedCanAskAgain does not render Open Settings panel kind', () {
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        MicrophoneBlockedPanelKind.none,
      );
    });

    test('CTA for grantedWithPermissionHandlerMismatch is Record moment', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.ready,
        micPermissionState:
            MicrophonePermissionState.grantedWithPermissionHandlerMismatch,
      );
      expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
      expect(policy.action, RecordCtaAction.startRecording);
    });

    test('record CTA routes to start when microphone is granted', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.ready,
          userDeniedThisSession: false,
        ),
        RecordCtaAction.startRecording,
      );
    });

    test('record CTA routes to request permission for first deniedCanAskAgain', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        RecordCtaAction.requestPermission,
      );
    });

    test('record CTA routes to open settings after session denial', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: true,
        ),
        RecordCtaAction.openSettings,
      );
      expect(
        RecordMicrophonePermissionUi.micBlockedStateLabel(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: true,
        ),
        'deniedThisSession',
      );
    });

    test('record CTA routes to open settings when permanently denied', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: false,
        ),
        RecordCtaAction.openSettings,
      );
      expect(
        RecordMicrophonePermissionUi.micBlockedStateLabel(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: false,
        ),
        'permanentlyDenied',
      );
    });

    test('competing record CTAs hide when blocked panel is shown', () {
      expect(
        RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
          ui: RecordUiState.permissionBlocked,
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        isTrue,
      );
      expect(
        RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
          ui: RecordUiState.ready,
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        isFalse,
      );
    });

    test('permanentlyDenied on launch renders Open Settings panel kind', () {
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: false,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: RecordUiState.permissionBlocked,
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        isTrue,
      );
    });

    test('granted result clears denied flags and blocked UI', () {
      final granted = RecordMicrophonePermissionUi.onPermissionGranted();
      expect(granted.userDenied, isFalse);
      expect(granted.mic, RecordingPhase.ready);
      expect(granted.ignoreStaleRefreshAfterGrant, isTrue);
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: granted.uiBeforeRecording,
          micPhase: RecordingPhase.ready,
          userDeniedThisSession: false,
        ),
        isFalse,
      );
    });

    test('stale refresh after grant is ignored while recording', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionPermanentlyDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.recording,
        ignoreAfterGrant: true,
        fromUserRequest: false,
      );
      expect(applied.ignored, isTrue);
      expect(applied.ui, isNull);
    });

    test('stale refresh with ignoreAfterGrant does not reopen blocked panel', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionPermanentlyDenied,
        userDeniedThisSession: true,
        currentUi: RecordUiState.ready,
        ignoreAfterGrant: true,
        fromUserRequest: false,
      );
      expect(applied.ignored, isTrue);
    });

    test('passive refresh preserves session denial for deniedCanAskAgain', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: true,
        currentUi: RecordUiState.permissionBlocked,
        ignoreAfterGrant: false,
        fromUserRequest: false,
      );
      expect(applied.userDenied, isTrue);
      expect(applied.ui, RecordUiState.permissionBlocked);
      expect(applied.sessionRequiresOpenSettings, isFalse);
    });

    test('passive refresh preserves permanentlyDenied session block', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: true,
        currentUi: RecordUiState.permissionBlocked,
        ignoreAfterGrant: false,
        fromUserRequest: false,
        sessionRequiresOpenSettings: true,
      );
      expect(applied.userDenied, isTrue);
      expect(applied.ui, RecordUiState.permissionBlocked);
      expect(applied.sessionRequiresOpenSettings, isTrue);
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: applied.mic!,
          userDeniedThisSession: applied.userDenied!,
          sessionRequiresOpenSettings: applied.sessionRequiresOpenSettings,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
    });

    test('user request denial sets session open settings requirement', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.requestingPermission,
        ignoreAfterGrant: false,
        fromUserRequest: true,
      );
      expect(applied.userDenied, isTrue);
      expect(applied.ui, RecordUiState.permissionBlocked);
      expect(applied.sessionRequiresOpenSettings, isTrue);
    });

    test('permanentlyDenied request result keeps open settings until granted', () {
      final denied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionPermanentlyDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.requestingPermission,
        ignoreAfterGrant: false,
        fromUserRequest: true,
      );
      expect(denied.sessionRequiresOpenSettings, isTrue);

      final refreshed = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: denied.userDenied!,
        currentUi: denied.ui!,
        ignoreAfterGrant: false,
        fromUserRequest: false,
        sessionRequiresOpenSettings: denied.sessionRequiresOpenSettings,
      );
      expect(refreshed.sessionRequiresOpenSettings, isTrue);
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: refreshed.mic!,
          userDeniedThisSession: refreshed.userDenied!,
          sessionRequiresOpenSettings: refreshed.sessionRequiresOpenSettings,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
    });

    test('initial deniedCanAskAgain shows Record one moment not blocked copy', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.permissionDenied,
        userDeniedThisSession: false,
        currentUi: RecordUiState.idle,
        ignoreAfterGrant: false,
        fromUserRequest: false,
      );
      expect(applied.ui, RecordUiState.ready);
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: applied.ui!,
          micPhase: applied.mic!,
          userDeniedThisSession: applied.userDenied!,
        ),
        isFalse,
      );
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        isNot(MicrophoneBlockedPanelKind.openSettings),
      );
    });
  });

  group('RecordingService permission UX flow', () {
    test('granted request then verified start calls recorder without re-check', () async {
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        requestResult: PermissionStatus.granted,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      expect(await recording.requestMicrophone(), RecordingPhase.ready);
      await recording.startRecording(permissionVerified: true);
      expect(recording.recorderStartCallCount, 1);
      expect(gateway.requestCallCount, 1);
    });

    test('denied request stays blocked until user has answered', () async {
      final gateway = FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.denied,
        requestResult: PermissionStatus.denied,
        hasRecorder: true,
      );
      final recording = RecordingService(
        testMode: true,
        permissionGateway: gateway,
        hasRecorderOverride: true,
      );

      final phase = await recording.requestMicrophone();
      expect(phase, RecordingPhase.permissionDenied);
      expect(
        RecordMicrophonePermissionUi.uiForMicPhase(
          phase: phase,
          userDeniedThisSession: true,
        ),
        RecordUiState.permissionBlocked,
      );
    });

    test('pending request uses requestingPermission before native dialog returns', () {
      const pendingUi = RecordUiState.requestingPermission;
      expect(
        RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(
          pendingUi,
        ),
        isTrue,
      );
      expect(
        RecordMicrophonePermissionUi.shouldShowBlockedPanel(pendingUi),
        isFalse,
      );
    });
  });

  group('MicrophonePermissionBlockedPanel', () {
    testWidgets('blocked panel always shows Open Settings CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophonePermissionBlockedPanel(
              onOpenSettings: () {},
              onTypeInstead: () async {},
            ),
          ),
        ),
      );

      expect(find.text(MicrophonePermissionCopy.allowMicrophoneCta), findsNothing);
      expect(find.text(MicrophonePermissionCopy.openSettingsCta), findsOneWidget);
      expect(find.text(MicrophonePermissionCopy.typeInsteadBlockedHelper), findsOneWidget);
    });

    testWidgets('simulator layout prioritizes Type Instead over Open Settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophonePermissionBlockedPanel(
              showSimulatorHelper: true,
              onOpenSettings: () {},
              onTypeInstead: () async {},
            ),
          ),
        ),
      );

      final typeInstead = find.byKey(const Key('microphone_permission_type_instead'));
      final openSettings = find.byKey(const Key('microphone_permission_open_settings'));
      expect(typeInstead, findsOneWidget);
      expect(openSettings, findsOneWidget);
      expect(
        tester.getTopLeft(typeInstead).dy < tester.getTopLeft(openSettings).dy,
        isTrue,
      );
      expect(
        find.text(MicrophonePermissionCopy.simulatorHelper),
        findsOneWidget,
      );
    });

    testWidgets('shows simulator helper copy when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophonePermissionBlockedPanel(
              showSimulatorHelper: true,
              onOpenSettings: () {},
              onTypeInstead: () async {},
            ),
          ),
        ),
      );

      expect(
        find.text(MicrophonePermissionCopy.simulatorHelper),
        findsOneWidget,
      );
    });

    testWidgets('shows denied copy, Open Settings, and Type Instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophonePermissionBlockedPanel(
              onOpenSettings: () async {},
              onTypeInstead: () async {},
            ),
          ),
        ),
      );

      expect(find.text(MicrophonePermissionCopy.deniedTitle), findsOneWidget);
      expect(
        find.textContaining('Turn it on in Settings, or use text if available'),
        findsOneWidget,
      );
      expect(find.text(MicrophonePermissionCopy.openSettingsCta), findsOneWidget);
      expect(find.text(MicrophonePermissionCopy.typeInsteadCta), findsOneWidget);
      expect(find.text(MicrophonePermissionCopy.typeInsteadBlockedHelper), findsOneWidget);
    });

    testWidgets('Type Instead navigates to quick capture', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: MicrophonePermissionBlockedPanel(
                    onOpenSettings: () async {},
                    onTypeInstead: () => navigateToTypeInsteadCapture(context),
                  ),
                ),
              ),
              GoRoute(
                path: '/quick-capture',
                builder: (context, state) =>
                    const Scaffold(body: Text('QUICK_CAPTURE_MARKER')),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('microphone_permission_type_instead')),
      );
      await tester.pumpAndSettle();

      expect(find.text('QUICK_CAPTURE_MARKER'), findsOneWidget);
    });
  });

  group('RecordScreenCloseButton', () {
    testWidgets('tablet width renders top-right Close button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1366));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordScreenCloseButton(),
          ),
        ),
      );
      expect(find.byKey(const Key('record_screen_close')), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('Close calls Navigator.maybePop without crashing', (tester) async {
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const Scaffold(
                          body: RecordScreenCloseButton(),
                        ),
                      ),
                    );
                  },
                  child: const Text('OPEN'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record_screen_close')));
      await tester.pumpAndSettle();
      popped = find.text('OPEN').evaluate().isNotEmpty;
      expect(popped, isTrue);
    });
  });

  group('Info.plist microphone strings', () {
    test('contains NSMicrophoneUsageDescription with ArchiveMe copy', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>NSMicrophoneUsageDescription</key>'));
      expect(
        plist,
        contains(
          'ArchiveMe uses the microphone so you can record short private reflections.',
        ),
      );
    });

    test('contains NSSpeechRecognitionUsageDescription when transcribing', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>NSSpeechRecognitionUsageDescription</key>'));
      expect(
        plist,
        contains(
          'ArchiveMe uses speech recognition to turn your recording into text when you choose to transcribe.',
        ),
      );
    });
  });
}
