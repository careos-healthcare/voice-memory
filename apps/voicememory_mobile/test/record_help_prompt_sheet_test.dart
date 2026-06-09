import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/record_help_prompt_sheet.dart';

Future<void> _pumpHost(
  WidgetTester tester, {
  required Size surface,
  required ValueChanged<String> onSelect,
  String? selected,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showRecordHelpPromptSheet(
                context: context,
                onSelect: onSelect,
                selected: selected,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sheet shows updated title and helper copy', (tester) async {
    await _pumpHost(tester, surface: const Size(390, 844), onSelect: (_) {});

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.recordHelpSheetTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.recordHelpSheetHelper), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.recordHelpSheetPrompts.first),
      findsOneWidget,
    );
  });

  testWidgets('sheet does not overflow in a short, constrained height',
      (tester) async {
    // Deliberately short viewport to reproduce the previous overflow.
    await _pumpHost(tester, surface: const Size(320, 480), onSelect: (_) {});

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sheet content scrolls instead of overflowing.
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a prompt closes the sheet and reports the selection',
      (tester) async {
    String? selected;
    await _pumpHost(
      tester,
      surface: const Size(390, 844),
      onSelect: (value) => selected = value,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final prompt = ConsumerUiCopy.recordHelpSheetPrompts[1];
    await tester.tap(find.text(prompt));
    await tester.pumpAndSettle();

    expect(selected, prompt);
    expect(find.text(ConsumerUiCopy.recordHelpSheetTitle), findsNothing);
  });

  testWidgets('already-selected prompt renders in a selected state',
      (tester) async {
    final preselected = ConsumerUiCopy.recordHelpSheetPrompts.first;
    await _pumpHost(
      tester,
      surface: const Size(390, 844),
      onSelect: (_) {},
      selected: preselected,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The selected card uses the accent surface; unselected cards do not.
    final selectedMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.text(preselected),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(selectedMaterial.color, AppColors.accentLight);

    final otherPrompt = ConsumerUiCopy.recordHelpSheetPrompts[1];
    final otherMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.text(otherPrompt),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(otherMaterial.color, AppColors.surfaceAlt);
  });
}
