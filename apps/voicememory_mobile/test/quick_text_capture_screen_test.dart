import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/start_here_catalog.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

/// iPhone 17 Pro logical size — tight enough to reproduce fallback overflow.
const _iphone17Pro = Size(402, 874);
const _keyboardInset = EdgeInsets.only(bottom: 336);

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/test-audio.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_quick_text_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? initialText,
    String? entryId,
    Size surfaceSize = _iphone17Pro,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            viewInsets: viewInsets,
          ),
          child: QuickTextCaptureScreen(
            initialText: initialText,
            entryId: entryId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  final saveButton = find.byKey(const Key('quick_text_capture_save_button'));

  group('QuickTextCaptureScreen prompt handling', () {
    testWidgets('opens with empty text field', (tester) async {
      await pumpScreen(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('initial prompt is hint only, not editable content', (
      tester,
    ) async {
      const prompt = 'When did you feel pressure to do more to feel okay?';
      await pumpScreen(tester, initialText: prompt);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(find.text(ConsumerUiCopy.trySayingLabel), findsOneWidget);
      expect(find.text(prompt), findsWidgets);
      expect(field.decoration?.hintText, prompt);
    });

    testWidgets('start here tap sets hint without prefilling field', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text(StartHereCatalog.prompts[1]));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(find.text(StartHereCatalog.prompts[1]), findsWidgets);
      expect(field.decoration?.hintText, StartHereCatalog.prompts[1]);
    });

    testWidgets('typing clears prompt helper and uses generic hint', (
      tester,
    ) async {
      const prompt = 'When did you feel pressure to do more to feel okay?';
      await pumpScreen(tester, initialText: prompt);

      await tester.enterText(find.byType(TextField), 'I did more because I felt behind.');
      await tester.pump();

      expect(find.text(ConsumerUiCopy.trySayingLabel), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'Type your thought here…');
      expect(field.controller?.text, 'I did more because I felt behind.');
    });

    testWidgets('save button stays disabled until user types', (tester) async {
      const prompt = 'When did you feel pressure to do more to feel okay?';
      await pumpScreen(tester, initialText: prompt);

      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'My own answer.');
      await tester.pump();

      final enabled = tester.widget<FilledButton>(saveButton);
      expect(enabled.onPressed, isNotNull);
    });
  });

  group('QuickTextCaptureScreen layout', () {
    testWidgets('renders without overflow on iPhone 17 Pro size', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(saveButton, findsOneWidget);
    });

    testWidgets('voice fallback renders without overflow on small phone', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedVoiceEntry());
      });

      await pumpScreen(tester, entryId: 'v1');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
      expect(find.text('What did you say?'), findsOneWidget);
      expect(find.text('Save words'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('voice fallback with keyboard inset stays scrollable', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedVoiceEntry());
      });

      await pumpScreen(
        tester,
        entryId: 'v1',
        viewInsets: _keyboardInset,
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(saveButton, findsOneWidget);

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(saveButton, findsOneWidget);
    });

    testWidgets('voice fallback shows compact prompt chips only', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedVoiceEntry());
      });

      await pumpScreen(tester, entryId: 'v1');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(StartHereCatalog.prompts[0]), findsOneWidget);
      expect(find.text(StartHereCatalog.prompts[1]), findsOneWidget);
      expect(find.text(StartHereCatalog.prompts[2]), findsNothing);
      expect(find.text(StartHereCatalog.prompts[3]), findsNothing);
    });
  });

  group('QuickTextCaptureScreen voice fallback save', () {
    testWidgets('opens with voice entry id context', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedVoiceEntry());
      });

      await pumpScreen(tester, entryId: 'v1');

      expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
      expect(find.text('What did you say?'), findsOneWidget);
    });
  });
}
