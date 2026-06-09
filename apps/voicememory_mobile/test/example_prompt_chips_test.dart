import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/record/example_prompt_catalog.dart';
import 'package:voicememory_mobile/record/start_here_catalog.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/example_prompt_chips.dart';

void main() {
  group('ExamplePromptChips', () {
    testWidgets('renders section title and all prompts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 0,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text(ExamplePromptCatalog.sectionTitle), findsOneWidget);
      for (final prompt in ExamplePromptCatalog.prompts) {
        expect(find.text(prompt), findsOneWidget);
      }
      expect(
        find.text(ExamplePromptCatalog.continueBuildingArchive),
        findsNothing,
      );
    });

    testWidgets('tap invokes callback with prompt text', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 1,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (p) => tapped = p,
              surface: 'test',
            ),
          ),
        ),
      );

      await tester.tap(find.text(ExamplePromptCatalog.prompts.first));
      await tester.pump();
      expect(tapped, ExamplePromptCatalog.prompts.first);
    });

    testWidgets('hides chips after threshold and shows continue copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 5,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text(ExamplePromptCatalog.sectionTitle), findsNothing);
      expect(
        find.text(ExamplePromptCatalog.continueBuildingArchive),
        findsOneWidget,
      );
    });

    testWidgets('chips have accessible conversation starter labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 0,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        ),
      );

      final chipSemantics = tester.widgetList<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith('Conversation starter:'),
        ),
      );
      expect(chipSemantics.length, ExamplePromptCatalog.prompts.length);
    });
  });

  group('RecordScreen Start Here', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_example_prompts_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('shows Start Here above record CTA when ready', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(StartHereCatalog.sectionTitle), findsOneWidget);
      expect(find.text(StartHereCatalog.prompts.first), findsOneWidget);
    });
  });

  group('QuickTextCaptureScreen Start Here', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_text_prompts_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
    });

    testWidgets('tap prefills text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: QuickTextCaptureScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text(StartHereCatalog.prompts[1]));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, StartHereCatalog.prompts[1]);
    });
  });
}
