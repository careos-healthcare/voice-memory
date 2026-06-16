import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/record/consumer_record_prompts_section.dart';

/// Minimal stand-in for the Record screen prompt area: it owns the selected
/// prompt state and mirrors how the screen surfaces it ("Try saying:" + the
/// selected line) plus the capture actions that consume it.
class _PromptHarness extends StatefulWidget {
  const _PromptHarness();

  @override
  State<_PromptHarness> createState() => _PromptHarnessState();
}

class _PromptHarnessState extends State<_PromptHarness> {
  String? _selected;
  bool _recordPressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selected != null) ...[
                const Text(ConsumerUiCopy.trySayingLabel),
                Text(_selected!),
              ],
              ConsumerRecordPromptsSection(
                selectedPrompt: _selected,
                onSelectPrompt: (p) => setState(() => _selected = p),
              ),
              CaptureEntryActions(
                onRecord: () => setState(() => _recordPressed = true),
                typeCapturePrompt: _selected,
                recordButtonLabel: ConsumerUiCopy.startRecording,
              ),
              if (_recordPressed) const Text('record-pressed'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const _PromptHarness()),
  );
}

void main() {
  testWidgets('shows "Show more prompt ideas" instead of the old link', (
    tester,
  ) async {
    await _pumpHarness(tester);

    expect(find.text(ConsumerUiCopy.showMorePromptIdeas), findsOneWidget);
    expect(find.text('Need a starter prompt?'), findsNothing);
  });

  testWidgets('tapping the link opens the sheet titled "Pick a prompt"', (
    tester,
  ) async {
    await _pumpHarness(tester);

    await tester.tap(find.text(ConsumerUiCopy.showMorePromptIdeas));
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.recordHelpSheetTitle), findsOneWidget);
    expect(find.text('Pick a prompt'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.recordHelpSheetHelper), findsOneWidget);
  });

  testWidgets(
    'tapping a sheet prompt closes the sheet and shows it under "Try saying:"',
    (tester) async {
      await _pumpHarness(tester);

      await tester.tap(find.text(ConsumerUiCopy.showMorePromptIdeas));
      await tester.pumpAndSettle();

      // A sheet-only prompt (not present among the main starter cards) so the
      // selection display is unambiguous.
      const sheetPrompt = 'What decision are you avoiding?';
      expect(
        ConsumerUiCopy.recordStarterPrompts.contains(sheetPrompt),
        isFalse,
      );

      await tester.tap(find.text(sheetPrompt));
      await tester.pumpAndSettle();

      // Sheet is dismissed.
      expect(find.text(ConsumerUiCopy.recordHelpSheetTitle), findsNothing);
      // Selection surfaced under "Try saying:".
      expect(find.text(ConsumerUiCopy.trySayingLabel), findsOneWidget);
      expect(find.text(sheetPrompt), findsOneWidget);
    },
  );

  testWidgets('selected prompt is preserved when tapping Start recording', (
    tester,
  ) async {
    await _pumpHarness(tester);

    const mainPrompt = 'What felt heavy or unresolved this week?';
    await tester.tap(find.text(mainPrompt));
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.trySayingLabel), findsOneWidget);

    await tester.tap(find.text(ConsumerUiCopy.startRecording));
    await tester.pumpAndSettle();

    // Record fired and the selection survived the interaction.
    expect(find.text('record-pressed'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.trySayingLabel), findsOneWidget);
    expect(find.text(mainPrompt), findsWidgets);
  });

  testWidgets('Type Instead receives the selected prompt', (tester) async {
    String? capturedExtra;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _PromptHarness()),
        GoRoute(
          path: '/quick-capture',
          builder: (context, state) {
            capturedExtra = state.extra as String?;
            return Scaffold(body: Text('captured:${state.extra}'));
          },
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );

    const mainPrompt = 'What felt heavy or unresolved this week?';
    await tester.tap(find.text(mainPrompt));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type Instead'));
    await tester.pumpAndSettle();

    expect(capturedExtra, mainPrompt);
    expect(find.text('captured:$mainPrompt'), findsOneWidget);
  });
}
