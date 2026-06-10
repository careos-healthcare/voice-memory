import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
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
      // The Record screen no longer renders the Start Here section on first
      // run — the first-recording handoff card owns that state now. The
      // "Try saying one of these" prompt area (same section title) appears
      // for returning users, so seed one reflection and verify it still
      // renders above the record CTA.
      await tester.runAsync(
        () => AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'e1',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        ),
      );

      await tester.binding.setSurfaceSize(const Size(390, 2400));
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
      expect(
        find.text(ConsumerUiCopy.recordStarterPrompts.first),
        findsOneWidget,
      );

      final sectionY =
          tester.getTopLeft(find.text(StartHereCatalog.sectionTitle)).dy;
      final ctaY = tester
          .getTopLeft(find.text(ConsumerUiCopy.startRecording).first)
          .dy;
      expect(sectionY, lessThan(ctaY),
          reason: 'prompt section should render above the record CTA');
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
