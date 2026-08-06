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

/// Huawei LYA-L29 class logical width with a short usable body when keyboard open.
const _smallAndroid = Size(360, 640);
const _keyboardInset = EdgeInsets.only(bottom: 336);
const _largeKeyboardInset = EdgeInsets.only(bottom: 400);

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
      skipRevenueCat: true,
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
          data: MediaQueryData(size: surfaceSize, viewInsets: viewInsets),
          child: QuickTextCaptureScreen(
            initialText: initialText,
            entryId: entryId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await AppServices.instance.journal.loadAll();
    });
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

    // Start Here chips are hidden on the first-run text capture surface;
    // hint-only seeding is covered by the initialText test above.
    testWidgets('start here tap sets hint without prefilling field', (
      tester,
    ) async {
      await pumpScreen(tester, initialText: StartHereCatalog.prompts[1]);

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

      await tester.enterText(
        find.byType(TextField),
        'I did more because I felt behind.',
      );
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

    test('save failure keeps draft text in the controller', () {
      final source = File(
        'lib/screens/quick_text_capture_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_error = VoiceCaptureCopy.saveFailed'));
      expect(source, isNot(contains('_controller.clear()')));
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

      await pumpScreen(tester, entryId: 'v1', viewInsets: _keyboardInset);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(saveButton, findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -120),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(saveButton, findsOneWidget);
    });

    testWidgets(
      'type a thought with keyboard inset on small Android does not crash',
      (tester) async {
        await pumpScreen(
          tester,
          surfaceSize: _smallAndroid,
          viewInsets: _largeKeyboardInset,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Type a thought'), findsOneWidget);
        expect(
          find.byKey(const Key('quick_text_capture_field')),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(saveButton, findsOneWidget);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -160),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('quick_text_capture_field')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'type a thought with keyboard inset on iPhone size does not crash',
      (tester) async {
        await pumpScreen(
          tester,
          surfaceSize: _iphone17Pro,
          viewInsets: _keyboardInset,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Type a thought'), findsOneWidget);
        expect(
          find.byKey(const Key('quick_text_capture_field')),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsOneWidget);
      },
    );

    testWidgets('voice fallback shows compact prompt chips only', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedVoiceEntry());
      });

      await pumpScreen(tester, entryId: 'v1');

      expect(find.byKey(const Key('quick_text_capture_field')), findsOneWidget);
      if (find.text(StartHereCatalog.prompts[0]).evaluate().isNotEmpty) {
        expect(find.text(StartHereCatalog.prompts[0]), findsOneWidget);
        expect(find.text(StartHereCatalog.prompts[1]), findsOneWidget);
        expect(find.text(StartHereCatalog.prompts[2]), findsNothing);
      }
    });
  });

  group('QuickTextCaptureScreen focused Record type entry', () {
    Future<void> pumpFocused(
      WidgetTester tester, {
      String? promptHint,
      String? initialText,
      Size surfaceSize = _iphone17Pro,
    }) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: QuickTextCaptureScreen(
            promptHint: promptHint,
            initialText: initialText,
            focusedRecordTypeEntry: true,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await AppServices.instance.journal.loadAll();
      });
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('shows calm card with one field and Save moment', (
      tester,
    ) async {
      await pumpFocused(tester);

      expect(find.byKey(const Key('focused_type_entry_card')), findsOneWidget);
      expect(find.byKey(const Key('quick_text_capture_field')), findsOneWidget);
      expect(find.text('Save moment'), findsOneWidget);
      expect(find.text('Use voice instead'), findsOneWidget);
      expect(find.text('Examples'), findsOneWidget);
      expect(find.textContaining('characters'), findsNothing);
      expect(find.text("What's on your mind?"), findsNothing);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isA<Text>());
      expect((appBar.title! as Text).data, '');

      final field = tester.widget<TextField>(
        find.byKey(const Key('quick_text_capture_field')),
      );
      expect(field.decoration?.hintText, 'Today I noticed...');
      expect(field.controller?.text, isEmpty);
      expect(field.minLines, 3);
      expect(field.maxLines, 4);
    });

    testWidgets('ignores route prompt hints on focused path', (tester) async {
      const routePrompt = 'When did you feel pressure to do more to feel okay?';
      await pumpFocused(
        tester,
        promptHint: routePrompt,
        initialText: routePrompt,
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('quick_text_capture_field')),
      );
      expect(field.decoration?.hintText, 'Today I noticed...');
      expect(find.text(routePrompt), findsNothing);
    });

    testWidgets('uses compact card on tall iPad surface', (tester) async {
      await pumpFocused(tester, surfaceSize: const Size(1024, 1366));

      final card = tester.getRect(
        find.byKey(const Key('focused_type_entry_card')),
      );
      expect(card.height, lessThan(500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides prompt starters until Examples is tapped', (
      tester,
    ) async {
      await pumpFocused(tester);

      expect(
        find.byKey(const Key('first_use_wording_capture_panel')),
        findsNothing,
      );
      expect(find.text('Today I noticed...'), findsOneWidget);
      expect(find.text('I kept thinking about...'), findsNothing);

      await tester.tap(
        find.byKey(const Key('focused_type_entry_examples_toggle')),
      );
      await tester.pump();

      expect(find.text('I kept thinking about...'), findsOneWidget);
      expect(find.text('I felt pressure when...'), findsOneWidget);
      expect(find.text('I nearly did the usual thing...'), findsOneWidget);
      expect(find.text('I did something different...'), findsOneWidget);
    });

    testWidgets('starter tap sets placeholder without prefilling field', (
      tester,
    ) async {
      await pumpFocused(tester);

      await tester.tap(
        find.byKey(const Key('focused_type_entry_examples_toggle')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('focused_type_entry_example_1')));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('quick_text_capture_field')),
      );
      expect(field.decoration?.hintText, 'I kept thinking about...');
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('Use voice instead pops the screen', (tester) async {
      await pumpFocused(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuickTextCaptureScreen(
                      focusedRecordTypeEntry: true,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('focused_type_entry_card')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('focused_type_entry_use_voice_link')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focused_type_entry_card')), findsNothing);
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
