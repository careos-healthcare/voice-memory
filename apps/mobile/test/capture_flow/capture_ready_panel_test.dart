import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/record/example_prompt_catalog.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(
    WidgetTester tester, {
    required bool microphoneGranted,
    bool permissionBlocked = false,
    bool permissionRequiresSettings = false,
    CaptureInputMode inputMode = CaptureInputMode.voice,
    double textScale = 1,
    Size surface = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: CaptureReadyPanel(
              inputMode: inputMode,
              attachMode: false,
              onStartVoice: () {},
              onSaveTyped: (_) {},
              onSwitchMode: (_) {},
              permissionBlocked: permissionBlocked,
              permissionRequiresSettings: permissionRequiresSettings,
              microphoneGranted: microphoneGranted,
              errorMessage: null,
              typedController: controller,
              saving: false,
              now: DateTime(2026, 9, 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('granted state shows no permission copy', (tester) async {
    await pumpPanel(tester, microphoneGranted: true);
    expect(find.text(MicrophonePermissionCopy.neededTitle), findsNothing);
    expect(find.text(MicrophonePermissionCopy.neededBody), findsNothing);
    expect(
      find.text(MicrophonePermissionCopy.requestMicrophoneCta),
      findsNothing,
    );
    expect(find.byKey(const Key('capture_record_button')), findsOneWidget);
    expect(find.text('Thursday, 24 September'), findsOneWidget);
    expect(find.text(ExamplePromptCatalog.prompts.first), findsOneWidget);
  });

  testWidgets('undetermined state shows permission copy', (tester) async {
    await pumpPanel(tester, microphoneGranted: false);
    expect(find.text(MicrophonePermissionCopy.neededTitle), findsOneWidget);
    expect(find.text(MicrophonePermissionCopy.neededBody), findsOneWidget);
    expect(
      find.text(MicrophonePermissionCopy.requestMicrophoneCta),
      findsOneWidget,
    );
  });

  testWidgets('typed save button label is Save', (tester) async {
    await pumpPanel(tester, microphoneGranted: true, inputMode: CaptureInputMode.typed);
    expect(find.text(MicrophonePermissionCopy.saveTypedCta), findsOneWidget);
    expect(find.text('Record'), findsNothing);
    expect(find.text(MicrophonePermissionCopy.backToVoiceCta), findsOneWidget);
    expect(find.byKey(const Key('capture_typed_field')), findsOneWidget);
    expect(find.byKey(const Key('capture_save_typed')), findsOneWidget);
  });

  testWidgets('prompt chip does not switch to typing', (tester) async {
    CaptureInputMode? switched;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? contextLine;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureReadyPanel(
            inputMode: CaptureInputMode.voice,
            attachMode: false,
            onStartVoice: () {},
            onSaveTyped: (_) {},
            onSwitchMode: (mode) => switched = mode,
            permissionBlocked: false,
            permissionRequiresSettings: false,
            microphoneGranted: true,
            errorMessage: null,
            typedController: controller,
            saving: false,
            onPromptContext: (line) => contextLine = line,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('capture_prompt_chip')));
    await tester.pump();
    expect(switched, isNull);
    expect(contextLine, ExamplePromptCatalog.prompts.first);
  });

  testWidgets('no overflow at 2.0x text scale on a 375x667 screen', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      microphoneGranted: false,
      textScale: 2,
      surface: const Size(375, 667),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('capture_record_button')));
    expect(tester.takeException(), isNull);
  });
}
