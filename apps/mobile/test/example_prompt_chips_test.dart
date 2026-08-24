import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/record/example_prompt_catalog.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/example_prompt_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

List<PressureCheckInRecord> _workThread3() => [
  PressureCheckInRecord(
    entryId: 'a',
    createdAt: DateTime(2026, 6, 2, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    transcript: 'pressure moment',
  ),
  PressureCheckInRecord(
    entryId: 'b',
    createdAt: DateTime(2026, 6, 4, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    transcript: 'pressure moment',
  ),
  PressureCheckInRecord(
    entryId: 'c',
    createdAt: DateTime(2026, 6, 9, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    transcript: 'pressure moment',
  ),
];

void main() {
  group('ExamplePromptChips', () {
    testWidgets('renders section title and all prompts', (tester) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 0,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        )));

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
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 1,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (p) => tapped = p,
              surface: 'test',
            ),
          ),
        )));

      await tester.tap(find.text(ExamplePromptCatalog.prompts.first));
      await tester.pump();
      expect(tapped, ExamplePromptCatalog.prompts.first);
    });

    testWidgets('hides chips after threshold and shows continue copy', (
      tester,
    ) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 5,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        )));

      expect(find.text(ExamplePromptCatalog.sectionTitle), findsNothing);
      expect(
        find.text(ExamplePromptCatalog.continueBuildingArchive),
        findsOneWidget,
      );
    });

    testWidgets('chips have accessible conversation starter labels', (
      tester,
    ) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ExamplePromptChips(
              recordingCount: 0,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        )));

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
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() => sandbox.dispose());

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('capture-first record suppresses starter prompt chips', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          await AppServices.instance.journalStore.save(
            JournalEntry(
              id: 'e$i',
              createdAt: DateTime(2026, 6, 1 + i, 12),
              transcript:
                  'A long enough transcript to count as a saved reflection number $i.',
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
          );
        }
      });

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(_workThread3()),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(ConsumerUiCopy.trySayingOneOfThese), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });
  });
}