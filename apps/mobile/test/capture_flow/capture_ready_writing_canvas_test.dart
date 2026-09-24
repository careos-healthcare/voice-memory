import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typed canvas uses editorial 1.7 style and fades chrome', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureReadyPanel(
            inputMode: CaptureInputMode.typed,
            attachMode: false,
            onStartVoice: () {},
            onSaveTyped: (_) {},
            onSwitchMode: (_) {},
            permissionBlocked: false,
            permissionRequiresSettings: false,
            errorMessage: null,
            typedController: controller,
            saving: false,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('capture_typed_field')),
    );
    expect(field.style?.height, WritingCanvasTheme.lineHeight);
    expect(find.byKey(const Key('capture_save_typed')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_typed_field')));
    await tester.enterText(
      find.byKey(const Key('capture_typed_field')),
      'A longer typed moment',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final fades = tester.widgetList<AnimatedOpacity>(
      find.byKey(const Key('writing_canvas_chrome_fade')),
    );
    expect(fades, isNotEmpty);
    expect(fades.every((fade) => fade.opacity == 0), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
