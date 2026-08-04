import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/onboarding_microphone_gate.dart';
import 'package:voicememory_mobile/features/voice_capture/onboarding_microphone_state.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'helpers/memory_secure_storage.dart';

void main() {
  late Directory directory;
  late OnboardingMicStateStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mic_onboarding_');
    final prefs = await MobilePrefsStore.open(
      '${directory.path}/prefs.json',
      secureStorage: MemorySecureStorage(),
    );
    store = OnboardingMicStateStore(prefs);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Widget harness({
    required FakeMicrophonePermissionGateway gateway,
    Future<bool> Function()? openSettings,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: OnboardingMicrophoneGate(
          store: store,
          gateway: gateway,
          openSettings: openSettings,
          child: const Text(
            'ACTIVE RECORDING CONTROLS',
            key: Key('active_recording_controls'),
          ),
        ),
      ),
    );
  }

  Future<void> flushAsync(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }

  test('stores stable local funnel values in secure preferences', () async {
    expect(OnboardingMicState.values.map((state) => state.storageValue), [
      'not_prompted',
      'soft_prompt_accepted',
      'granted',
      'denied',
      'permanently_denied',
    ]);
    expect(await store.read(), OnboardingMicState.notPrompted);

    for (final state in OnboardingMicState.values) {
      await store.write(state);
      expect(await store.read(), state);
    }
  });

  test('every persisted funnel state has one stable UI view', () {
    expect(
      OnboardingMicrophoneViewResolver.fromLocalState(
        OnboardingMicState.notPrompted,
      ),
      OnboardingMicrophoneView.softPrompt,
    );
    expect(
      OnboardingMicrophoneViewResolver.fromLocalState(
        OnboardingMicState.softPromptAccepted,
      ),
      OnboardingMicrophoneView.softPrompt,
    );
    expect(
      OnboardingMicrophoneViewResolver.fromLocalState(
        OnboardingMicState.granted,
      ),
      OnboardingMicrophoneView.active,
    );
    expect(
      OnboardingMicrophoneViewResolver.fromLocalState(
        OnboardingMicState.denied,
      ),
      OnboardingMicrophoneView.recovery,
    );
    expect(
      OnboardingMicrophoneViewResolver.fromLocalState(
        OnboardingMicState.permanentlyDenied,
      ),
      OnboardingMicrophoneView.recovery,
    );
  });

  testWidgets('soft prompt is accepted before native permission request', (
    tester,
  ) async {
    final gateway = FakeMicrophonePermissionGateway(
      statusValue: PermissionStatus.denied,
      requestResult: PermissionStatus.granted,
      requestDelay: const Duration(seconds: 1),
    );
    await tester.pumpWidget(harness(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('microphone_soft_prompt')), findsOneWidget);
    expect(find.textContaining('app-private storage'), findsOneWidget);
    expect(find.textContaining('Offline transcription'), findsOneWidget);
    expect(gateway.requestCallCount, 0);

    await tester.tap(find.byKey(const Key('microphone_soft_prompt_continue')));
    await tester.pump();
    await flushAsync(tester);

    expect(gateway.requestCallCount, 1);
    expect(await store.read(), OnboardingMicState.softPromptAccepted);

    await tester.pump(const Duration(seconds: 1));
    await flushAsync(tester);
    await tester.pumpAndSettle();
    expect(await store.read(), OnboardingMicState.granted);
    expect(find.byKey(const Key('active_recording_controls')), findsOneWidget);
  });

  testWidgets('denial persists locally and shows inline recovery', (
    tester,
  ) async {
    final gateway = FakeMicrophonePermissionGateway(
      statusValue: PermissionStatus.denied,
      requestResult: PermissionStatus.denied,
    );
    await tester.pumpWidget(harness(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('microphone_soft_prompt_continue')));
    await flushAsync(tester);

    expect(await store.read(), OnboardingMicState.denied);
    expect(
      find.byKey(const Key('microphone_permission_blocked_panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('microphone_permission_open_settings')),
      findsOneWidget,
    );
  });

  testWidgets('permanent denial opens operating-system settings', (
    tester,
  ) async {
    var settingsCalls = 0;
    final gateway = FakeMicrophonePermissionGateway(
      statusValue: PermissionStatus.permanentlyDenied,
    );
    await tester.pumpWidget(
      harness(
        gateway: gateway,
        openSettings: () async {
          settingsCalls++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await flushAsync(tester);
    await flushAsync(tester);

    expect(await store.read(), OnboardingMicState.permanentlyDenied);
    await tester.tap(
      find.byKey(const Key('microphone_permission_open_settings')),
    );
    await tester.pump();
    expect(settingsCalls, 1);
  });

  testWidgets('resume automatically restores active recording controls', (
    tester,
  ) async {
    final gateway = FakeMicrophonePermissionGateway(
      statusValue: PermissionStatus.permanentlyDenied,
    );
    await tester.pumpWidget(harness(gateway: gateway));
    await tester.pumpAndSettle();
    await flushAsync(tester);
    await flushAsync(tester);
    expect(
      find.byKey(const Key('microphone_permission_blocked_panel')),
      findsOneWidget,
    );

    gateway.statusValue = PermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsync(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(await store.read(), OnboardingMicState.granted);
    expect(find.byKey(const Key('active_recording_controls')), findsOneWidget);
    expect(
      find.byKey(const Key('microphone_permission_blocked_panel')),
      findsNothing,
    );
    expect(
      find.text(MicrophonePermissionCopy.connectedMessage),
      findsOneWidget,
    );
  });
}
