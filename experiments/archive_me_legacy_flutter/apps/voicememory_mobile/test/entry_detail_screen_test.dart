import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items/archive_action_item.dart';
import 'package:voicememory_mobile/features/archive_evidence/transcript_pending_copy.dart';
import 'package:voicememory_mobile/features/entry_detail/entry_detail_copy.dart';
import 'package:voicememory_mobile/features/fact_ledger/archive_fact.dart';
import 'package:voicememory_mobile/features/memory/curated_memory_marker.dart';
import 'package:voicememory_mobile/features/memory/entry_aboutness.dart';
import 'package:voicememory_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/entry_detail_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

JournalEntry _entry({
  required String id,
  String transcript =
      'A long enough transcript for entry detail screen tests here.',
  String mood = 'neutral',
  String aboutness = 'about_me',
  String surfacing = 'normal',
  bool preserveOriginal = false,
  String observation = '',
  String exactLanguage = '',
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 14, 30),
  transcript: transcript,
  durationSeconds: 20,
  localAudioPath: localAudioPath,
  reflection: Reflection(
    mood: mood,
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: exactLanguage,
    concreteObservation: observation,
    repeatedSignal: '',
  ),
  entryAboutness: aboutness,
  memorySurfacing: surfacing,
  preserveOriginal: preserveOriginal,
);

Future<void> _saveEntry(JournalEntry entry) async {
  await AppServices.instance.journalStore.save(entry);
}

Future<void> _pumpEntryDetail(WidgetTester tester, String entryId) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: EntryDetailScreen(entryId: entryId),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

Future<void> _saveAndPump(
  WidgetTester tester, {
  required JournalEntry entry,
}) async {
  await tester.runAsync(() => _saveEntry(entry));
  await _pumpEntryDetail(tester, entry.id);
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('entry_detail_screen_test');
    await AppServices.resetForTest(
      journalPath: '${tmp.path}/entries.json',
      prefsPath: '${tmp.path}/prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('Entry detail default layout', () {
    testWidgets('shows user-facing header and sections', (tester) async {
      await _saveAndPump(tester, entry: _entry(id: 'e1'));

      expect(find.text(EntryDetailCopy.title), findsOneWidget);
      expect(find.text(EntryDetailCopy.whatYouRecorded), findsOneWidget);
      expect(find.text(EntryDetailCopy.archiveNoteLabel), findsOneWidget);
      expect(find.text(EntryDetailCopy.archiveNoteBody), findsOneWidget);
      expect(find.text(EntryDetailCopy.archiveNoteHelper), findsOneWidget);
    });

    testWidgets('hides internal metadata on default view', (tester) async {
      await _saveAndPump(
        tester,
        entry: _entry(
          id: 'meta',
          aboutness: 'project_material',
          surfacing: 'sensitive',
          preserveOriginal: true,
          mood: 'neutral',
        ),
      );

      expect(find.textContaining('[draft]'), findsNothing);
      expect(find.textContaining('Mood: neutral'), findsNothing);
      expect(find.text(MemorySurfacingCopy.surfacingTitle), findsNothing);
      expect(find.text(EntryAboutnessCopy.projectMaterialLabel), findsNothing);
      expect(find.text(CuratedMemoryCopy.preserveOriginalLabel), findsNothing);
      expect(find.text(FactLedgerCopy.saveDetail), findsNothing);
    });

    testWidgets('voice draft entry shows degraded transcription copy', (
      tester,
    ) async {
      await _saveAndPump(
        tester,
        entry: _entry(
          id: 'draft',
          transcript:
              '[draft] Recording saved locally — transcribe when connected',
          observation: '',
          localAudioPath: '/tmp/test-audio.m4a',
        ),
      );

      expect(find.textContaining('[draft]'), findsNothing);
      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
      expect(
        find.text(TranscriptPendingCopy.savedLocallyTitle),
        findsOneWidget,
      );
      expect(find.text(TranscriptPendingCopy.savedLocallyBody), findsOneWidget);
      expect(
        find.byKey(const Key('entry_detail_type_what_you_said')),
        findsOneWidget,
      );
    });

    testWidgets('typed transcript shows plainly', (tester) async {
      const typed = 'I want to remember this idea about the garden.';
      await _saveAndPump(
        tester,
        entry: _entry(id: 'typed', transcript: typed),
      );

      expect(
        find.byKey(const Key('entry_detail_recorded_body')),
        findsOneWidget,
      );
      expect(find.text(typed), findsOneWidget);
    });

    testWidgets('expanding advanced details reveals metadata controls', (
      tester,
    ) async {
      await _saveAndPump(
        tester,
        entry: _entry(
          id: 'advanced',
          aboutness: 'project_material',
          surfacing: 'sensitive',
          preserveOriginal: true,
        ),
      );

      expect(find.byKey(const Key('entry_aboutness_editor')), findsNothing);
      expect(find.byKey(const Key('memory_surfacing_editor')), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('entry_detail_advanced_section')),
        200,
      );
      final advancedDetails = find.text(EntryDetailCopy.advancedDetails);
      await tester.ensureVisible(advancedDetails);
      await tester.pump();
      await tester.tap(advancedDetails);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('entry_aboutness_editor')), findsOneWidget);
      expect(find.byKey(const Key('memory_surfacing_editor')), findsOneWidget);
      expect(find.text(EntryAboutnessCopy.entryTypeTitle), findsOneWidget);
      expect(find.text(MemorySurfacingCopy.surfacingTitle), findsOneWidget);
      expect(
        find.text(EntryAboutnessCopy.projectMaterialLabel),
        findsOneWidget,
      );
      expect(find.text(FactLedgerCopy.saveDetail), findsOneWidget);
      expect(find.byKey(const Key('entry_add_to_collection')), findsOneWidget);
    });
  });

  group('Entry detail actions', () {
    testWidgets(
      'remember this button stays hidden while action items are off',
      (tester) async {
        await _saveAndPump(tester, entry: _entry(id: 'remember'));

        expect(find.byKey(const Key('remember_this_button')), findsNothing);
        expect(find.text(ActionItemsCopy.rememberThis), findsNothing);
      },
    );

    testWidgets('pin still toggles entry pin state', (tester) async {
      await _saveAndPump(tester, entry: _entry(id: 'pin-me'));

      expect(find.byKey(const Key('pin_entry_button')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pin_entry_button')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Pinned'), findsOneWidget);
      await tester.runAsync(() async {
        expect(
          (await AppServices.instance.journalStore.getById('pin-me'))!.isPinned,
          isTrue,
        );
      });
    });

    testWidgets('delete shows confirmation dialog', (tester) async {
      await _saveAndPump(tester, entry: _entry(id: 'delete-me'));

      expect(
        find.byKey(const Key('entry_detail_delete_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('entry_detail_delete_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(EntryDetailCopy.deleteConfirmTitle), findsOneWidget);
      expect(
        find.byKey(const Key('entry_detail_delete_confirm')),
        findsOneWidget,
      );
    });
  });
}
