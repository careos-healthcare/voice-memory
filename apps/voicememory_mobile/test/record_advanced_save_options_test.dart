import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack.dart';
import 'package:voicememory_mobile/features/memory/entry_memory_mode.dart';
import 'package:voicememory_mobile/features/memory/entry_save_coordinator.dart';
import 'package:voicememory_mobile/features/memory/entry_thread_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';

import 'support/expand_advanced_save_options.dart';
import 'support/memory_pressure_stores.dart';

JournalEntry _entry({required String id}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 10),
  transcript: 'A long enough transcript for advanced save options tests.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_adv_save_opts_');
    MemoryScopePolicy.resetForTest();
    EntryMemoryModeSession.resetSessionForTest();
    EntryThreadScopeSession.resetSessionForTest();
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
      skipRevenueCat: true,
    );
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(ui: RecordUiState.ready),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    VisualAuditOverrides.setRecordPresentation(null);
  });

  Future<void> pumpRecordScreen(WidgetTester tester, {int entries = 1}) async {
    if (entries > 0) {
      await tester.runAsync(() async {
        for (var i = 0; i < entries; i++) {
          await AppServices.instance.journalStore.save(_entry(id: 'e$i'));
        }
      });
    }
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RecordScreen(
            suggestionAttributionStore: MemorySuggestionAttributionStore(),
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Record screen advanced save options', () {
    testWidgets('shows primary capture actions when collapsed', (tester) async {
      await pumpRecordScreen(tester, entries: 1);

      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      expect(
        find.text(CaptureEntryActions.logPressureMomentLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows collapsed advanced save options with helper copy', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entries: 1);

      expect(find.text(EntryMemoryModeCopy.advancedSaveOptionsTitle), findsOneWidget);
      expect(
        find.text(EntryMemoryModeCopy.advancedSaveOptionsCollapsedHelper),
        findsOneWidget,
      );
      expect(find.byKey(const Key('entry_options_expansion')), findsOneWidget);
    });

    testWidgets('hides advanced controls until expanded', (tester) async {
      await pumpRecordScreen(tester, entries: 1);

      expect(find.text(EntryMemoryModeCopy.useLabel), findsNothing);
      expect(find.text(EntryThreadScopeCopy.existingThreadLabel), findsNothing);
      expect(find.text(ArchivePacksCopy.saveToPack), findsNothing);

      await expandAdvancedSaveOptions(tester);

      expect(find.text(EntryMemoryModeCopy.useLabel), findsOneWidget);
      expect(find.text(EntryThreadScopeCopy.existingThreadLabel), findsOneWidget);
      expect(find.text(ArchivePacksCopy.saveToPack), findsOneWidget);
    });

    testWidgets('zero-entry users also start collapsed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EntryOptionsSection(entryCount: 0),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(EntryMemoryModeCopy.advancedSaveOptionsTitle), findsOneWidget);
      expect(find.byKey(const Key('entry_memory_scope_picker')), findsNothing);

      await expandAdvancedSaveOptions(tester);

      expect(find.byKey(const Key('entry_memory_scope_picker')), findsOneWidget);
    });

    test('default save metadata stays on archive context with no thread or pack', () async {
      expect(
        EntryMemoryModeSession.selectedMode,
        EntryMemoryMode.useArchiveContext,
      );
      expect(
        EntryThreadScopeSession.selectedScope,
        EntryThreadScope.noThread,
      );

      final saved = await EntrySaveCoordinator.applyNewEntryOptions(
        _entry(id: 'default_save'),
        entryCount: 1,
      );

      expect(saved.treatAsNew, isFalse);
      expect(saved.keepSeparate, isFalse);
      expect(saved.archiveThreadId, isNull);
      expect(saved.archivePackId, isNull);
    });
  });
}
